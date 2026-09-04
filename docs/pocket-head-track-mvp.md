# PocketHeadTrack MVP

## Outcome

An iPhone operator can control a connected Pocket 4 / 4 Pro gimbal from an
AirPods head pose while a dedicated control surface covers the live monitor.
The feature reuses the existing camera session, datalink, gimbal-stick stream,
`HeadphoneMotionBridge`, and `HeadTrack` observer.

## Constraints

- Do not change BLE, SoftAP, UDP/DUML, or gimbal command encoding.
- Do not introduce a second controller or PID.
- Keep the 25 Hz gimbal-stick budget and the existing rest packet behavior.
- iOS only: Android has no headphone-motion source.
- Head tracking remains experimental and off by default.

## Operator flow

1. Connect a saved Pocket through the existing connection flow.
2. Open Operator Setup → Controls → HeadTrack Control.
3. Confirm AirPods, Pocket, datalink, and gimbal readiness.
4. Hold still and tap **CALIBRATE HEAD LOCK**.
5. Use **STOP** to clear the lock and rest the gimbal immediately.

For a Personal Team development build, iOS cannot grant the Hotspot
Configuration entitlement. If automatic join is unavailable, the Wi-Fi step
shows the exact camera SSID and waits while the operator joins it in Settings;
returning to the app resumes the existing BLE → datalink flow automatically.

The page shows live head, gimbal, and target yaw/pitch plus Sensitivity, Dead
Zone, Smoothness, and Max Speed controls. The video surface is not required to
be visible while this page is open.

## Safety acceptance

- AirPods disconnect rests the gimbal and clears calibration.
- Pocket or datalink loss is detected by the 25 Hz control pump, rests the
  gimbal, and clears calibration.
- No fresh headphone-motion sample for 250 ms rests the gimbal and clears
  calibration.
- App inactive/background notifications rest the gimbal and clear calibration
  before the session begins foreground recovery.
- Disabling Head Tracking and explicit STOP use the same safe stop path.

## Verification

- Swift core tests cover default behavior and all four configuration controls.
- iOS unit tests cover persisted preference defaults/clamping where practical.
- `just native-check` must pass locally.
- Physical iPhone + supported AirPods + Pocket 4/4 Pro verification remains a
  merge gate because Simulator cannot provide Bluetooth, SoftAP, or headphone
  motion.
