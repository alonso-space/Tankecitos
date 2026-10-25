extends Node

const PORT := 9080
const MAX_CLIENTS := 8

# Ids de los jugadores aceptados. Es la única fuente de verdad
var players: Array[int] = []


func _ready() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Could not open port %d: %s" % [PORT, error_string(err)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Server listening on ws://localhost:", PORT)


# Estas funciones existen vacías aquí porque Godot exige que servidor y cliente
# declaren los mismos RPC; la lógica real está en el cliente
@rpc("authority", "call_remote", "reliable")
func receive_player_list(_player_ids: PackedInt32Array) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func player_joined(_id: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func player_left(_id: int) -> void:
	pass


func _on_peer_connected(id: int) -> void:
	# Contamos nuestra propia lista y no get_peers(), que incluye a los rechazados
	if players.size() >= MAX_CLIENTS:
		print("Server full, rejecting ", id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	# Primero avisamos a los que ya estaban (el nuevo aún no está en la lista)
	for other_id in players:
		player_joined.rpc_id(other_id, id)

	players.append(id)
	# Al nuevo le mandamos la lista completa, incluido él mismo
	receive_player_list.rpc_id(id, PackedInt32Array(players))
	print("Connected: ", id, " (total: ", players.size(), ")")


func _on_peer_disconnected(id: int) -> void:
	# Si lo habíamos rechazado, nunca estuvo en la lista y no hay nada que avisar
	if not players.has(id):
		return

	# Sale de la lista y nadie más ocupará ese id
	players.erase(id)
	for other_id in players:
		player_left.rpc_id(other_id, id)
	print("Disconnected: ", id, " (total: ", players.size(), ")")
