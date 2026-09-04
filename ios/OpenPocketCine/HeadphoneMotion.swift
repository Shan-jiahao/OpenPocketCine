import CoreMotion
import OpenPocketViewCore
import UIKit
import os

/// Shared local space: Calibrate Head Lock is identity. Look is Euler
/// Δatt yaw/pitch from that lock. Stick throw closes live `0x04/0x05`
/// onto that look. Roll is displayed only. Motion starts when Head
/// Tracking is on.
@MainActor
final class HeadphoneMotionBridge: NSObject, CMHeadphoneMotionManagerDelegate {
    /// On-screen head-track debug: axis rings + IMU/pred readout. Off for
    /// operators; flip to true when retuning `HeadTrack.stickRateDegPerSec`
    /// against the `pred` row. `ControlLiveLog` head-imu lines stay on
    /// either way (they are the pullable evidence, not screen chrome).
    static let debugHud = false

    private struct HeadSample: Sendable {
        var receivedAt: TimeInterval
        var w: Double
        var x: Double
        var y: Double
        var z: Double
        var gx: Double
        var gy: Double
        var gz: Double
        var yaw: Double
        var pitch: Double
        var roll: Double
        var quat: HeadTrack.Quat { HeadTrack.Quat(w: w, x: x, y: y, z: z) }
    }

    private weak var model: AppModel?
    private let motion = CMHeadphoneMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "opv.head-track"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()
    nonisolated private let latestHead = OSAllocatedUnfairLock<HeadSample?>(initialState: nil)
    private var samplePump: Task<Void, Never>?
    private var originQuat = HeadTrack.Quat.identity
    private var originYaw = 0.0
    private var originPitch = 0.0
    private var originRoll = 0.0
    private var lastYaw = 0.0
    private var lastPitch = 0.0
    private var lastRoll = 0.0
    private var lastQuat = HeadTrack.Quat.identity
    private var lastGx = 0.0
    private var lastGy = 0.0
    private var lastGz = 0.0
    private var biasGx = 0.0
    private var biasGy = 0.0
    private var biasGz = 0.0
    private var intGx = 0.0
    private var intGy = 0.0
    private var intGz = 0.0
    private var didToastStill = false
    private var haveHead = false
    private var didToastNeedPods = false
    private var userStopped = false
    private var calibratedByUser = false
    private var pendingCalibrate = false
    private var lastMotionAt: Date?
    private var lastHudAt: Date?
    private var lastLogAt: Date?
    private var centerHaptic = UIImpactFeedbackGenerator(style: .medium)
    private var track = HeadTrack()
    private var driving = false
    private var gimbalYaw0Deg = 0.0
    private var gimbalPitch0Deg = 0.0
    private var didToastLive = false
    private static let motionTimeout: TimeInterval = 0.25

    func attach(model: AppModel) {
        detach()
        self.model = model
        motion.delegate = self
        sync()
    }

    func detach() {
        stopForSafety(reason: "bridge detached")
        stopMotion()
        haveHead = false
        didToastNeedPods = false
        didToastStill = false
        userStopped = false
        calibratedByUser = false
        pendingCalibrate = false
        lastMotionAt = nil
        driving = false
        track.reset()
        didToastLive = false
        model?.headTrackControlTitle = LiveHeadTrackCalibrateButton.calibrateTitle
        model?.headTrackImuReadout = ""
        model?.headTrackAxisPose = nil
        clearPublishedPose()
        motion.delegate = nil
        model = nil
    }

    func noteBlocked() {
        stopDrive()
    }

    func noteLinkUnavailable() {
        stopForSafety(reason: "control link unavailable")
    }

    func noteSceneBecameInactive() {
        stopForSafety(reason: "app inactive")
    }

    func sync() {
        guard let model else { return }
        guard model.headTrackingEnabled else {
            stopForSafety(reason: "head tracking disabled")
            stopMotion()
            haveHead = false
            didToastNeedPods = false
            didToastStill = false
            userStopped = false
            calibratedByUser = false
            pendingCalibrate = false
            lastMotionAt = nil
            didToastLive = false
            model.headTrackControlTitle = LiveHeadTrackCalibrateButton.calibrateTitle
            model.headTrackImuReadout = ""
            model.headTrackAxisPose = nil
            clearPublishedPose()
            return
        }
        publishTitle()
        startMotion()
        if haveHead { publishReadout(now: Date()) }
        if canDrive, !userStopped, calibratedByUser { apply(dt: 0) } else { stopDrive() }
    }

