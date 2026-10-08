# Astro Royale V36 — Full Engine UI + Android Permission Center

## What's new in V36
- Replaced the small black-framed launcher artwork with a full-bleed blue ASTRO hero icon. The main 192 px icon and adaptive foreground are filled edge-to-edge without imposed black padding.
- Added an optional Android Permission Center for calendar read/write, camera, contacts read, approximate/precise location, microphone, notification, nearby Bluetooth/Wi-Fi devices and phone status.
- Each permission is requested only after the player taps it. No mass permission prompt at startup; denial does not block Terms, Login, Profile, Lobby or local play.
- Added an in-app guide for Android's “pause app activity if unused” / unused-app permission reset settings. This control is owned by Android Settings and cannot be toggled silently by the game.
- Expanded the lobby navigation with ranked, Starfall Pass, mail/news and permission management.
- Preserved V35 login/onboarding and realtime server base; local save migrates from V35 through V30.
- Bumped Android package/version to `com.kittown.astroroyale.v36`, version name `2.6.0`, version code `3601`.

## Build
GitHub Actions workflow: **Build Astro Royale V36**
Expected artifact: `AstroRoyale-v36-full-engine-apk`
APK file: `AstroRoyale-V36.apk`

Build validation is done in GitHub Actions using Godot 4.7.2. A successful ZIP check alone does not mean that the APK has already built.

## Android permission behavior
The manifest declares the optional permissions needed by the Permission Center. The UI asks for one permission only when selected; the OS remains the source of truth. The game does not currently use contacts/calendar/camera/phone/Bluetooth/Wi-Fi data beyond the permission management interface, so do not grant those permissions unless you choose to test a related feature.

To manage unused-app restrictions manually, open Android Settings → Apps → Astro Royale → “Pause app activity if unused” or similar wording; manufacturer and Android version labels may vary.

## Realtime backend
Default matchmaking still requires 10 authenticated clients. For development transport testing only, `MATCHMAKING_MIN_PLAYERS=2 ./run_termux.sh` may be used. A publicly reachable secure host is required for players on different networks. This release does not claim that Google/Facebook/WhatsApp/Play Games identity providers or a public matchmaking deployment are configured automatically.
