import OpenPocketViewCore
import SwiftUI

/// Head-only control surface. The live camera session stays mounted behind this
/// cover, but the operator does not need the video monitor to drive the gimbal.
struct HeadTrackControlView: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: 10)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            LiveDesign.background
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusGrid
                    angleGrid
                    controlButton
                    configuration
                    safetyNote
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 68)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            CloseButton(action: onClose)
                .padding(.leading, 16)
                .padding(.top, 16)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { model.headphoneMotion.sync() }
        .accessibilityIdentifier("headTrack.control")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("PocketHeadTrack")
                    .font(LiveType.ui(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(LiveDesign.accent)
                Text("HEAD LOCK CONTROL")
                    .font(LiveType.ui(size: 26, weight: .semibold))
                    .foregroundStyle(LiveDesign.text)
            }
            Spacer()
            Toggle("Head Tracking", isOn: Bindable(model).headTrackingEnabled)
                .labelsHidden()
                .tint(LiveDesign.accent)
                .accessibilityLabel("Head Tracking")
        }
    }

    private var statusGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            statusCard(
                "AirPods",
                model.headTrackMotionFresh
                    ? "Motion ready"
                    : (model.headTrackAirPodsConnected ? "Motion paused" : "Not connected"),
                ready: model.headTrackMotionFresh)
            statusCard(
                "Pocket", model.session.phase.label,
                ready: model.session.isControlLinkReady)
            statusCard(
                "Datalink", model.session.isControlLinkReady ? "Ready" : "Unavailable",
                ready: model.session.isControlLinkReady)
            statusCard(
                "Gimbal", model.headTrackGimbalYawDeg == nil ? "Waiting for attitude" : "Ready",
                ready: model.headTrackGimbalYawDeg != nil && model.session.isControlLinkReady)
        }
    }

    private var angleGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            angleCard("HEAD YAW", model.headTrackHeadYawDeg)
            angleCard("HEAD PITCH", model.headTrackHeadPitchDeg)
            angleCard("GIMBAL YAW", model.headTrackGimbalYawDeg)
            angleCard("GIMBAL PITCH", model.headTrackGimbalPitchDeg)
            angleCard("TARGET YAW", model.headTrackTargetYawDeg)
            angleCard("TARGET PITCH", model.headTrackTargetPitchDeg)
        }
    }

    private var controlButton: some View {
        Button {
            model.headphoneMotion.tapControl()
        } label: {
            Text(model.headTrackControlTitle.opcLocalized.uppercased())
                .font(LiveType.ui(size: 15, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    model.headTrackCalibrated ? LiveDesign.rec : LiveDesign.accent,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!model.headTrackCalibrated && !canCalibrate)
        .opacity(!model.headTrackCalibrated && !canCalibrate ? 0.42 : 1)
        .accessibilityIdentifier("headTrack.calibrateStop")
    }

    private var canCalibrate: Bool {
        model.headTrackingEnabled && model.headTrackMotionFresh
            && model.session.isControlLinkReady && model.headTrackGimbalYawDeg != nil
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONTROL RESPONSE")
                .font(LiveType.ui(size: 11, weight: .bold))
                .kerning(1)
                .foregroundStyle(LiveDesign.muted)
            valueSlider(
                "Sensitivity", value: Bindable(model).headTrackSensitivity,
                range: 0.5...2, step: 0.05, valueText: "×%.2f")
            valueSlider(
                "Dead Zone", value: Bindable(model).headTrackDeadZoneDeg,
                range: 0...10, step: 0.5, valueText: "%.1f°")
            valueSlider(
                "Smoothness", value: Bindable(model).headTrackSmoothness,
                range: 0...1, step: 0.05, valueText: "%.0f%%", displayScale: 100)
            valueSlider(
                "Max Speed", value: Bindable(model).headTrackMaxSpeedDegPerSec,
                range: 10...HeadTrack.stickRateDegPerSec, step: 1, valueText: "%.0f°/s")
        }
        .padding(16)
        .background(
            LiveDesign.surface,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LiveDesign.hairline, lineWidth: 1))
    }

    private var safetyNote: some View {
        Text(
            "STOP is automatic when AirPods motion, the Pocket link, or app activity is lost. Recalibrate after any safety stop."
        )
        .font(LiveType.text(12))
        .foregroundStyle(LiveDesign.muted)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statusCard(_ title: String, _ value: String, ready: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ready ? LiveDesign.good : LiveDesign.faint)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.opcLocalized.uppercased())
                    .font(LiveType.ui(size: 9, weight: .bold))
                    .foregroundStyle(LiveDesign.muted)
                Text(value.opcLocalized)
                    .font(LiveType.text(13))
                    .foregroundStyle(LiveDesign.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(LiveDesign.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func angleCard(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.opcLocalized)
                .font(LiveType.ui(size: 9, weight: .bold))
                .foregroundStyle(LiveDesign.muted)
            Text(value.map { String(format: "%+.1f°", $0) } ?? "—")
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(LiveDesign.text)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(LiveDesign.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func valueSlider(
        _ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
        valueText: String, displayScale: Double = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title.opcLocalized)
                    .font(LiveType.text(13))
                    .foregroundStyle(LiveDesign.text)
                Spacer()
                Text(String(format: valueText, value.wrappedValue * displayScale))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(LiveDesign.muted)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .tint(LiveDesign.accent)
                .accessibilityLabel(title)
        }
    }
}
