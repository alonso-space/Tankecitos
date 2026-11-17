extends Node
## Servidor autoritativo y headless. Simula todo el juego (física, balas, daño,
## reapariciones) y publica snapshots del estado a los clientes del navegador.

const GameMapScript := preload("res://maps/game_map.gd")
const TANK_SCENE := preload("res://server/ServerTank.tscn")
const BULLET_SCENE := preload("res://server/ServerBullet.tscn")

# peer id -> tanque. Es la única fuente de verdad de quién está jugando
var tanks: Dictionary[int, ServerTank] = {}

var _next_bullet_id := 1

# Mapa actual, su id (índice en GameConfig.MAPS) y cuenta atrás para el próximo cambio
var _map: GameMapScript
var _map_id := -1
var _map_time_left := GameConfig.MAP_ROTATION_SECONDS
# Categoría de tamaño -> ids de los mapas de esa categoría (se llena en _index_maps)
var _map_ids_by_size: Array[Array] = []

@onready var _tanks_root: Node2D = $World/Tanks
@onready var _bullets_root: Node2D = $World/Bullets
@onready var _map_slot: Node2D = $World/MapSlot


func _ready() -> void:
	# En headless no hay vsync y el bucle giraría al 100% de CPU sin límite
	Engine.max_fps = 120

	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(GameConfig.PORT)
	if err != OK:
		push_error("Could not open port %d: %s" % [GameConfig.PORT, error_string(err)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Server listening on ws://localhost:", GameConfig.PORT)

	_index_maps()
	_change_map(_pick_map_id(0))


func _physics_process(delta: float) -> void:
	_map_time_left -= delta
	if _map_time_left <= 0.0:
		_change_map(_pick_map_id(tanks.size()))

	# La física corre a 60 Hz; mandamos snapshots solo cada N ticks
	var every_n_ticks := maxi(Engine.physics_ticks_per_second / GameConfig.SNAPSHOT_RATE, 1)
	if Engine.get_physics_frames() % every_n_ticks == 0:
		_broadcast_snapshot()


# --- RPC ---
# Godot exige que servidor y cliente declaren EXACTAMENTE los mismos RPC (mismo
# nombre y mismas opciones). Los que no se ejecutan de este lado quedan vacíos.

@rpc("authority", "call_remote", "reliable")
func receive_map(_new_map_id: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func receive_player_list(_player_ids: PackedInt32Array, _slots: PackedInt32Array) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func player_joined(_id: int, _slot: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func player_left(_id: int) -> void:
	pass


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(
	_tank_ids: PackedInt32Array,
	_tank_data: PackedFloat32Array,
	_bullet_ids: PackedInt32Array,
	_bullet_data: PackedFloat32Array,
) -> void:
	pass


# Input continuo: si se pierde un paquete llega otro 33 ms después, por eso no es reliable
@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_input(move: Vector2, aim: float) -> void:
	var tank := tanks.get(multiplayer.get_remote_sender_id()) as ServerTank
	if tank != null:
		tank.apply_input(move, aim)


# Un disparo es un evento puntual: no puede perderse, por eso es reliable.
# El servidor decide si de verdad hay disparo (recarga, tanque vivo, pared delante)
@rpc("any_peer", "call_remote", "reliable")
func send_fire(aim: float) -> void:
	var tank := tanks.get(multiplayer.get_remote_sender_id()) as ServerTank
	if tank != null:
		tank.request_fire(aim)


# --- Conexiones ---

func _on_peer_connected(id: int) -> void:
	# Contamos nuestros tanques y no get_peers(), que incluye a los rechazados
	if tanks.size() >= GameConfig.MAX_PLAYERS:
		print("Server full, rejecting ", id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	# Un jugador más puede no caber en el mapa actual: se salta a uno de la categoría que sí
	if GameConfig.MAP_CHANGE_WHEN_FULL and tanks.size() + 1 > _map.capacity():
		_change_map(_pick_map_id(tanks.size() + 1))

	var tank := TANK_SCENE.instantiate() as ServerTank
	tank.name = "Tank%d" % id
	tank.peer_id = id
	tank.slot = _take_free_slot()
	tank.bullet_requested.connect(_spawn_bullet)
	tank.respawn_requested.connect(_respawn_tank)
	_tanks_root.add_child(tank)
	tank.spawn(_pick_spawn_point(_alive_positions()))

	# Primero avisamos a los que ya estaban (el nuevo aún no está en el diccionario)
	for other_id in tanks:
		player_joined.rpc_id(other_id, id, tank.slot)

	tanks[id] = tank
	# Al nuevo le mandamos el mapa y luego la lista completa, incluido él mismo
	receive_map.rpc_id(id, _map_id)
	var ids := PackedInt32Array()
	var slots := PackedInt32Array()
	for player_id in tanks:
		ids.append(player_id)
		slots.append(tanks[player_id].slot)
	receive_player_list.rpc_id(id, ids, slots)
	print("Connected: ", id, " slot ", tank.slot, " (total: ", tanks.size(), ")")


func _on_peer_disconnected(id: int) -> void:
	# Si lo habíamos rechazado, nunca tuvo tanque y no hay nada que avisar
	if not tanks.has(id):
		return

	tanks[id].queue_free()
	tanks.erase(id)
	for other_id in tanks:
		player_left.rpc_id(other_id, id)
	print("Disconnected: ", id, " (total: ", tanks.size(), ")")


# El slot decide el color; se reutiliza el primero libre cuando alguien se va
func _take_free_slot() -> int:
	var used: Array[int] = []
	for tank in tanks.values():
		used.append(tank.slot)
	for slot in GameConfig.MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return 0


# El punto de aparición más lejano al tanque más cercano de `avoid`; empates al azar
func _pick_spawn_point(avoid: Array[Vector2]) -> Vector2:
	var candidates := Array(_map.spawn_points)
	candidates.shuffle()
	var best: Vector2 = candidates[0]
	var best_distance := -1.0
	for point: Vector2 in candidates:
		var nearest := INF
		for other in avoid:
			nearest = minf(nearest, point.distance_to(other))
		if nearest > best_distance:
			best = point
			best_distance = nearest
	return best


func _alive_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for tank in tanks.values():
		if tank.alive:
			positions.append(tank.position)
	return positions


func _respawn_tank(tank: ServerTank) -> void:
	tank.spawn(_pick_spawn_point(_alive_positions()))


# --- Mapas ---

# Clasifica los mapas por su flag size_category. Se instancian una vez solo para leerlo
func _index_maps() -> void:
	for i in GameMapScript.CAPACITY.size():
		_map_ids_by_size.append([])
	for id in GameConfig.MAPS.size():
		var candidate := GameConfig.MAPS[id].instantiate() as GameMapScript
		_map_ids_by_size[candidate.size_category].append(id)
		candidate.free()


# Un mapa al azar de la categoría que corresponde a esa cantidad de jugadores,
# evitando repetir el actual si hay otro de la misma categoría
func _pick_map_id(player_count: int) -> int:
	var size := GameMapScript.size_for_players(player_count)
	var candidates: Array = _map_ids_by_size[size].filter(func(id: int) -> bool: return id != _map_id)
	if candidates.is_empty():
		candidates = _map_ids_by_size[size]
	if candidates.is_empty():
		push_error("No maps for size category %d" % size)
		return maxi(_map_id, 0)
	return candidates.pick_random()


func _change_map(map_id: int) -> void:
	# Las balas en vuelo pertenecen al mapa anterior
	for bullet in _bullets_root.get_children():
		_bullets_root.remove_child(bullet)
		bullet.queue_free()

	# remove_child (y no solo queue_free) para que los muros viejos salgan de la física ya
	if _map != null:
		_map_slot.remove_child(_map)
		_map.queue_free()
	_map = GameConfig.MAPS[map_id].instantiate() as GameMapScript
	_map_id = map_id
	_map_slot.add_child(_map)
	_map_time_left = GameConfig.MAP_ROTATION_SECONDS

	# Los tanques vivos se reparten por el mapa nuevo; los muertos reaparecen solos más tarde
	var placed: Array[Vector2] = []
	for tank in tanks.values():
		if tank.alive:
			var point := _pick_spawn_point(placed)
			tank.spawn(point)
			placed.append(point)

	for id in tanks:
		receive_map.rpc_id(id, map_id)
	print("Map: %s (%d players)" % [_map.display_name, tanks.size()])


func _spawn_bullet(tank: ServerTank, origin: Vector2, direction: Vector2) -> void:
	var bullet := BULLET_SCENE.instantiate() as ServerBullet
	bullet.id = _next_bullet_id
	_next_bullet_id += 1
	bullet.owner_id = tank.peer_id
	bullet.owner_slot = tank.slot
	_bullets_root.add_child(bullet)
	bullet.launch(origin, direction)


# --- Snapshots ---
# Se manda el estado completo, no diferencias: pesa poco (8 tanques + unas
# balas) y un snapshot perdido se corrige solo con el siguiente.

func _broadcast_snapshot() -> void:
	var tank_ids := PackedInt32Array()
	var tank_data := PackedFloat32Array()
	for tank in tanks.values():
		if not tank.alive:
			continue  # un tanque muerto simplemente no aparece
		tank_ids.append(tank.peer_id)
		tank_data.append_array(PackedFloat32Array([
			tank.position.x,
			tank.position.y,
			tank.body_rotation,
			tank.turret_rotation,
			tank.hp,
			1.0 if tank.protection_left > 0.0 else 0.0,
		]))

	var bullet_ids := PackedInt32Array()
	var bullet_data := PackedFloat32Array()
	for bullet: ServerBullet in _bullets_root.get_children():
		if bullet.is_queued_for_deletion():
			continue
		bullet_ids.append(bullet.id)
		bullet_data.append_array(PackedFloat32Array([
			bullet.position.x, bullet.position.y, bullet.owner_slot,
		]))

	for id in tanks:
		receive_snapshot.rpc_id(id, tank_ids, tank_data, bullet_ids, bullet_data)
