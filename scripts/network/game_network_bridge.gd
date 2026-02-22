## GameNetworkBridge - Game state synchronization over WebSocket
## Added as a child of GameBoard in network mode.
## Server: receives client actions, processes them, broadcasts state.
## Client: sends actions, receives state updates and applies them.
class_name GameNetworkBridge
extends Node


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal public_state_received(state: Dictionary)
signal private_state_received(data: Dictionary)
signal remote_action_received(player_idx: int, action: Dictionary)


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
# Server-side: peer_id → player index in GameState.players
var _peer_to_player: Dictionary = {}
# Client-side: my peer_id → my player index
var _my_player_index: int = -1


# -----------------------------------------------------------------------------
# Public — Setup
# -----------------------------------------------------------------------------

## Server: build peer→player map from lobby room data
func setup_peer_map(room_players: Array) -> void:
	_peer_to_player.clear()
	for i in range(room_players.size()):
		_peer_to_player[room_players[i].get("id", 0)] = i
	print("[GameNetworkBridge] Peer map: %s" % str(_peer_to_player))


## Client: store which player index we control
func set_my_player_index(idx: int) -> void:
	_my_player_index = idx


## Returns true if local peer controls the current active player
func is_my_turn() -> bool:
	return _my_player_index == GameState.current_player_index


# -----------------------------------------------------------------------------
# Public — Client sends action to server
# -----------------------------------------------------------------------------

func send_roll_dice() -> void:
	_rpc_client_action.rpc_id(1, {"type": "roll_dice"})


func send_draw_card() -> void:
	_rpc_client_action.rpc_id(1, {"type": "draw_card"})


func send_attack(target_player_id: int) -> void:
	_rpc_client_action.rpc_id(1, {"type": "attack", "target": target_player_id})


func send_use_card(card_id: String, target_player_id: int) -> void:
	_rpc_client_action.rpc_id(1, {
		"type": "use_card",
		"card_id": card_id,
		"target": target_player_id,
	})


func send_end_turn() -> void:
	_rpc_client_action.rpc_id(1, {"type": "end_turn"})


## Generic action for simple requests (attack prompt, ability prompt)
func send_action_request(action_type: String) -> void:
	_rpc_client_action.rpc_id(1, {"type": action_type})


func send_reveal() -> void:
	_rpc_client_action.rpc_id(1, {"type": "reveal"})


func send_reveal_choice(confirmed: bool) -> void:
	_rpc_client_action.rpc_id(1, {"type": "reveal_choice", "confirmed": confirmed})


func send_zone_choice(choice: Dictionary) -> void:
	_rpc_client_action.rpc_id(1, {"type": "zone_choice", "choice": choice})


func send_target_selected(target_player_id: int) -> void:
	_rpc_client_action.rpc_id(1, {"type": "target_selected", "target": target_player_id})


# -----------------------------------------------------------------------------
# Public — Server broadcasts state
# -----------------------------------------------------------------------------

## Broadcast public game state to all connected peers
func broadcast_public_state() -> void:
	if not multiplayer.is_server():
		return
	var state = _build_public_state()
	_rpc_sync_public.rpc(state)


## Send private state (faction, hand) to a specific peer
func send_private_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx = _peer_to_player.get(peer_id, -1)
	if player_idx < 0 or player_idx >= GameState.players.size():
		return
	var player = GameState.players[player_idx]
	_rpc_sync_private.rpc_id(peer_id, _build_private_state(player))


## Send private state to ALL peers (e.g. at game start)
func send_all_private_states() -> void:
	if not multiplayer.is_server():
		return
	for peer_id in _peer_to_player.keys():
		send_private_state_to_peer(peer_id)


## Broadcast a toast message to all clients
func broadcast_toast(message: String, color: Color = Color.WHITE) -> void:
	if not multiplayer.is_server():
		return
	_rpc_show_toast.rpc(message, color)


## Broadcast game over to all clients
func broadcast_game_over(winning_faction: String) -> void:
	if not multiplayer.is_server():
		return
	_rpc_game_over.rpc(winning_faction)


@rpc("authority", "reliable", "call_local")
func _rpc_game_over(winning_faction: String) -> void:
	if multiplayer.is_server():
		return
	GameState.game_over.emit(winning_faction)


# -----------------------------------------------------------------------------
# RPC — Client → Server
# -----------------------------------------------------------------------------

