# Astro Royale V35 — Realtime Stability + Full Artwork App Icon

- Replaced the project artwork with the exact uploaded 1254×1254 ASTRO hero image; the source asset is copied unmodified.
- Added padded Android legacy/adaptive foreground icons plus a black adaptive background. The foreground is fitted into the launcher safe area to reduce masking/clipping of the artwork and ASTRO wordmark.
- Configured Godot Android preset to use the new launcher icons and package `com.kittown.astroroyale.v35`.
- Fixed WebSocket URL construction for `http://` and `https://` backend URLs.
- Removed the fixed 150 ms auth/queue race: queue join happens only after the server accepts the session token.
- Added reconnect backoff, heartbeat pings, automatic queue rejoin, and match resume support.
- Added `server_time`, `tick_hz`, and connected/disconnected presence to realtime state.
- Fixed stale socket cleanup so a disconnected old connection cannot erase a newer reconnected connection.
- Hardened Termux startup with Python detection and an isolated virtual environment.

V35 preserves the V33 onboarding/login/lobby flow and the V34 server-owned match state. Real 10-player play still requires the backend to be reachable and 10 authenticated clients queued at once.
