# Astro Royale V33 Changelog

## App identity
- Replaced the previous app/logo artwork with the user-supplied Astro Royale hero image.
- The exact uploaded PNG is used at `assets/astro_royale_logo.png` and referenced by `project.godot`.

## Real game-state engine
- Added `AstroGameStateService` to the client Core Kernel.
- Added queued network requests so login/sync/game requests do not overwrite each other.
- Added authoritative game-session API: start, state polling, lane/target actions and combat actions.
- Added server-side HP, mana, cooldown, gold, enemy hero, minion waves, three lanes, towers, enemy core and respawn state.
- Added server-side reward settlement and persistent match events.
- Client CLOUD mode now uses the server-owned match state instead of the old client-side result calculation.
- Local fallback remains available when no backend URL is configured.

## Stability boundary
- Boot, Terms, Login, Profile and onboarding UI were kept structurally unchanged.
- V31 remains the previous working cloud baseline; V33 is an incremental extension.

## Not yet in V33
- Multiple human players in the same match.
- Production matchmaking.
- Realtime multi-user transport.
- Production anti-cheat.

Those belong to V33+.