    func tapControl() {
        guard let model, model.headTrackingEnabled else { return }
        if !userStopped, calibratedByUser {
            stopForSafety(reason: "operator stop", markUserStopped: true)
            resetRelative()
            model.session.controlNote = "Head lock cleared"
            publishReadout(now: Date())
            return
        }
        userStopped = false
        pendingCalibrate = true
        startMotion()
        if haveHead {
            completeCalibrate()
        } else {
            model.session.controlNote = "Head tracking needs AirPods in your ears"
        }
    }

    private func completeCalibrate() {
        guard let model, pendingCalibrate, haveHead else { return }
        switch track.center(
            gimbalYawTenth: model.session.gimbalYawTenthDeg,
            gimbalPitchTenth: model.session.gimbalPitchTenthDeg,
            gyroLookRight: lastGx, gyroLookUp: lastGy, gyroYaw: lastGz)
        {
        case .waitingForGimbal:
            model.session.controlNote = "Head tracking waiting for gimbal"
            return
        case .waitingForStill:
            if !didToastStill {
                didToastStill = true
                model.session.controlNote = "Hold still to set forward"
            }
            return
        case .centered:
            break
        }
        originYaw = lastYaw
        originPitch = lastPitch
        originRoll = lastRoll
        originQuat = lastQuat
        gimbalYaw0Deg = model.session.gimbalYawTenthDeg.map { Double($0) / 10 } ?? 0
        gimbalPitch0Deg = model.session.gimbalPitchTenthDeg.map { Double($0) / 10 } ?? 0
        biasGx = lastGx
        biasGy = lastGy
        biasGz = lastGz
        intGx = 0
        intGy = 0
        intGz = 0
        pendingCalibrate = false
        calibratedByUser = true
        track.configuration = model.headTrackConfiguration
        model.headTrackCalibrated = true
        didToastLive = true
        model.session.prepHeadTrackGimbal()
        model.session.controlNote = "Head lock set — gimbal follows"
        ControlLiveLog.line("head-track: calibrated")
        if model.hapticsEnabled { centerHaptic.impactOccurred() }
        lastMotionAt = Date()
        publishTitle()
        apply(dt: 0)
        publishReadout(now: lastMotionAt)
    }

    private func resetRelative() {
        originYaw = lastYaw
        originPitch = lastPitch
        originRoll = lastRoll
        originQuat = lastQuat
        intGx = 0
        intGy = 0
        intGz = 0
        lastMotionAt = Date()
    }

