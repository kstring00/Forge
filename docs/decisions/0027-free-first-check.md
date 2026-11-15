# 0027 — The first check on a device is free

Recorded 2026-11-08.

- `startCheck(device, deviceToken)` on the proxy: a device's first Reality Check returns
  `free: true`, counts against no per-device allowance, and is logged as `freeChecks` in
  the usage view. Every later check counts as before. Developer tokens are neither free nor
  limited. The daily spend ceiling still applies to everything.
- **Remembered per device, not per install.** The app sends its DeviceCheck token next to
  the App Attest assertion on a Reality Check's opening turn; the proxy reads Apple's two
  per-device bits (`query_two_bits`) and sets bit 0 when the free check is spent
  (`update_two_bits`). Those bits survive a reinstall. Without a DeviceCheck key on the
  proxy, or if Apple does not answer, the store remembers by device id (per install) and
  says so in the log.
- The research response carries `freeCheck` on the opening turn so the app can show the
  one calm line after the first Brief (decision 0028).
- Test: `protect.test.ts` ("the first check on a device is free…").
