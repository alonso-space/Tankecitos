extends Node
## Prueba de humo de red: se conecta como un cliente real a un servidor ya
## corriendo y comprueba el ciclo completo (lista de jugadores, snapshots,
## movimiento por input y disparo).
##
## Terminal 1:  godot --headless --path . res://server/server.tscn
## Terminal 2:  godot --headless --path . res://tests/smoke_test.tscn
##
## El nodo raíz se llama "Main" y declara los mismos RPC que client.gd:
## si no, Godot descarta los paquetes porque las rutas/ids de RPC no coinciden.

const TIMEOUT := 15.0

var _failures := 0
var _my_slot := -1
var _players := 0
var _my_position := Vector2.ZERO
var _has_tank := false
var _bullets_seen := 0


func _ready() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client("ws://127.0.0.1:%d" % GameConfig.PORT)
	if err != OK:
		push_error("Could not create client")
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer

	get_tree().create_timer(TIMEOUT).timeout.connect(func() -> void:
		print("  FAIL  timeout (is the server running?)")
		get_tree().quit(1))

	await _run()
	print("RESULT: ", "OK" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	await _until(func() -> bool: return _my_slot >= 0)
	_check(_my_slot >= 0, "received player list including myself (slot %d)" % _my_slot)

	await _until(func() -> bool: return _has_tank)
	_check(_has_tank, "snapshot contains my tank")

	# Algunos spawns quedan junto al borde: nos movemos y disparamos hacia el centro del mapa
	var toward_center := Vector2.LEFT if _my_position.x > 0.0 else Vector2.RIGHT

	# Mover 0.6 s mandando input a 30 Hz
	var start := _my_position
	for i in 18:
		send_input.rpc_id(1, toward_center, toward_center.angle())
		await get_tree().create_timer(1.0 / 30.0).timeout
	send_input.rpc_id(1, Vector2.ZERO, toward_center.angle())
	var moved := (_my_position - start).dot(toward_center)
	_check(moved > 50.0, "tank moved toward the center (%.0f px)" % moved)

	send_fire.rpc_id(1, toward_center.angle())
	await get_tree().create_timer(0.3).timeout
	_check(_bullets_seen > 0, "bullet appeared in snapshots")
	print("  info  players visible: %d" % _players)


@rpc("authority", "call_remote", "reliable")
func receive_player_list(player_ids: PackedInt32Array, slots: PackedInt32Array) -> void:
	_players = player_ids.size()
	for i in player_ids.size():
		if player_ids[i] == multiplayer.get_unique_id():
			_my_slot = slots[i]


@rpc("authority", "call_remote", "reliable")
func player_joined(_id: int, _slot: int) -> void:
	_players += 1


@rpc("authority", "call_remote", "reliable")
func player_left(_id: int) -> void:
	_players -= 1


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(
	tank_ids: PackedInt32Array,
	tank_data: PackedFloat32Array,
	bullet_ids: PackedInt32Array,
	_bullet_data: PackedFloat32Array,
) -> void:
	var index := tank_ids.find(multiplayer.get_unique_id())
	_has_tank = index >= 0
	if _has_tank:
		var o := index * GameConfig.TANK_STRIDE
		_my_position = Vector2(tank_data[o], tank_data[o + 1])
	_bullets_seen = maxi(_bullets_seen, bullet_ids.size())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_input(_move: Vector2, _aim: float) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func send_fire(_aim: float) -> void:
	pass


func _until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok    " if condition else "  FAIL  "), label)
	if not condition:
		_failures += 1
