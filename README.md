# browser_multiplayer

Minimal server-authoritative multiplayer example in Godot 4. A headless server keeps the player list and every client connects from the browser over WebSockets.

Requires Godot 4.3+ with web export templates, and Python 3 to serve the export.

## Run

1. Start the server (it listens on port `9080`):

   ```bash
   godot --headless --path . res://server/server.tscn
   ```

2. Export the client: *Project → Export → Web* to `export/web/index.html` (exclude `server/*`).

3. Serve the export and open `http://localhost:8000`:

   ```bash
   cd export/web && python3 -m http.server 8000
   ```

Each browser tab is a new player. Use `localhost`, not `0.0.0.0`.

> Development setup only: the server has no authentication, so keep ports `9080` and `8000` inside your local network.

# Cómo lo ejecuto yo

Servidor (terminal 1):

```bash
cd ~/mygithub/MicroProjects/Projects/browser_multiplayer
~/dev_tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://server/server.tscn
```

Cliente web (terminal 2), tras exportar desde el editor:

```bash
cd ~/mygithub/MicroProjects/Projects/browser_multiplayer/export/web
python3 -m http.server 8000
```

Navegador: http://localhost:8000 (Ctrl+Shift+R después de reexportar).

Si el puerto está ocupado: `ss -ltnp | grep 9080` y `kill <pid>`.
