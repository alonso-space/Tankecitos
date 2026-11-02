class_name GameConfig
## Constantes compartidas entre servidor y cliente.
## Todo lo que sea "balance del juego" o "protocolo" vive aquí para que
## ambos lados siempre estén de acuerdo.

# --- Red ---
const PORT := 9080
const MAX_PLAYERS := 8
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

# Puntos de aparición: las 4 esquinas del juego original + 4 más para llegar a 8 jugadores
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-400, -400), Vector2(400, 400), Vector2(-400, 400), Vector2(400, -400),
	Vector2(0, -400), Vector2(0, 400), Vector2(-900, 150), Vector2(900, -150),
]

# Colores por slot: los 4 primeros son los del juego original
const PLAYER_COLORS: Array[Color] = [
	Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0), Color(1, 1, 0),
	Color(0, 1, 1), Color(1, 0.5, 0), Color(0.7, 0.3, 1), Color(1, 0.4, 0.7),
]
