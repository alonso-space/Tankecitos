extends Node
## Cliente del navegador. No simula nada: manda el input al servidor y dibuja
## el estado que este le devuelve en cada snapshot.

const TANK_VIEW_SCENE := preload("res://client/TankView.tscn")
const BULLET_VIEW_SCENE := preload("res://client/BulletView.tscn")

# Copia local de la lista del servidor (peer id -> slot); el cliente nunca la modifica por su cuenta
var player_slots: Dictionary[int, int] = {}

var _connected := false
var _input_send_left := 0.0
var _tank_views: Dictionary[int, TankView] = {}
var _bullet_views: Dictionary[int, BulletView] = {}

@onready var _world: Node2D = $World
@onready var _tanks_root: Node2D = $World/Tanks
@onready var _bullets_root: Node2D = $World/Bullets
@onready var _input: InputController = $InputController
@onready var _status_label: Label = $Hud/StatusLabel
@onready var _players_label: Label = $Hud/PlayersLabel
@onready var _rotate_hint: Label = $Hud/RotateHint


func _ready() -> void:
	_input.setup(_world)
	_input.fire_requested.connect(_on_fire_requested)
	get_viewport().size_changed.connect(_update_rotate_hint)
	_update_rotate_hint()

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_log("Connecting...")
	var peer := WebSocketMultiplayerPeer.new()
	var url := _get_server_url()
	var err := peer.create_client(url)
	if err != OK:
		push_error("Could not create client: %s" % error_string(err))
		_log("Could not create client")
		return
	multiplayer.multiplayer_peer = peer


func _process(delta: float) -> void:
	if not _connected:
		return

	# El input necesita saber dónde está tu tanque para calcular hacia dónde apunta el cursor
	var my_view := _tank_views.get(multiplayer.get_unique_id()) as TankView
	if my_view != null:
		_input.origin = my_view.position
		my_view.set_local_aim(_input.aim)

	_input_send_left -= delta
	if _input_send_left <= 0.0:
		_input_send_left = 1.0 / GameConfig.INPUT_RATE
		send_input.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _input.move, _input.aim)


func _get_server_url() -> String:
	if not OS.has_feature("web"):
		return "ws://127.0.0.1:%d" % GameConfig.PORT
	# Página por HTTPS (Caddy): el navegador exige wss:// y el mismo origen, por la ruta /ws.
	# Página por HTTP (localhost): conexión directa al puerto del servidor.
	var is_https := bool(JavaScriptBridge.eval("window.location.protocol === 'https:'"))
	if is_https:
		return "wss://%s/ws" % str(JavaScriptBridge.eval("window.location.host"))
	return "ws://%s:%d" % [str(JavaScriptBridge.eval("window.location.hostname")), GameConfig.PORT]


func _log(message: String) -> void:
	print(message)
	_status_label.text = message


# En vertical el mapa se vería diminuto; pedimos girar el teléfono
func _update_rotate_hint() -> void:
	var size := get_viewport().get_visible_rect().size
	_rotate_hint.visible = _input.touch_mode and size.y > size.x


func _refresh_players_label() -> void:
	_players_label.text = "Players: %d" % player_slots.size()


func _on_fire_requested(aim: float) -> void:
	if _connected:
		send_fire.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, aim)


func _on_connected() -> void:
	_connected = true
	_log("Connected, my id: %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_log("Could not connect")


func _on_server_disconnected() -> void:
	_connected = false
	_log("Server went down")
	player_slots.clear()
	_clear_views()
	_refresh_players_label()


func _clear_views() -> void:
	for view in _tank_views.values():
		view.queue_free()
	for view in _bullet_views.values():
		view.queue_free()
	_tank_views.clear()
	_bullet_views.clear()


# --- RPC (mismos que en server.gd, ver el comentario allí) ---

@rpc("authority", "call_remote", "reliable")
func receive_player_list(player_ids: PackedInt32Array, slots: PackedInt32Array) -> void:
	if player_ids.size() != slots.size():
		return
	player_slots.clear()
	for i in player_ids.size():
		player_slots[player_ids[i]] = slots[i]
	_status_label.text = ""
	_refresh_players_label()


@rpc("authority", "call_remote", "reliable")
func player_joined(id: int, slot: int) -> void:
	player_slots[id] = slot
	_refresh_players_label()


@rpc("authority", "call_remote", "reliable")
func player_left(id: int) -> void:
	player_slots.erase(id)
	var view := _tank_views.get(id) as TankView
	if view != null:
		view.queue_free()
		_tank_views.erase(id)
	_refresh_players_label()


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(
	tank_ids: PackedInt32Array,
	tank_data: PackedFloat32Array,
	bullet_ids: PackedInt32Array,
	bullet_data: PackedFloat32Array,
) -> void:
	# Un snapshot mal formado se descarta entero
	if tank_data.size() != tank_ids.size() * GameConfig.TANK_STRIDE:
		return
	if bullet_data.size() != bullet_ids.size() * GameConfig.BULLET_STRIDE:
		return
	_apply_tanks(tank_ids, tank_data)
	_apply_bullets(bullet_ids, bullet_data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_input(_move: Vector2, _aim: float) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func send_fire(_aim: float) -> void:
	pass


# --- Aplicar snapshots ---

func _apply_tanks(ids: PackedInt32Array, data: PackedFloat32Array) -> void:
	var present := {}
	for i in ids.size():
		var id := ids[i]
		# Si el snapshot llega antes que la lista de jugadores, aún no sabemos su color
		if not player_slots.has(id):
			continue
		present[id] = true

		var view := _tank_views.get(id) as TankView
		if view == null:
			view = TANK_VIEW_SCENE.instantiate() as TankView
			view.setup(player_slots[id], id == multiplayer.get_unique_id())
			_tanks_root.add_child(view)
			_tank_views[id] = view

		var o := i * GameConfig.TANK_STRIDE
		view.apply_state(
			Vector2(data[o], data[o + 1]), data[o + 2], data[o + 3], int(data[o + 4]), data[o + 5] > 0.5
		)

	# Lo que ya no viene en el snapshot (murió o se fue) se borra
	for id in _tank_views.keys():
		if not present.has(id):
			_tank_views[id].queue_free()
			_tank_views.erase(id)


func _apply_bullets(ids: PackedInt32Array, data: PackedFloat32Array) -> void:
	var present := {}
	for i in ids.size():
		var id := ids[i]
		present[id] = true

		var o := i * GameConfig.BULLET_STRIDE
		var view := _bullet_views.get(id) as BulletView
		if view == null:
			view = BULLET_VIEW_SCENE.instantiate() as BulletView
			view.setup(int(data[o + 2]))
			_bullets_root.add_child(view)
			_bullet_views[id] = view
		view.apply_state(Vector2(data[o], data[o + 1]))

	for id in _bullet_views.keys():
		if not present.has(id):
			_bullet_views[id].queue_free()
			_bullet_views.erase(id)
