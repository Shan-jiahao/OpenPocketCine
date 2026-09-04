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

## Operations

- Secret configuration locations and handling rules are documented in
  `SECURITY.md`; values must not be copied here.
- Remove obsolete entries through a reviewed change to this file.
