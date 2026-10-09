# V36 ASTRO App Icon

The original user artwork remains the source. `assets/astro_royale_logo.png` is retained for in-game screen art.

Launcher-specific files are built from the same 1254×1254 user artwork without cropping or reducing it into a small inset tile:
- `astro_royale_app_icon_192.png`: 192×192 legacy launcher icon.
- `astro_royale_adaptive_foreground_432.png`: 432×432 adaptive foreground.
- `astro_royale_adaptive_background_432.png`: blue non-black backing that fills only transparent external corner pixels.

Only the border-connected black corner fields from the source artwork are made transparent in launcher variants; the interior artwork and ASTRO wordmark remain untouched. There is no added black frame or artificial padding. Android launchers can still apply their own device-specific adaptive mask to outer corners.
