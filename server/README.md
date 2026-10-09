# Astro Royale V36 Backend

V36 keeps the authenticated WebSocket matchmaking/game server on port 8788 and HTTP cloud API on port 8787, adding a safer WebSocket URL/handshake sequence, reconnect backoff, queue rejoin and active match resume. Realtime states include a server timestamp, tick rate and per-player connection presence.

## Start in Termux

```bash
pkg update && pkg install python -y
cd server
./run_termux.sh
```

The launcher script creates a local virtual environment on Termux and installs `requirements.txt` there. If Python is already installed, skip the package install.

Default matchmaking needs **10 authenticated clients**. For controlled development only, run `MATCHMAKING_MIN_PLAYERS=2 ./run_termux.sh` to test the transport with two clients. Do not use the 2-player setting as the production 5v5 setting.

Environment variables:
- `ASTRO_HOST`: defaults to `0.0.0.0` in `run_termux.sh`
- `ASTRO_PORT`: defaults to `8787`
- `ASTRO_WS_PORT`: defaults to `8788`
- `ASTRO_DB`: defaults to `astro_royale_v36.sqlite3`
- `MATCHMAKING_MIN_PLAYERS`: defaults to `10`

The server authoritatively owns team assignment, player HP, movement coordinates, damage, deaths/respawn, towers, cores, objectives, victory and reward settlement. Reconnect/resume works while the in-memory match is still available; matches are not yet restored after a game server process restart.

For players on different networks, deploy this backend to a publicly reachable host with HTTPS/WSS, firewall limits, backups and load/security testing. A Termux listener is not automatically public on the internet.
