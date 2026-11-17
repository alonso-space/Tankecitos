# Tankecitos

Multiplayer tank arena for Godot 4.7. A headless authoritative server simulates everything (physics, bullets, damage, respawns); players join from a browser over WebSockets. Desktop: WASD/arrows + mouse aim + click to shoot. Mobile: twin-stick (left moves, right aims, release to shoot). Endless match with respawns.

See `tankecitos/howToRun.txt` for the commands. Development setup only: no authentication, keep ports 9080/8000 inside your LAN.

## Mapas

16 mapas en cuatro categorías según los jugadores conectados: MINI (1-4, ~1000), SMALL (5-8, ~2000), MEDIUM (9-12, ~3000) y LARGE (13-16, ~4000), cuatro por categoría. El servidor cambia a un mapa aleatorio de la categoría que corresponda cada 15 minutos (`GameConfig.MAP_ROTATION_SECONDS`) y también al instante si entra alguien que ya no cabe (`GameConfig.MAP_CHANGE_WHEN_FULL`).

Para añadir un mapa: crea la escena con el script `maps/game_map.gd` en la raíz (nombre, `size_category`, `play_size`, `spawn_points` y colores) y súmala a `GameConfig.MAPS`. `tests/maps_test.tscn` comprueba lo básico.

## Despliegue con Docker

Desde la raíz del repo, sin necesitar Godot instalado:

    HOST_IP=$(hostname -I | awk '{print $1}') docker compose up --build -d

Abre `https://<IP-del-PC>:8443` (el móvil, aceptando el certificado una vez) o `http://localhost:8000`. Dos servicios: `server` (Godot headless, puerto 9080) y `web` (Caddy con el cliente exportado, reenvía `/ws` al servidor). La primera construcción descarga Godot y las plantillas de exportación (~1 GB) y queda en caché de Docker; las siguientes solo reconstruyen lo que cambió. Para otra versión: `--build-arg GODOT_VERSION=...`. Sigue siendo solo para desarrollo/LAN: no hay autenticación.

