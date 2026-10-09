# V38 Test Plan
1. GitHub Actions must pass Godot parse-check and Android APK export.
2. Install alongside previous package; check launcher wordmark remains readable.
3. Verify Terms -> Login/Register -> Profile -> Tutorial -> Lobby.
4. Open mode selector and test all eight mode cards; start Training/VS AI locally.
5. Confirm 3D terrain, lanes, river, towers, core, hero, minions render on phone.
6. Test movement controls, attack/skills, target hero/tower/core and tower gate.
7. Test exit returns to lobby. Verify no data loss on relaunch.
8. Test online queue only after backend is reachable; test with two clients in development mode, then ten real clients in production mode.
