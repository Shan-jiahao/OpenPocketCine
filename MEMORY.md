# Project Memory

## Purpose

Long-lived project context that is not already obvious from the code or `AGENTS.md`.
Never store secrets, camera credentials, captures, or personal data here.

## Current decisions

- 2026-09-04: PocketHeadTrack MVP reuses the existing iOS Pocket 4/4 Pro
  BLE → SoftAP → UDP/DUML → gimbal path, `HeadphoneMotionBridge`, and
  `HeadTrack`. It does not introduce a second protocol implementation or PID.
- 2026-09-04: Head tracking must be usable without mounting the live video
  monitor, and every loss-of-control condition must send the existing gimbal
  rest/stop behavior immediately.
- 2026-09-04: Keep English source strings as the fallback and ship Simplified
  Chinese through `zh-Hans` localization resources so the interface follows the
  device language without maintaining a separate Chinese UI implementation.
- 2026-09-04: Simplified Chinese copy should explain specialist terms in plain
  Chinese while retaining useful industry abbreviations such as BLE, HEVC,
  DUML, LUT, IRE, ETTR, ISO, and FPS for cross-reference with camera menus.

## Operations

- Secret configuration locations and handling rules are documented in
  `SECURITY.md`; values must not be copied here.
- Apple Personal Teams cannot provision the Hotspot Configuration capability.
  For local device-only debugging, use a temporary empty entitlements file and
  a developer-owned bundle identifier at build time. Keep the checked-in
  Hotspot entitlement and production bundle identifier for the paid team/App
  Store build.
- 2026-09-04: The manual SoftAP fallback was hardware-validated with a Pocket 4
  Pro: when the phone already has a `192.168.2.x` camera path, skipping
  `NEHotspotConfiguration.apply` allows the existing UDP/DUML connection to
  continue under a Personal Team build.
- 2026-09-04: A Personal Team build reports `NEHotspotConfigurationErrorDomain`
  code 8 when it attempts automatic SoftAP configuration. Treat that as a
  manual-join flow: preserve the target network, show its SSID, poll for the
  camera DHCP path, and resume without another pairing tap.
- 2026-09-05: `Pocket助手` is a separate Chinese-first iPhone app target. Head
  tracking is its primary workflow; gimbal, capture, and device connection are
  supporting tabs. It has no monitor or media workflow and reuses the existing
  Pocket connection/control stack and HeadTrack controller without protocol or
  PID forks. See `docs/pocket-assistant.md`.
- Remove obsolete entries through a reviewed change to this file.