@rpc("any_peer", "reliable", "call_remote")
func _rpc_client_action(action: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player_idx = _peer_to_player.get(sender_id, -1)
	if player_idx < 0:
		push_warning("[GameNetworkBridge] Unknown peer: %d" % sender_id)
		return
	# Validate turn ownership (except reveal_choice which can come from anyone)
	var action_type = action.get("type", "")
	if action_type != "reveal_choice" and player_idx != GameState.current_player_index:
		push_warning("[GameNetworkBridge] Peer %d sent action out of turn" % sender_id)
		return
	remote_action_received.emit(player_idx, action)


# -----------------------------------------------------------------------------
# RPC — Server → All Clients (public state)
# -----------------------------------------------------------------------------

@rpc("authority", "reliable", "call_local")
func _rpc_sync_public(state: Dictionary) -> void:
	if multiplayer.is_server():
		return  # Server already has the state
	_apply_public_state(state)
	public_state_received.emit(state)


# -----------------------------------------------------------------------------
# RPC — Server → One Client (private state)
# -----------------------------------------------------------------------------

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_private(data: Dictionary) -> void:
	_apply_private_state(data)
	private_state_received.emit(data)


# -----------------------------------------------------------------------------
# RPC — Server → All (toast notification)
# -----------------------------------------------------------------------------

@rpc("authority", "reliable", "call_local")
func _rpc_show_toast(message: String, color: Color) -> void:
	if multiplayer.is_server():
		return
	# The GameBoard will listen to this via public_state_received or a dedicated signal
	# For now, store last toast info in a property
	_last_toast_message = message
	_last_toast_color = color


var _last_toast_message: String = ""
var _last_toast_color: Color = Color.WHITE


# -----------------------------------------------------------------------------
# State Serialization (Server → Clients)
# -----------------------------------------------------------------------------

func _build_public_state() -> Dictionary:
	var players_data: Array = []
	for p in GameState.players:
		var p_dict: Dictionary = {
			"id": p.id,
			"name": p.display_name,
			"hp": p.hp,
			"hp_max": p.hp_max,
			"is_alive": p.is_alive,
			"is_revealed": p.is_revealed,
			"position_zone": p.position_zone,
			"equipment": [],
		}
		for card in p.equipment:
			p_dict["equipment"].append(card.to_dict())
		# Only reveal character info if player is revealed
		if p.is_revealed:
			p_dict["character_id"] = p.character_id
			p_dict["character_name"] = p.character_name
			p_dict["faction"] = p.faction
		players_data.append(p_dict)

	return {
		"players": players_data,
		"current_player_index": GameState.current_player_index,
		"turn_count": GameState.turn_count,
		"phase": int(GameState.current_phase),
		"hermit_count": GameState.hermit_deck.get_card_count() if GameState.hermit_deck else 0,
		"white_count": GameState.white_deck.get_card_count() if GameState.white_deck else 0,
		"black_count": GameState.black_deck.get_card_count() if GameState.black_deck else 0,
	}


func _build_private_state(player: Player) -> Dictionary:
	var hand_data: Array = []
	for card in player.hand:
		hand_data.append(card.to_dict())
	return {
		"player_id": player.id,
		"character_id": player.character_id,
		"character_name": player.character_name,
		"faction": player.faction,
		"hp_max": player.hp_max,
		"ability_data": player.ability_data,
		"hand": hand_data,
	}


# -----------------------------------------------------------------------------
# State Application (Client side)
# -----------------------------------------------------------------------------

func _apply_public_state(state: Dictionary) -> void:
	var players_data: Array = state.get("players", [])
	for p_data in players_data:
		var player_id: int = p_data.get("id", -1)
		if player_id < 0 or player_id >= GameState.players.size():
			continue
		var player: Player = GameState.players[player_id]
		player.hp = p_data.get("hp", player.hp)
		player.hp_max = p_data.get("hp_max", player.hp_max)
		player.is_alive = p_data.get("is_alive", player.is_alive)
		player.is_revealed = p_data.get("is_revealed", player.is_revealed)
		player.position_zone = p_data.get("position_zone", player.position_zone)
		# Apply revealed info if present
		if p_data.has("character_id"):
			player.character_id = p_data["character_id"]
			player.character_name = p_data["character_name"]
			player.faction = p_data["faction"]
		# Apply equipment
		player.equipment.clear()
		for card_data in p_data.get("equipment", []):
			var card = Card.new()
			card.from_dict(card_data)
			player.equipment.append(card)

	GameState.current_player_index = state.get("current_player_index", 0)
	GameState.turn_count = state.get("turn_count", 1)
	var phase_int: int = state.get("phase", 0)
	GameState.current_phase = phase_int as GameState.TurnPhase


func _apply_private_state(data: Dictionary) -> void:
	var player_id: int = data.get("player_id", -1)
	if player_id < 0 or player_id >= GameState.players.size():
		return
	var player: Player = GameState.players[player_id]
	player.character_id = data.get("character_id", "")
	player.character_name = data.get("character_name", "")
	player.faction = data.get("faction", "")
	player.hp_max = data.get("hp_max", player.hp_max)
	player.ability_data = data.get("ability_data", {})
	player.hand.clear()
	for card_data in data.get("hand", []):
		var card = Card.new()
		card.from_dict(card_data)
		player.hand.append(card)
