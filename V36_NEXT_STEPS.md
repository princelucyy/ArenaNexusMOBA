# V36 Test Checklist

1. Run GitHub Actions: Build Astro Royale V36; download `AstroRoyale-v36-full-engine-apk` only after the workflow is green.
2. Confirm launcher icon shows the full-bleed ASTRO hero artwork without artificial black padding. Android launcher mask shape is controlled by the device.
3. Test Terms → Login/Register → Profile → Lobby and launch a local match.
4. Open APP PERMISSIONS; request permissions individually, grant/deny, then press “PERBARUI STATUS IZIN”.
5. Verify denial of a permission does not block app launch or local gameplay.
6. Open “APLIKASI JIKA TIDAK DIGUNAKAN” and verify the Android Settings help text.
7. Test matchmaking with two clients in development mode, then set the server back to the default minimum of 10 for production 5v5.

Do not overwrite V33–V35 backups before testing V36 on the phone.
