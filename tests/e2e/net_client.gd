extends SceneTree

## End-to-end multiplayer test client.
## Connects to a local dedicated server (ws://127.0.0.1:9080), creates a room
## with 3 bots, starts the game and plays several turns through the real
## client network path. Exits 0 on success, 1 on timeout.
##
## Usage (server must already run on port 9080):
##   GODOT_WS_PORT=9091 godot --headless --path . -s res://tests/e2e/net_client.gd
## (GODOT_WS_PORT redirects this process's own auto-started server away from 9080.)
##
## Autoloads are resolved dynamically: this script compiles before they exist.

const TIMEOUT: float = 110.0
const TARGET_TURNS: int = 3
const PHASE_MOVEMENT: int = 0
const PHASE_ACTION: int = 1

var _started: bool = false
var _phase: String = "boot"
var _board: Node = null
var _my_idx: int = -1
var _elapsed: float = 0.0
var _tick: float = 0.0
var _acted_key: String = ""
var _gs: Node = null
var _nm: Node = null


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _started:
		_started = true
		_setup()
		return false
	if _elapsed > TIMEOUT:
		print("[TEST] TIMEOUT — phase=%s turn_count=%d current=%d game_phase=%d" % [
			_phase, _gs.turn_count, _gs.current_player_index, _gs.current_phase
		])
		quit(1)
		return false
	_tick += delta
	if _tick < 0.4:
		return false
	_tick = 0.0
	if _phase == "playing":
		_drive()
	return false


func _setup() -> void:
	_gs = root.get_node("GameState")
	_nm = root.get_node("NetworkManager")
	_nm.connected_to_server.connect(_on_connected)
	_nm.connection_failed.connect(func(): print("[TEST] CONNECTION FAILED"); quit(1))
	_nm.room_created.connect(_on_room_created)
	_nm.game_started.connect(_on_game_started)
	print("[TEST] connecting to ws://127.0.0.1:9080 ...")
	_nm.connect_to_server("ws://127.0.0.1:9080")


func _on_connected() -> void:
	print("[TEST] connected — creating room")
	_nm.request_create_room("Testeur")


func _on_room_created(code: String) -> void:
	print("[TEST] room created: %s — adding 3 bots" % code)
	_nm.request_set_bot_count(3)
	await create_timer(1.0).timeout
	print("[TEST] starting game")
	_nm.request_start_game()


func _on_game_started(initial_players: Array, my_player_index: int, zone_positions: Array) -> void:
	print("[TEST] game started — I am player %d (%d players)" % [my_player_index, initial_players.size()])
	var player_script = load("res://scripts/entities/player.gd")
	_gs.reset()
	_gs.is_network_game = true
	_gs.my_network_player_index = my_player_index
	for p_data in initial_players:
		_gs.players.append(player_script.from_dict(p_data))
	_gs.turn_count = 1
	_gs.current_player_index = 0
	_gs.current_phase = PHASE_MOVEMENT
	if zone_positions.size() > 0:
		_gs.zone_positions = zone_positions
	_my_idx = my_player_index
	# A game legitimately ending early (kill on turn 1-2) is also a full valid flow
	_gs.game_over.connect(func(faction):
		print("[TEST] SUCCESS — game over reached (%s wins) at turn %d" % [faction, _gs.turn_count])
		quit(0))
	var scene = load("res://scenes/game/game_board.tscn").instantiate()
	root.add_child(scene)
	_board = scene
	_phase = "playing"
	print("[TEST] game board loaded on client")


func _drive() -> void:
	if _gs.turn_count >= TARGET_TURNS:
		print("[TEST] SUCCESS — reached turn %d (current player %d)" % [
			_gs.turn_count, _gs.current_player_index
		])
		quit(0)
		return
	if _board == null or not is_instance_valid(_board):
		return

	# Answer a server-requested target selection (vision / instant / ability)
	if _board._net_selection_requested and _board.target_selection_panel.visible:
		var targets: Array = _board.target_selection_panel.get_current_targets()
		if not targets.is_empty():
			print("[TEST] answering target selection -> %s" % targets[0].display_name)
			_board.target_selection_panel._emit_selection(targets[0])
			return

	# Close a zone effect popup if one opened (effect zones)
	if _board.zone_effect_popup.visible:
		print("[TEST] cancelling zone effect popup")
		_board.zone_effect_popup._on_cancel_pressed()
		return

	if _gs.current_player_index != _my_idx:
		return

	var key: String = "%d_%d_%d" % [_gs.turn_count, _gs.current_player_index, _gs.current_phase]

	match int(_gs.current_phase):
		PHASE_MOVEMENT:
			if _acted_key == key:
				return
			_acted_key = key
			var zone_id: String = "church" if _gs.turn_count % 2 == 1 else "cemetery"
			print("[TEST] my turn — moving to %s" % zone_id)
			_board._on_popup_zone_selected(zone_id)
		PHASE_ACTION:
			# Auto-draw is handled by _net_update_client_ui; end turn once drawn
			if _board.has_drawn_this_turn and not _board.target_selection_panel.visible:
				if _acted_key == key:
					return
				_acted_key = key
				print("[TEST] ending my turn")
				_board._net.send_end_turn()
