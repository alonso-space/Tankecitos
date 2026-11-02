class_name ServerTank
extends CharacterBody2D
## Tanque tal como lo ve el servidor: aquí vive la verdad del juego.
## El cliente solo manda su intención (hacia dónde moverse, hacia dónde apunta,
## "quiero disparar") y este nodo decide qué pasa de verdad.

# server.gd escucha estas señales; así el tanque no necesita conocer al servidor
signal bullet_requested(tank: ServerTank, origin: Vector2, direction: Vector2)
signal respawn_requested(tank: ServerTank)

var peer_id := 0
var slot := 0
var hp := 0
var alive := false
var protection_left := 0.0
# Rotaciones de los sprites, tal cual las dibuja el cliente (el sprite mira hacia arriba)
var body_rotation := 0.0
var turret_rotation := 0.0

var _move_input := Vector2.ZERO
var _aim := -PI / 2.0  # ángulo de la dirección de apuntado (0 = derecha)
var _input_age := 0.0
var _fire_cooldown := 0.0
var _fire_requested := false
var _respawn_left := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


## Guarda el input recibido por red. Nunca se confía en él: se valida todo.
func apply_input(move: Vector2, aim: float) -> void:
	if not move.is_finite() or not is_finite(aim):
		return
	_move_input = move.limit_length(1.0)
	_aim = aim
	_input_age = 0.0


## Anota que el jugador quiere disparar; se resuelve en el siguiente tick de física.
func request_fire(aim: float) -> void:
	if not is_finite(aim):
		return
	_aim = aim
	_fire_requested = true


func take_damage(amount: int) -> void:
	if not alive or protection_left > 0.0:
		return
	hp -= amount
	if hp <= 0:
		_die()


func spawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	hp = GameConfig.TANK_MAX_HP
	alive = true
	protection_left = GameConfig.SPAWN_PROTECTION
	_move_input = Vector2.ZERO
	_fire_requested = false
	# set_deferred porque se puede llamar en medio de un callback de red/física
	_shape.set_deferred("disabled", false)


func _die() -> void:
	alive = false
	velocity = Vector2.ZERO
	_move_input = Vector2.ZERO
	_respawn_left = GameConfig.RESPAWN_TIME
	# Muerto = sin colisión, para que las balas y otros tanques lo atraviesen
	_shape.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	if not alive:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			respawn_requested.emit(self)
		return

	protection_left = maxf(protection_left - delta, 0.0)

	# Si el cliente dejó de enviar (pestaña en segundo plano, red caída), frenamos
	_input_age += delta
	if _input_age > GameConfig.INPUT_TIMEOUT:
		_move_input = Vector2.ZERO

	var direction := _move_input
	if direction.length() < GameConfig.MOVE_DEADZONE:
		direction = Vector2.ZERO
	if direction != Vector2.ZERO:
		body_rotation = direction.angle() + PI / 2.0

	velocity = direction * GameConfig.TANK_SPEED
	move_and_slide()

	turret_rotation = _aim + PI / 2.0

	if _fire_requested:
		_fire_requested = false
		_try_fire()


func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return

	var direction := Vector2.from_angle(_aim)
	var muzzle := position + direction * GameConfig.MUZZLE_DISTANCE
	# Si hay una pared entre el centro y la boca del cañón no se dispara:
	# evita crear la bala dentro de la pared (y disparar a través de ella)
	var reach := muzzle + direction * GameConfig.BULLET_RADIUS
	var query := PhysicsRayQueryParameters2D.create(position, reach, GameConfig.LAYER_WALLS)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return

	_fire_cooldown = GameConfig.FIRE_COOLDOWN
	protection_left = 0.0  # disparar cancela la protección de reaparición
	bullet_requested.emit(self, muzzle, direction)
