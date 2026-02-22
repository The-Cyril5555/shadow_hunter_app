## NetworkManager - Handles WebSocket multiplayer connections
## Autoload singleton. Manages server/client lifecycle, room codes, and peer tracking.
class_name NetworkManagerClass
extends Node


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal room_created(code: String)
signal room_joined(code: String, players: Array)
signal room_join_failed(reason: String)
signal lobby_updated(players: Array)
signal game_started(initial_players: Array, my_player_index: int)


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const DEFAULT_PORT: int = 9080
const MAX_PLAYERS: int = 8


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
var is_server_mode: bool = false
var room_code: String = ""
var local_player_name: String = ""
var server_url: String = ""

# Server-side only: room data
# { code: String → { peers: Array[int], players: Array[Dictionary], host_id: int } }
var _rooms: Dictionary = {}

# Client-side only: current room info
var _current_room: Dictionary = {}


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Auto-start in headless mode (Fly.io dedicated server)
	if DisplayServer.get_name() == "headless":
		var port: int = DEFAULT_PORT
		var env_port: String = OS.get_environment("PORT")
		if env_port != "":
			port = int(env_port)
		start_server(port)


# -----------------------------------------------------------------------------
# Public — Server
# -----------------------------------------------------------------------------

## Start a WebSocket server on the given port
func start_server(port: int = DEFAULT_PORT) -> Error:
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err != OK:
		push_error("[NetworkManager] Failed to start server on port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	is_server_mode = true
	print("[NetworkManager] Server started on port %d" % port)
	return OK


## Stop the server and disconnect all clients
func stop_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_rooms.clear()
	is_server_mode = false
	print("[NetworkManager] Server stopped")


# -----------------------------------------------------------------------------
# Public — Client
# -----------------------------------------------------------------------------

## Connect to a WebSocket server
func connect_to_server(url: String) -> Error:
	server_url = url
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_client(url)
	if err != OK:
		push_error("[NetworkManager] Failed to connect to %s: %s" % [url, error_string(err)])
		connection_failed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Connecting to %s..." % url)
	return OK


## Disconnect from server
func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	room_code = ""
	_current_room.clear()
	print("[NetworkManager] Disconnected from server")


# -----------------------------------------------------------------------------
# Public — Room Management (called by client, executed on server via RPC)
# -----------------------------------------------------------------------------

## Request creation of a new room (client → server)
func request_create_room(player_name: String) -> void:
	local_player_name = player_name
	_rpc_create_room.rpc_id(1, player_name)


## Request joining an existing room (client → server)
func request_join_room(code: String, player_name: String) -> void:
	local_player_name = player_name
	_rpc_join_room.rpc_id(1, code, player_name)


## Request game start (host only, client → server)
func request_start_game() -> void:
	_rpc_start_game.rpc_id(1)


## Broadcast a player action to the server (client → server)
func send_action(action: Dictionary) -> void:
	_rpc_player_action.rpc_id(1, action)


# -----------------------------------------------------------------------------
# RPC — Client → Server
# -----------------------------------------------------------------------------

@rpc("any_peer", "reliable", "call_remote")
func _rpc_create_room(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var code = _generate_room_code()
	_rooms[code] = {
		"peers": [sender_id],
		"players": [{"id": sender_id, "name": player_name, "ready": false}],
		"host_id": sender_id,
		"started": false,
	}
	print("[NetworkManager] Room created: %s by peer %d" % [code, sender_id])
	_rpc_room_created.rpc_id(sender_id, code)


@rpc("any_peer", "reliable", "call_remote")
func _rpc_join_room(code: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()

	if not _rooms.has(code):
		_rpc_join_failed.rpc_id(sender_id, "room_not_found")
		return

	var room = _rooms[code]

	if room.started:
		_rpc_join_failed.rpc_id(sender_id, "game_already_started")
		return

	if room.peers.size() >= MAX_PLAYERS:
		_rpc_join_failed.rpc_id(sender_id, "room_full")
		return

	room.peers.append(sender_id)
	room.players.append({"id": sender_id, "name": player_name, "ready": false})
	print("[NetworkManager] Peer %d joined room %s" % [sender_id, code])

	# Confirm to joiner
	_rpc_room_joined.rpc_id(sender_id, code, room.players)

	# Update all others in the room
	for peer_id in room.peers:
		if peer_id != sender_id:
			_rpc_lobby_updated.rpc_id(peer_id, room.players)


@rpc("any_peer", "reliable", "call_remote")
func _rpc_start_game() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	for code in _rooms:
		var room = _rooms[code]
		if room.host_id == sender_id and not room.started:
			if room.peers.size() < 2:
				return
			room.started = true
			print("[NetworkManager] Game starting in room %s" % code)
			_setup_network_game(room)
			return


@rpc("any_peer", "reliable", "call_remote")
func _rpc_player_action(_action: Dictionary) -> void:
	pass  # Handled by GameNetworkBridge._rpc_client_action


# -----------------------------------------------------------------------------
# RPC — Server → Client
# -----------------------------------------------------------------------------

@rpc("authority", "reliable", "call_local")
func _rpc_room_created(code: String) -> void:
	room_code = code
	room_created.emit(code)
	print("[NetworkManager] Room created: %s" % code)


@rpc("authority", "reliable", "call_local")
func _rpc_room_joined(code: String, players: Array) -> void:
	room_code = code
	_current_room = {"code": code, "players": players}
	room_joined.emit(code, players)
	print("[NetworkManager] Joined room: %s (%d players)" % [code, players.size()])


@rpc("authority", "reliable", "call_local")
func _rpc_join_failed(reason: String) -> void:
	room_join_failed.emit(reason)
	print("[NetworkManager] Join failed: %s" % reason)


@rpc("authority", "reliable", "call_local")
func _rpc_lobby_updated(players: Array) -> void:
	_current_room["players"] = players
	lobby_updated.emit(players)


## Sent to each peer individually with their full initial state
@rpc("authority", "reliable", "call_remote")
func _rpc_game_started(initial_players: Array, my_player_index: int) -> void:
	print("[NetworkManager] Game started — I am player %d" % my_player_index)
	game_started.emit(initial_players, my_player_index)


# -----------------------------------------------------------------------------
# Private Helpers
# -----------------------------------------------------------------------------

## Server: create Player objects, distribute characters, send initial state to each peer
func _setup_network_game(room: Dictionary) -> void:
	# 1. Build Player objects
	var players: Array = []
	for i in range(room.players.size()):
		var p_data = room.players[i]
		var player = Player.new(i, p_data.get("name", "Joueur %d" % (i + 1)), true)
		players.append(player)
	GameState.reset()
	GameState.players = players
	GameState.is_network_game = true

	# 2. Distribute characters using existing system
	var player_count = players.size()
	CharacterDistributor.distribute_characters(players, player_count, false)

	# 3. Initialize decks
	GameState.initialize_decks()

	# 4. Initialize turn state
	GameState.turn_count = 1
	GameState.current_player_index = 0
	GameState.current_phase = GameState.TurnPhase.MOVEMENT

	print("[NetworkManager] Network game set up with %d players" % player_count)

	# 5. Send initial state to each peer individually
	for i in range(room.peers.size()):
		var peer_id: int = room.peers[i]
		# Find which player index this peer controls
		# Match peer_id to player by index in lobby players list
		var my_idx: int = -1
		for j in range(room.players.size()):
			if room.players[j].get("id", 0) == peer_id:
				my_idx = j
				break

		# Serialize players — each peer gets a version where only THEIR faction/hand is visible
		var serialized: Array = _serialize_initial_players(players, my_idx)
		_rpc_game_started.rpc_id(peer_id, serialized, my_idx)

	# 6. Server also transitions to GAME scene to run GameBoard and process client RPCs
	GameState.my_network_player_index = -1  # dedicated server has no local player
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME)


## Serialize all players for initial state, filtering private data per viewer
func _serialize_initial_players(players: Array, viewer_idx: int) -> Array:
	var result: Array = []
	for i in range(players.size()):
		var p: Player = players[i]
		var p_dict: Dictionary = {
			"id": p.id,
			"display_name": p.display_name,
			"is_human": true,
			"hp": p.hp,
			"hp_max": p.hp_max,
			"is_alive": true,
			"is_revealed": false,
			"position_zone": "hermit",
			"equipment": [],
			"hand": [],
		}
		# Only include private data for the viewer themselves
		if i == viewer_idx:
			p_dict["character_id"] = p.character_id
			p_dict["character_name"] = p.character_name
			p_dict["faction"] = p.faction
			p_dict["ability_data"] = p.ability_data
		else:
			# Other players: hide identity
			p_dict["character_id"] = ""
			p_dict["character_name"] = ""
			p_dict["faction"] = ""
			p_dict["ability_data"] = {}
		result.append(p_dict)
	return result


func _generate_room_code() -> String:
	var attempts := 0
	var code := ""
	while attempts < 100:
		code = "%04d" % randi_range(1000, 9999)
		if not _rooms.has(code):
			return code
		attempts += 1
	return "%06d" % randi_range(100000, 999999)


func _remove_peer_from_rooms(peer_id: int) -> void:
	for code in _rooms.keys():
		var room = _rooms[code]
		if peer_id in room.peers:
			room.peers.erase(peer_id)
			room.players = room.players.filter(func(p): return p.id != peer_id)

			if room.peers.is_empty():
				_rooms.erase(code)
				print("[NetworkManager] Room %s deleted (empty)" % code)
			else:
				# Notify remaining players
				for pid in room.peers:
					_rpc_lobby_updated.rpc_id(pid, room.players)
				print("[NetworkManager] Peer %d left room %s" % [peer_id, code])
			return


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % peer_id)
	if is_server_mode:
		_remove_peer_from_rooms(peer_id)
	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server (my peer ID: %d)" % multiplayer.get_unique_id())
	connected_to_server.emit()


func _on_connection_failed() -> void:
	push_warning("[NetworkManager] Connection failed")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("[NetworkManager] Server disconnected")
	multiplayer.multiplayer_peer = null
	room_code = ""
	_current_room.clear()
	server_disconnected.emit()
