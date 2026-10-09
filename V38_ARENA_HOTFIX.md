# V38 Arena Hotfix

The reported battle screen showed only the HUD and a flat navy background, so the original nested SubViewport arena was not visible on the target Android build.

## Fix
- Render the arena Node3D in the main scene viewport instead of a nested SubViewport.
- Hide the full-screen 2D app background while MatchPanel is visible, and restore it on leaving a match.
- Keep the legacy MatchPanel ArenaBG hidden during battle.
- Consolidate arena setup to one code path to avoid duplicate world roots.
- Keep the 2D HUD, joystick, buttons, and status overlays on top of the 3D world.

## Validation
The ZIP archive and project/workflow metadata are checked. Godot 4.7.2 parse/export and Android on-device rendering still require GitHub Actions and a device; this source hotfix is not claimed as APK-verified until that workflow passes.
