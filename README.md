# Arena Nexus MOBA — Godot 4.7.2 Starter

Original MOBA prototype, not a clone of Mobile Legends. This starter includes a playable 5v5-style arena loop with:

- 1 player hero + 9 bot heroes
- 3 lanes
- towers and bases
- minion waves
- basic attack + area skill
- HP, mana, XP, level and gold
- respawn
- win/lose condition when a base falls
- keyboard controls and basic touchscreen controls
- GitHub Actions APK debug export

## Local run
Open the folder with Godot 4.7.2 stable and run the project.

## Controls
Desktop: WASD/Arrow keys to move, Left Mouse or ATK touch area to attack, Q/Space or SK1 touch area for skill.

Mobile: left side drag = movement; lower-right = attack; upper-right = skill.

## Termux workflow
This repository is designed to be edited with Termux and built by GitHub Actions. The APK is produced by CI.

## Next production layers
Replace procedural visuals with original assets; add authoritative multiplayer server, matchmaking, accounts, persistence, anti-cheat, hero data, item shop, skills, effects, audio, analytics and live-service tooling.
