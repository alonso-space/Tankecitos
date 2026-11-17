# Tankecitos

Juego multijugador de tanques en Godot 4.7 (GDScript). Servidor headless autoritativo
(`tankecitos/server/`) y cliente web (`tankecitos/client/`) por WebSocket.

## Comandos (desde `tankecitos/`)
- Servidor: `godot --headless --path . res://server/server.tscn`
- Pruebas: `godot --headless --path . res://tests/combat_test.tscn` (y `maps_test`, `smoke_test`)
- Si añades un `class_name` nuevo: `godot --headless --path . --import` antes de ejecutar.
- Docker: `HOST_IP=$(hostname -I | awk '{print $1}') docker compose up --build -d`

## Reglas del proyecto
- El servidor manda: física, daño y reaparición viven solo en `server/`. El cliente solo dibuja.
- Los RPC deben declararse idénticos (mismo nombre y firma) en `server.gd`, `client.gd`
  y `tests/smoke_test.gd`. Si añades uno, añádelo en los tres.
- Constantes compartidas en `shared/config.gd`; no repitas números mágicos.
- Cada mapa lleva `size_category` y spawns propios (ver README, sección Mapas); súmalo a `GameConfig.MAPS`.
- Texturas del tanque: grises + alfa, para teñirse con `modulate`.
- Servidor sin autenticación: solo LAN/desarrollo.

## Convenciones
- Archivos: scripts y recursos en `snake_case`, escenas en `PascalCase`. Sin tildes ni ñ.
- Un solo separador, sin repetirlo: nada de `nombre--nombre` ni `nombre__nombre`.
- Identificadores en inglés; textos para el jugador en español.
- Tipos explícitos en parámetros, retornos y variables.
- Comentarios en español, pocos: solo donde el código no sea obvio, explicando el porqué.
- Sin emojis, ni en el código ni en los textos.
- Commits: `tipo: qué cambió` en español (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`).

## Antes de terminar
- Corre las pruebas. Si no puedes ejecutarlas, dilo.
- No toques `.godot/` ni `export/` (generados).
- No añadas dependencias ni plugins sin justificar para qué sirven.