    private func publishTitle() {
        model?.headTrackControlTitle =
            (!userStopped && calibratedByUser)
            ? LiveHeadTrackCalibrateButton.stopTitle
            : LiveHeadTrackCalibrateButton.calibrateTitle
    }

    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in
            ControlLiveLog.line("head-track: AirPods connected")
            self.didToastNeedPods = false
            self.model?.headTrackAirPodsConnected = true
            if self.model?.headTrackingEnabled == true { self.startMotion() }
            self.sync()
        }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in
            ControlLiveLog.line("head-track: AirPods disconnected")
            self.haveHead = false
            self.latestHead.withLock { $0 = nil }
            self.model?.headTrackAirPodsConnected = false
            self.stopForSafety(reason: "AirPods disconnected")
            if self.model?.headTrackingEnabled == true {
                self.model?.session.controlNote = "Head tracking needs AirPods in your ears"
            }
        }
    }

    private func startMotion() {
        let auth = CMHeadphoneMotionManager.authorizationStatus()
        ControlLiveLog.line(
            "head-track: auth=\(Self.authLabel(auth)) available=\(motion.isDeviceMotionAvailable ? 1 : 0) active=\(motion.isDeviceMotionActive ? 1 : 0)"
        )
        if auth == .denied || auth == .restricted {
            if !didToastNeedPods {
                didToastNeedPods = true
                let name =
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? "OpenPocketCine"
                model?.session.controlNote = String(
                    format: "Allow Motion & Fitness for %@ in Settings".opcLocalized, name)
            }
            return
        }
        if !motion.isConnectionStatusActive {
            motion.startConnectionStatusUpdates()
        }
        guard motion.isDeviceMotionAvailable else {
            if model?.headTrackingEnabled == true, !didToastNeedPods {
                didToastNeedPods = true
                model?.session.controlNote = "Head tracking needs AirPods with motion"
            }
            return
        }
        model?.headTrackAirPodsConnected = true
        startSamplePump()
        guard !motion.isDeviceMotionActive else { return }
        latestHead.withLock { $0 = nil }
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] sample, error in
            if let error {
                Task { @MainActor in
                    ControlLiveLog.line("head-track: motion error \(error.localizedDescription)")
                    guard let self else { return }
                    self.haveHead = false
                    self.latestHead.withLock { $0 = nil }
                    self.model?.headTrackAirPodsConnected = false
                    self.stopForSafety(reason: "motion error")
                    if !self.didToastNeedPods {
                        self.didToastNeedPods = true
                        self.model?.session.controlNote = "Head tracking needs AirPods in your ears"
                    }
                }
                return
            }
            guard let sample, let self else { return }
            let q = sample.attitude.quaternion
            let r = sample.rotationRate
            let a = sample.attitude
            let next = HeadSample(
                receivedAt: ProcessInfo.processInfo.systemUptime,
                w: q.w, x: q.x, y: q.y, z: q.z,
                gx: r.x, gy: r.y, gz: r.z,
                yaw: a.yaw, pitch: a.pitch, roll: a.roll)
            self.latestHead.withLock { $0 = next }
        }
    }

    private func startSamplePump() {
        guard samplePump == nil else { return }
        samplePump = Task { @MainActor [weak self] in
            let delay = Duration.milliseconds(
                Int((GimbalStick.streamInterval * 1_000).rounded(.up)))
            while !Task.isCancelled {
                try? await Task.sleep(for: delay)
                guard let self, !Task.isCancelled else { return }
                self.checkSafety()
                self.pullHead()
            }
        }
    }

    private func stopSamplePump() {
        samplePump?.cancel()
        samplePump = nil
    }

    private func pullHead() {
        guard let sample = latestHead.withLock({ $0 }) else { return }
        guard ProcessInfo.processInfo.systemUptime - sample.receivedAt <= Self.motionTimeout else {
            stopForSafety(reason: "motion timeout")
            return
        }
        lastGx = sample.gx
        lastGy = sample.gy
        lastGz = sample.gz
        lastYaw = sample.yaw
        lastPitch = sample.pitch
        lastRoll = sample.roll
        lastQuat = sample.quat
        if !haveHead {
            resetRelative()
        }
        haveHead = true
        model?.headTrackAirPodsConnected = true
        model?.headTrackMotionFresh = true
        didToastNeedPods = false
        let now = Date()
        var dt = 0.0
        if let last = lastMotionAt {
            dt = now.timeIntervalSince(last)
            if dt < 0 || dt > 0.25 { dt = 0 }
        }
        lastMotionAt = now
        if calibratedByUser, dt > 0 {
            let toDeg = 180 / Double.pi
            intGx += (lastGx - biasGx) * dt * toDeg
            intGy += (lastGy - biasGy) * dt * toDeg
            intGz += (lastGz - biasGz) * dt * toDeg
        }
        if pendingCalibrate, !calibratedByUser {
            completeCalibrate()
        } else if calibratedByUser {
            apply(dt: dt)
        }
        publishReadout(now: now)
    }

    private var canDrive: Bool {
        guard let model else { return false }
        if model.session.isLocked { return false }
        if model.session.isBrowsingMedia { return false }
        if let panel = model.liveOperatorPanel, panel != .headTrack { return false }
        if model.isEditingChrome { return false }
        return model.session.isControlLinkReady
    }

    private func apply(dt: TimeInterval) {
        guard let model, model.headTrackingEnabled, haveHead, !userStopped else {
            stopDrive()
            return
        }
        guard canDrive else {
            stopForSafety(reason: "control link unavailable")
            return
        }
        if !calibratedByUser || !track.isCentered {
            stopDrive()
            return
        }
        if model.gimbalAnalogHeld {
            stopDrive()
            return
        }
        if model.session.isLiveVideoStale {
            stopDrive()
            return
        }
        // Nose azimuth/elevation, not Euler Δatt: Euler yaw wobbles during
        // a nod at a yawed heading (18:29 take: diagonal drift).
        let look = HeadTrack.look(current: lastQuat, origin: originQuat)
        let lookRight = look.right
        let lookUp = look.up
        track.configuration = model.headTrackConfiguration
        guard
            let cmd = track.tick(
                lookRightDeg: lookRight, lookUpDeg: lookUp,
                gimbalYawTenth: model.session.gimbalYawTenthDeg,
                gimbalPitchTenth: model.session.gimbalPitchTenthDeg, dt: dt,
                gyroLookRight: lastGx, gyroLookUp: lastGy, gyroYaw: lastGz)
        else { return }
        // Mimo: 0x04/0x01 only while thrown. Do not grab/release in the same
        // second — that chatter paused HEVC (22:24:19 rest/throw/rest).
        if cmd.rest {
            if driving {
                ControlLiveLog.line(
                    String(
                        format: "head-track: stick rest head Y=%.1f P=%.1f", lookRight, lookUp))
                stopDrive()
            }
            return
        }
        if !driving {
            let axes = GimbalStick.encode(
                x: cmd.x, y: cmd.y,
                invertPan: GimbalStick.liveInvertPan(
                    poseInvert: model.session.gimbalPoseInvertPan,
                    assistMirror: model.assist.isVisible(.mirror)),
                linear: true)
            ControlLiveLog.line(
                String(
                    format:
                        "head-track: stick throw x=%.2f y=%.2f axis0=%u axis1=%u head Y=%.1f P=%.1f",
                    cmd.x, cmd.y, axes.axis0, axes.axis1, lookRight, lookUp))
        }
        driving = true
        model.session.updateGimbalStick(
            x: cmd.x, y: cmd.y, assistMirror: model.assist.isVisible(.mirror), linear: true)
    }

    private func stopDrive() {
        guard driving else { return }
        driving = false
        if model?.gimbalAnalogHeld != true {
            model?.session.endGimbalStick()
        }
    }

    private func checkSafety() {
        guard let model, model.headTrackingEnabled else { return }
        guard canDrive else {
            if calibratedByUser || driving {
                stopForSafety(reason: "control link unavailable")
            }
            return
        }
        guard let sample = latestHead.withLock({ $0 }) else {
            if calibratedByUser || driving { stopForSafety(reason: "motion timeout") }
            return
        }
        if ProcessInfo.processInfo.systemUptime - sample.receivedAt > Self.motionTimeout {
            stopForSafety(reason: "motion timeout")
        }
    }

    private func stopForSafety(reason: String, markUserStopped: Bool = false) {
        let wasActive = calibratedByUser || driving || pendingCalibrate
        userStopped = markUserStopped
        calibratedByUser = false
        pendingCalibrate = false
        lastMotionAt = nil
        track.reset()
        driving = false
        if model?.gimbalAnalogHeld != true { model?.session.endGimbalStick() }
        model?.headTrackCalibrated = false
        model?.headTrackMotionFresh = false
        model?.headTrackTargetYawDeg = nil
        model?.headTrackTargetPitchDeg = nil
        publishTitle()
        if wasActive { ControlLiveLog.line("head-track: stopped — \(reason)") }
    }

    private func stopMotion() {
        stopSamplePump()
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        if motion.isConnectionStatusActive { motion.stopConnectionStatusUpdates() }
        latestHead.withLock { $0 = nil }
        model?.headTrackMotionFresh = false
    }

    private func publishReadout(now: Date?) {
        guard let model, model.headTrackingEnabled, haveHead else {
            model?.headTrackImuReadout = ""
            model?.headTrackAxisPose = nil
            return
        }
        let look = HeadTrack.look(current: lastQuat, origin: originQuat)
        let lookRight = look.right
        let lookUp = look.up
        let adjusted = model.headTrackConfiguration.adjustedLook(right: lookRight, up: lookUp)
        let originGimbalYaw = calibratedByUser ? gimbalYaw0Deg : 0
        let originGimbalPitch = calibratedByUser ? gimbalPitch0Deg : 0
        let gimbalYawDeg = model.session.gimbalYawTenthDeg.map {
            HeadTrack.bodyLookRightDeg(
                liveYawDeg: Double($0) / 10, originYawDeg: originGimbalYaw)
        }
        let gimbalPitchDeg = model.session.gimbalPitchTenthDeg.map {
            HeadTrack.bodyLookUpDeg(
                livePitchDeg: Double($0) / 10, originPitchDeg: originGimbalPitch)
        }
        model.headTrackCalibrated = calibratedByUser
        model.headTrackHeadYawDeg = lookRight
        model.headTrackHeadPitchDeg = lookUp
        model.headTrackGimbalYawDeg = model.session.gimbalYawTenthDeg.map { Double($0) / 10 }
        model.headTrackGimbalPitchDeg = model.session.gimbalPitchTenthDeg.map { Double($0) / 10 }
        if calibratedByUser {
            let target = HeadTrack.Reach.project(
                lookRight: adjusted.right, lookUp: adjusted.up,
                yaw0: gimbalYaw0Deg, pitch0: gimbalPitch0Deg)
            model.headTrackTargetYawDeg = target.yaw
            model.headTrackTargetPitchDeg = target.pitch
        } else {
            model.headTrackTargetYawDeg = nil
            model.headTrackTargetPitchDeg = nil
        }
        model.headTrackAxisPose =
            Self.debugHud
            ? HeadTrackAxisPose(
                yawDeg: lookRight, pitchDeg: lookUp,
                gimbalYawDeg: gimbalYawDeg, gimbalPitchDeg: gimbalPitchDeg,
                locked: calibratedByUser)
            : nil
        let hudDue: Bool
        if let now, let last = lastHudAt {
            hudDue = now.timeIntervalSince(last) >= LiveChromeThrottle.statusInterval
        } else {
            hudDue = true
        }
        let logDue: Bool
        if let now, let last = lastLogAt {
            logDue = now.timeIntervalSince(last) >= 0.5
        } else {
            logDue = true
        }
        guard hudDue || logDue else { return }

        let dY = lookRight
        let dP = lookUp
        let dR = HeadTrack.wrapDeg(
            HeadTrack.radToDeg(lastRoll) - HeadTrack.radToDeg(originRoll))
        let bodyY = gimbalYawDeg ?? 0
        let bodyP = gimbalPitchDeg ?? 0
        // Observer pose, SET-relative like body. `pred` racing or trailing a
        // settled `body` on a physical take means `stickRateDegPerSec` is off.
        let predY = calibratedByUser ? track.modelYawDeg - gimbalYaw0Deg : 0
        let predP = calibratedByUser ? track.modelTiltDeg - gimbalPitch0Deg : 0
        let rawY = model.session.gimbalYawTenthDeg.map { String($0) } ?? "-"
        let rawP = model.session.gimbalPitchTenthDeg.map { String($0) } ?? "-"
        let setMark = calibratedByUser ? "SET" : "no SET"
        if hudDue {
            lastHudAt = now
            model.headTrackImuReadout =
                Self.debugHud
                ? String(
                    format:
                        "%@  shared °\nhead   Y%+6.1f  P%+6.1f  R%+6.1f\nbody   Y%+6.1f  P%+6.1f  rawP %@\npred   Y%+6.1f  P%+6.1f\nerr    Y%+6.1f  P%+6.1f",
                    setMark, dY, dP, dR, bodyY, bodyP, rawP, predY, predP, dY - predY,
                    dP - predP)
                : ""
        }
        if logDue {
            lastLogAt = now
            let att = model.session.lastGimbalAttitudeHex
            let dump = model.session.lastGimbalAttitudeDump
            ControlLiveLog.line(
                String(
                    format:
                        "head-imu: %@ head Y=%.1f P=%.1f R=%.1f  body Y=%.1f P=%.1f  pred Y=%.1f P=%.1f  err Y=%.1f P=%.1f  rawY=%@ rawP=%@ %@ att=%@",
                    setMark, dY, dP, dR, bodyY, bodyP, predY, predP, dY - predY, dP - predP,
                    rawY, rawP, dump.isEmpty ? "-" : dump, att.isEmpty ? "-" : att)
            )
        }
    }

    private func clearPublishedPose() {
        model?.headTrackAirPodsConnected = false
        model?.headTrackMotionFresh = false
        model?.headTrackCalibrated = false
        model?.headTrackHeadYawDeg = nil
        model?.headTrackHeadPitchDeg = nil
        model?.headTrackGimbalYawDeg = nil
        model?.headTrackGimbalPitchDeg = nil
        model?.headTrackTargetYawDeg = nil
        model?.headTrackTargetPitchDeg = nil
    }

    private static func authLabel(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        @unknown default: "unknown"
        }
    }
}
