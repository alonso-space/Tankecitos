class_name InputController
extends Node
## Convierte el input del dispositivo en tres cosas: hacia dónde moverse (move),
## hacia dónde apuntar (aim) y "quiero disparar" (fire_requested).
## Escritorio: WASD/flechas + cursor + clic.  Móvil: dos joysticks (twin-stick).

signal fire_requested(aim: float)

# Mantener el botón pide disparar cada 0.1 s; el servidor decide si ya recargó
const FIRE_REPEAT := 0.1
# Con el joystick de apuntar por debajo de este valor se considera "centrado"
const STICK_THRESHOLD := 0.3

var move := Vector2.ZERO
var aim := -PI / 2.0  # ángulo en radianes (0 = derecha)
var origin := Vector2.ZERO  # posición del tanque propio; la actualiza client.gd
var touch_mode := false

var _world: Node2D
var _fire_repeat_left := 0.0
var _aim_stick_active := false


func setup(world: Node2D) -> void:
	_world = world
	touch_mode = _detect_touch_mode()
	if touch_mode:
		_build_touch_ui()


func _process(delta: float) -> void:
	move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_mode:
		_process_touch()
	else:
		_process_desktop(delta)


func _process_desktop(delta: float) -> void:
	aim = (_world.get_global_mouse_position() - origin).angle()
	_fire_repeat_left -= delta
	if Input.is_action_pressed("fire") and _fire_repeat_left <= 0.0:
		_fire_repeat_left = FIRE_REPEAT
		fire_requested.emit(aim)


func _process_touch() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var active := stick.length() >= STICK_THRESHOLD
	if active:
		aim = stick.angle()
	elif _aim_stick_active:
		# Soltaste el joystick de apuntar: dispara con el último ángulo
		fire_requested.emit(aim)
	_aim_stick_active = active


# --- Detección de dispositivo ---

# ?touch=1 / ?touch=0 en la URL (o "-- --touch" al correr en el editor) fuerza el modo,
# útil para probar los joysticks desde el escritorio
func _detect_touch_mode() -> bool:
	var forced := _read_touch_override()
	if forced == 1:
		# Con esto el ratón también genera toques y los joysticks responden al clic
		Input.emulate_touch_from_mouse = true
		return true
	if forced == 0:
		return false
	if OS.has_feature("web"):
		# "pointer: coarse" = el dispositivo principal de apuntado es un dedo
		return bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches"))
	return DisplayServer.is_touchscreen_available()


func _read_touch_override() -> int:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('touch')")
		if value == "1":
			return 1
		if value == "0":
			return 0
		return -1
	return 1 if OS.get_cmdline_user_args().has("--touch") else -1


# --- Joysticks táctiles ---

func _build_touch_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# Dos mitades: izquierda mueve, derecha apunta y dispara al soltar
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	layer.add_child(row)
	row.add_child(_make_stick("move"))
	row.add_child(_make_stick("aim"))


func _make_stick(prefix: String) -> VirtualJoystick:
	var stick := VirtualJoystick.new()
	stick.action_left = StringName(prefix + "_left")
	stick.action_right = StringName(prefix + "_right")
	stick.action_up = StringName(prefix + "_up")
	stick.action_down = StringName(prefix + "_down")
	stick.joystick_size = 300.0
	stick.tip_size = 150.0
	stick.modulate = Color(1, 1, 1, 0.6)
	stick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stick.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return stick
