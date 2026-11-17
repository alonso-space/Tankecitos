class_name GameConfig
## Constantes compartidas entre servidor y cliente.
## Todo lo que sea "balance del juego" o "protocolo" vive aquí para que
## ambos lados siempre estén de acuerdo.

# --- Red ---
const PORT := 9080
const MAX_PLAYERS := 16
const SNAPSHOT_RATE := 30  # snapshots por segundo, servidor -> clientes
const INPUT_RATE := 30  # envíos de input por segundo, cliente -> servidor
const INPUT_TIMEOUT := 0.5  # sin input por este tiempo (s), el servidor frena el tanque

# Formato de los snapshots (arrays planos de floats, ver server.gd y client.gd)
# Tanque: x, y, rotación chasis, rotación torreta, hp, protegido (0/1)
const TANK_STRIDE := 6
# Bala: x, y, slot del dueño
const BULLET_STRIDE := 3

# --- Física: bits de collision layer (coinciden con los nombres en project.godot) ---
const LAYER_WALLS := 1
const LAYER_TANKS := 2
const LAYER_BULLETS := 4

# --- Tanque (valores del juego original) ---
const TANK_SPEED := 250.0
const TANK_MAX_HP := 4
const TANK_RADIUS := 50.0
const MOVE_DEADZONE := 0.1
const MUZZLE_DISTANCE := 100.0  # distancia del centro del tanque a la boca del cañón
const FIRE_COOLDOWN := 1.0

# --- Bala (valores del juego original) ---
const BULLET_SPEED := 500.0
const BULLET_RADIUS := 12.5
const BULLET_LIFETIME := 4.0
const BULLET_DAMAGE := 1

# --- Reaparición ---
const RESPAWN_TIME := 3.0
const SPAWN_PROTECTION := 1.5  # invulnerable al reaparecer (se pierde al disparar)

# --- Mapas ---
# Lista de mapas. El índice es el id que viaja por red (servidor y cliente deben ser de la
# misma versión). Cada mapa se clasifica solo con su flag size_category (ver maps/game_map.gd);
# para añadir uno basta con crear la escena y sumarla aquí. Los puntos de aparición viven en cada mapa.
const MAPS: Array[PackedScene] = [
	# MINI (1-4 jugadores)
	preload("res://maps/Dunas.tscn"),
	preload("res://maps/CruzDeHielo.tscn"),
	preload("res://maps/Contenedores.tscn"),
	preload("res://maps/ArenaNeon.tscn"),
	# SMALL (5-8 jugadores)
	preload("res://maps/Arena.tscn"),
	preload("res://maps/Selva.tscn"),
	preload("res://maps/CiudadNocturna.tscn"),
	preload("res://maps/AnilloOrbital.tscn"),
	# MEDIUM (9-12 jugadores)
	preload("res://maps/Volcan.tscn"),
	preload("res://maps/CanonSerpentino.tscn"),
	preload("res://maps/Zigurat.tscn"),
	preload("res://maps/Archipielago.tscn"),
	# LARGE (13-16 jugadores)
	preload("res://maps/Laboratorio.tscn"),
	preload("res://maps/TableroDulces.tscn"),
	preload("res://maps/Fortaleza.tscn"),
	preload("res://maps/Asteroides.tscn"),
]
const MAP_ROTATION_SECONDS := 15.0 * 60.0  # cada cuánto cambia el mapa
# Si entra un jugador y el mapa actual ya no le cabe, se cambia a uno de la categoría siguiente
# sin esperar a la rotación. Ponlo en false para cambiar de mapa solo cada MAP_ROTATION_SECONDS.
const MAP_CHANGE_WHEN_FULL := true

# Colores por slot: los 4 primeros son los del juego original; del 9 al 16, intermedios
const PLAYER_COLORS: Array[Color] = [
	Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0), Color(1, 1, 0),
	Color(0, 1, 1), Color(1, 0.5, 0), Color(0.7, 0.3, 1), Color(1, 0.4, 0.7),
	Color(0, 0.55, 1), Color(1, 0.75, 0.55), Color(0.6, 0.7, 0.2), Color(0, 1, 0.5),
	Color(1, 0.75, 0), Color(0.75, 0.7, 1), Color(1, 0.45, 0.35), Color(0.65, 0.4, 0.2),
]
