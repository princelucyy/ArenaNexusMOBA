# Astro Royale V38 — 3D MOBA Mode Select & Battle HUD

V38 is built from the V37 source to address the text-only battle screen and mode-selection gaps.

## Main changes
- Android icon updated from the supplied ASTRO ROYALE full-wordmark artwork. The standard 192px launcher icon keeps the full composition; the adaptive foreground is composed specifically for Android's central safe zone so ASTRO/ROYALE stays legible after launcher masking.
- Mode selector: Classic 5v5, Ranked 5v5, Custom Room, Arcade, Brawl, Training, VS AI, Practice Range.
- Dynamic 3D arena rendered by Godot SubViewport using meshes/materials: 3 lanes, river, jungle crystal clusters, blue/red towers and cores, hero units and minion units.
- On-screen movement controls, target hero/tower/core, lane selection, attack, two skills, ultimate, recall and push wave.
- Local combat target logic: hero -> tower -> core; tower protects the core in local practice mode.
- Match HUD uses the arena as visual background rather than a text-only screen; menu navigation is retained.
- Save data moves to `user://astro_royale_v38.cfg` and migrates legacy V37/V36 saves.
- Package ID `com.kittown.astroroyale.v38`, version 2.8.0 / code 3801.

## Boundaries
- Godot-procedural models are in-engine 3D mesh characters, not production skeletal animation assets.
- Classic/Ranked enter online matchmaking only when a cloud session and reachable server are configured. Other modes run locally.
- A full 10-human authoritative online match still requires the V34/V35 server to be deployed and tested from multiple devices.
- External OAuth, Google Play Games plugin, WhatsApp OTP, production anti-cheat, global leaderboard, and app-store purchase verification require provider/backend configuration.
- ZIP/source validation is not the same as an APK export or on-device test. GitHub Actions should perform the Godot parse check and APK export before installation.

## Build
GitHub Actions workflow: `Build Astro Royale V38`
Artifact: `AstroRoyale-v38-3d-moba-apk`
APK: `AstroRoyale-V38.apk`
