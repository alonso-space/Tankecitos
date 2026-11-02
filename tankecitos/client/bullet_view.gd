class_name BulletView
extends Node2D
## Dibujo de una bala en el cliente (solo posición, sin física).

const SMOOTHING := 25.0

var _color := Color.WHITE
var _has_state := false
var _target_position := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D


func setup(slot: int) -> void:
	_color = GameConfig.PLAYER_COLORS[slot % GameConfig.PLAYER_COLORS.size()]


func _ready() -> void:
	_sprite.modulate = _color


func apply_state(pos: Vector2) -> void:
	_target_position = pos
	if not _has_state:
		_has_state = true
		position = pos


func _process(delta: float) -> void:
	position = position.lerp(_target_position, 1.0 - exp(-SMOOTHING * delta))
