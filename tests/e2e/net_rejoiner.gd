extends SceneTree

## E2E rejoin test, part 2: read the room code written by net_dropper.gd,
## join the STARTED game with the same player name, and verify that the
## server sends the mid-game snapshot and live state flows again.
## Exits 0 on success.
##
## Usage (run after net_dropper.gd, same server):
##   GODOT_WS_PORT=9093 godot --headless --path . -s res://tests/e2e/net_rejoiner.gd

const CODE_FILE: String = "user://e2e_room_code.txt"
const TIMEOUT: float = 70.0
const PHASE_MOVEMENT: int = 0

var _started: bool = false
var _elapsed: float = 0.0
var _board: Node = null
var _my_idx: int = -1
var _synced: bool = false
var _gs: Node = null
var _nm: Node = null


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _started:
		_started = true
		_setup()
		return false
	if _elapsed > TIMEOUT:
		print("[TEST] TIMEOUT — rejoined=%s synced=%s" % [_my_idx >= 0, _synced])
		quit(1)
	return false


func _setup() -> void:
	if not FileAccess.file_exists(CODE_FILE):
		print("[TEST] FAIL — no room code file (run net_dropper.gd first)")
		quit(1)
		return
	var f = FileAccess.open(CODE_FILE, FileAccess.READ)
	var code: String = f.get_as_text().strip_edges()
	f.close()
	_gs = root.get_node("GameState")
	_nm = root.get_node("NetworkManager")
	_nm.connected_to_server.connect(func():
		print("[TEST] connected — rejoining room %s as Testeur" % code)
		_nm.request_join_room(code, "Testeur"))
	_nm.connection_failed.connect(func(): print("[TEST] CONNECTION FAILED"); quit(1))
	_nm.room_join_failed.connect(func(reason):
		print("[TEST] FAIL — rejoin refused: %s" % reason)
		quit(1))
	_nm.game_started.connect(_on_game_snapshot)
	_nm.connect_to_server("ws://127.0.0.1:9080")


func _on_game_snapshot(players: Array, my_player_index: int, zone_positions: Array) -> void:
	print("[TEST] snapshot received — I am player %d (%d players)" % [my_player_index, players.size()])
	if my_player_index < 0 or players.is_empty():
		print("[TEST] FAIL — invalid snapshot")
		quit(1)
		return
	_my_idx = my_player_index
	var player_script = load("res://scripts/entities/player.gd")
	_gs.reset()
	_gs.is_network_game = true
	_gs.my_network_player_index = my_player_index
	for p_data in players:
		_gs.players.append(player_script.from_dict(p_data))
	_gs.turn_count = 1
	_gs.current_player_index = 0
	_gs.current_phase = PHASE_MOVEMENT
	if zone_positions.size() > 0:
		_gs.zone_positions = zone_positions
	var scene = load("res://scenes/game/game_board.tscn").instantiate()
	root.add_child(scene)
	_board = scene
	var bridge = _board.get_node_or_null("GameNetworkBridge")
	if bridge == null:
		print("[TEST] FAIL — no network bridge on rejoined board")
		quit(1)
		return
	bridge.public_state_received.connect(_on_live_state)
	# Game ending right after our rejoin still proves the rejoin worked
	_gs.game_over.connect(func(faction):
		print("[TEST] SUCCESS — game over (%s wins) right after rejoin" % faction)
		quit(0))
	print("[TEST] board rebuilt — waiting for live state from server")


func _on_live_state(_state: Dictionary) -> void:
	if _synced:
		return
	_synced = true
	print("[TEST] SUCCESS — live public state received after rejoin (turn %d, current player %d)" % [
		_gs.turn_count, _gs.current_player_index
	])
	quit(0)
