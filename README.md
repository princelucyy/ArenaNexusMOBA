# Astro Royale V37 — Wordmark Icon + Expanded MOBA Systems

V37 continues from the V36 project and retains the existing Terms → Login → Profile → Tutorial → Lobby flow. It imports the new ASTRO ROYALE square artwork with rounded transparent corners, updates Android launcher icon assets, and expands the lobby into a scrollable system navigation with Heroes/Loadout, Shop, Inventory, Daily Reward, Rank/Leaderboard, Replay Center, Controls, Graphics/FPS, Audio, Account Center, Privacy/Security, Permissions and System Monitor.

## Version
- Version name: 2.7.0
- Version code: 3701
- Android package: `com.kittown.astroroyale.v37`
- APK: `build/AstroRoyale-V37.apk`
- GitHub Actions artifact: `AstroRoyale-v37-full-engine-apk`

## V37 functionality
- Existing local/cloud account flow and realtime client are retained. V36 local save data is migrated on first run via legacy config lookup.
- FPS cap can be changed (30/60/90/120) and is applied to `Engine.max_fps`. Master volume preference applies to Godot's main audio bus when present.
- Hero selection is persisted locally. Local shop purchases deduct coins and add an item to saved inventory. Daily reward is restricted to one claim per system date on the device.
- System Monitor reports real local platform/FPS and service health.
- Android permissions are user-requested one at a time. Optional/sensitive permissions do not gate the basic game flow.

## Honest limitations
Global leaderboard/social presence, full replay playback, verified premium purchases, external OAuth provider login, online news, and production matchmaking require deployed services/providers. V37 does not pretend these are live in local/offline mode.

## Build
Push source to the repository, then run GitHub Actions workflow `Build Astro Royale V37`. Check the exported APK and test on-device before replacing any existing stable build.
