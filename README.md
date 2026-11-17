# Tankecitos

Multiplayer tank arena for Godot 4.7. A headless authoritative server simulates everything (physics, bullets, damage, respawns); players join from a browser over WebSockets. Desktop: WASD/arrows + mouse aim + click to shoot. Mobile: twin-stick (left moves, right aims, release to shoot). Endless match with respawns.

See `tankecitos/howToRun.txt` for the commands. Development setup only: no authentication, keep ports 9080/8000 inside your LAN.

## Mapas

16 mapas en cuatro categorías según los jugadores conectados: MINI (1-4, ~1000), SMALL (5-8, ~2000), MEDIUM (9-12, ~3000) y LARGE (13-16, ~4000), cuatro por categoría. El servidor cambia a un mapa aleatorio de la categoría que corresponda cada 15 minutos (`GameConfig.MAP_ROTATION_SECONDS`) y también al instante si entra alguien que ya no cabe (`GameConfig.MAP_CHANGE_WHEN_FULL`).

Para añadir un mapa: crea la escena con el script `maps/game_map.gd` en la raíz (nombre, `size_category`, `play_size`, `spawn_points` y colores) y súmala a `GameConfig.MAPS`. `tests/maps_test.tscn` comprueba lo básico.

