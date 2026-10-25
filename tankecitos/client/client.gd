extends Node

const PORT := 9080

# Copia local de la lista del servidor; el cliente nunca la modifica por su cuenta
var players: Array[int] = []

@onready var status_label: Label = $StatusLabel
@onready var players_label: Label = $PlayersLabel


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_log("Connecting...")
	var peer := WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [_get_server_host(), PORT]
	var err := peer.create_client(url)
	if err != OK:
		push_error("Could not create client: %s" % error_string(err))
		_log("Could not create client")
		return
	multiplayer.multiplayer_peer = peer


func _get_server_host() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.hostname"))
	return "127.0.0.1"


func _log(message: String) -> void:
	print(message)
	status_label.text += message + "\n"


# Se redibuja siempre desde la lista completa, así nunca queda desincronizado
func _refresh_players_label() -> void:
	var lines := PackedStringArray()
	lines.append("Players (%d):" % players.size())
	for id in players:
		var suffix := " (you)" if id == multiplayer.get_unique_id() else ""
		lines.append("- %d%s" % [id, suffix])
	players_label.text = "\n".join(lines)


func _on_connected() -> void:
	_log("Connected, my id: %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_log("Could not connect")


func _on_server_disconnected() -> void:
	_log("Server went down")
	players.clear()
	_refresh_players_label()


@rpc("authority", "call_remote", "reliable")
func receive_player_list(player_ids: PackedInt32Array) -> void:
	players.assign(player_ids)
	_refresh_players_label()


@rpc("authority", "call_remote", "reliable")
func player_joined(id: int) -> void:
	if not players.has(id):
		players.append(id)
	_log("Player joined: %d" % id)
	_refresh_players_label()


@rpc("authority", "call_remote", "reliable")
func player_left(id: int) -> void:
	players.erase(id)
	_log("Player left: %d" % id)
	_refresh_players_label()
