class_name TankView
extends Node2D
## Dibujo de un tanque en el cliente. No tiene física ni lógica de juego:
## solo muestra lo que dice el servidor, suavizando entre snapshots.

# Qué tan rápido persigue al último snapshot (más alto = más pegado, menos suave)
const SMOOTHING := 25.0
const BAR_SIZE := Vector2(100, 7)
const BAR_OFFSET := Vector2(-50, 75)

var hp := GameConfig.TANK_MAX_HP

var _color := Color.WHITE
var _is_local := false
var _protected := false
var _has_state := false
var _target_position := Vector2.ZERO
var _target_body_rotation := 0.0
var _target_turret_rotation := 0.0
var _local_turret_rotation := 0.0
var _use_local_turret := false

@onready var _chassis: Sprite2D = $Chassis
@onready var _turret: Sprite2D = $Turret


# Se llama antes de add_child, por eso solo guarda datos; los sprites se pintan en _ready
func setup(slot: int, is_local: bool) -> void:
	_color = GameConfig.PLAYER_COLORS[slot % GameConfig.PLAYER_COLORS.size()]
	_is_local = is_local


func _ready() -> void:
	_chassis.modulate = _color
	_turret.modulate = _color


func apply_state(pos: Vector2, body_rotation: float, turret_rotation: float, new_hp: int, is_protected: bool) -> void:
	_target_position = pos
	_target_body_rotation = body_rotation
	_target_turret_rotation = turret_rotation
	_protected = is_protected
	if new_hp != hp:
		hp = new_hp
		queue_redraw()
	if not _has_state:
		# Primer snapshot de este tanque: aparece directo, sin deslizarse desde (0, 0)
		_has_state = true
		position = pos
		_chassis.rotation = body_rotation
		_turret.rotation = turret_rotation


## La torreta del jugador local sigue su propio cursor/joystick sin esperar al servidor.
## Es solo estética: el disparo real sale con el ángulo que el servidor recibe.
func set_local_aim(aim: float) -> void:
	_use_local_turret = true
	_local_turret_rotation = aim + PI / 2.0


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-SMOOTHING * delta)
	position = position.lerp(_target_position, weight)
	_chassis.rotation = lerp_angle(_chassis.rotation, _target_body_rotation, weight)
	if _use_local_turret:
		_turret.rotation = _local_turret_rotation
	else:
		_turret.rotation = lerp_angle(_turret.rotation, _target_turret_rotation, weight)

	# Parpadeo mientras dura la protección de reaparición
	modulate.a = 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.02) if _protected else 1.0


func _draw() -> void:
	draw_rect(Rect2(BAR_OFFSET, BAR_SIZE), Color(0, 0, 0, 0.6))
	var fill := BAR_SIZE.x * float(hp) / GameConfig.TANK_MAX_HP
	draw_rect(Rect2(BAR_OFFSET, Vector2(fill, BAR_SIZE.y)), _color)
	if _is_local:
		# Anillo para reconocer tu propio tanque entre los demás
		draw_arc(Vector2.ZERO, 64.0, 0.0, TAU, 48, Color.WHITE, 3.0)
