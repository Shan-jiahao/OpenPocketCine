# Pocket Assistant iOS App

## Product outcome

`Pocket助手` is a separate, Chinese-first iPhone app for operating a supported
DJI Osmo Pocket without a video monitor. Head tracking is the primary workflow;
gimbal, capture, and connection utilities are supporting workflows.

The existing `OpenPocketCine` app remains available and unchanged as a product.
Both apps reuse the same proven BLE → SoftAP → UDP/DUML session, camera command
tables, gimbal stream, and `HeadTrack` controller. Pocket Assistant must not
fork the protocol implementation or add another PID controller.

## Information architecture

The app has four stable tabs:

1. **头追** — readiness, AirPods/Pocket/datalink/gimbal state, calibration and
   STOP, head/gimbal/target angles, gimbal recenter, supported-headphone help,
   and quick or detailed response tuning.
2. **云台** — a touch joystick, recenter, rotate 180°, pose readout, and stick
   sensitivity.
3. **拍摄** — recording control plus current battery, storage, capture mode,
   video format, color, and exposure summaries. No picture is rendered.
4. **设备** — first pairing, saved-camera reconnect, disconnect/forget, current
   connection stage, and practical Wi-Fi guidance.

## Architecture

- Add an independent `PocketAssistant` iOS application target and bundle.
- The target compiles the existing iOS control/session sources, excluding the
  `OpenPocketCineApp` entry point and its app icon, then adds its own SwiftUI
  entry point, root navigation, and asset catalog.
- `AppModel` and `HeadphoneMotionBridge` remain the single owners of connection
  and AirPods motion state in this iteration. Pocket Assistant mounts them at
  app level and never mounts `LiveViewScreen`.
- Connection success persists the camera and moves the operator to Head Track.
- Connection loss, AirPods loss, stale motion, app inactive/background, or an
  explicit STOP immediately rests the existing gimbal stream.
- The AirPods motion stream is stopped when the scene becomes inactive and is
  started cleanly on return. If an active Core Motion stream produces no first
  sample after authorization or an in-ear transition, the app performs up to
  three bounded push-stream restarts, falls back to the API's 25 Hz pull path,
  and then shows an actionable in-ear/retry message if both paths stay empty.
- A Personal Team build keeps the manual Settings → Wi-Fi fallback. A paid-team
  build can retain automatic Hotspot Configuration without UI changes.

This first extraction intentionally shares the proven shell sources instead of
moving protocol code between modules overnight. A later cleanup may split a
small reusable `PocketControlKit` target after both app targets have hardware
coverage; that refactor is not required for product separation.

## Out of scope

- Video preview, scopes, LUTs, focus overlays, media browsing, downloads, or
  delivery integrations.
- New camera opcodes, protocol reverse engineering, or a replacement PID.
- Android parity for this initial iPhone product extraction.
- iPhone or camera firmware updates.

## Acceptance criteria

- Xcode exposes separate `OpenPocketCine` and `PocketAssistant` schemes.
- Installing Pocket Assistant shows the name `Pocket助手` and its own icon.
- Every Pocket Assistant product surface is Chinese and no monitor screen is
  reachable.
- A user can pair/reconnect a Pocket, enter live datalink, calibrate head lock,
  stop it, recenter before calibration, choose Fast/Standard/Gentle response
  presets or tune the four detailed parameters, inspect Apple's current
  dynamic-head-tracking headphone list, move/flip the gimbal, and start/stop
  recording without a video surface.
- Head tracking stops safely for all lifecycle/link/motion failure cases.
- Existing HeadTrack and iOS unit tests pass; both iOS schemes build for the
  simulator; the Pocket Assistant target produces a signed device build ready
  for next-morning installation.

## Risks and validation

- A free Personal Team cannot provision Hotspot Configuration. Validate the
  manual SSID path and do not discard cached credentials for entitlement error
  code 8.
- Simulator cannot validate AirPods motion, BLE, or Pocket UDP traffic. Those
  remain physical-device checks; simulator work validates navigation, Chinese
  layout, disabled states, and build integrity.
- Shared source compilation means monitor internals still exist in the binary
  during this first extraction, but there is no entry point or product UI for
  them. Removing that unused binary weight requires a later module extraction,
  not a protocol rewrite.
