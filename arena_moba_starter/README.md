# Arena Nexus MOBA — Gameplay & Onboarding V2

Original 16:9 landscape mobile MOBA prototype built with Godot 4.7.2.

## First-launch flow

1. Black logo screen
2. Full 16:9 collaborative hero splash
3. Loading progress 0–100%
4. User agreement & privacy/fair-play policy
5. Demo social login buttons: Google, Facebook, WhatsApp, or Guest
6. Create username + language + country
7. First-time tutorial intro
8. Hero selection
9. 5v5 bot tutorial match
10. Match result + rewards
11. Match history
12. Lobby

## Lobby / menu layer

- Hero gallery
- Classic AI 5v5 play flow
- Ranked preview
- Match history
- Player profile
- Event center
- Settings
- Local wallet (coins/diamonds)
- First-run persistence via `user://arena_nexus_profile.cfg`

The lobby is an original design inspired by modern mobile MOBA information architecture. It does not copy Mobile Legends assets, code, branding, characters, or exact UI.

## Current gameplay

- 5 original heroes
- 5v5-style match: 1 player + 4 allied bots vs 5 enemy bots
- 3 lanes + river/jungle background
- Minion waves + ranged/siege minions
- Turrets + bases
- Basic attack + Skill 1 + Skill 2 + Ultimate
- HP + Mana + XP + level + gold
- Hero respawn
- Item shop
- Touch + keyboard controls
- Tutorial completion + result screen + local match history

## Android build

GitHub Actions workflow:

`.github/workflows/android.yml`

Artifact:

`ArenaNexus-debug-apk`

The workflow enables ETC2/ASTC, creates a signed debug keystore, exports ARM64 + ARMv7, validates the APK with `apksigner`, and uploads the APK artifact.

## Production TODO

Real Google/Facebook/WhatsApp OAuth, persistent backend account service, authoritative multiplayer server, matchmaking, anti-cheat, chat, friends/guilds, live events, payment/store integrations, release signing, CDN, analytics, and production infrastructure should be implemented separately.


## V2.1 landscape/responsive fix
- Android uses sensor-landscape orientation for the MOBA UI/gameplay.
- Stretch aspect uses `expand` so full-screen backdrops fill wider phone aspect ratios without gray portrait bars.
- Runtime orientation is reinforced through `DisplayServer.SCREEN_SENSOR_LANDSCAPE`.
- This is an intentional landscape-first MOBA layout; a dedicated portrait lobby can be added later as a separate responsive scene.
