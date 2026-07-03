extends SceneTree

## E2E rejoin test, part 1: create a room, start a game with 3 bots,
## write the room code to user://e2e_room_code.txt, then drop the
## connection abruptly mid-game. Run net_rejoiner.gd afterwards.
##
## Usage (server must already run on port 9080):
##   GODOT_WS_PORT=9092 godot --headless --path . -s res://tests/e2e/net_dropper.gd

const CODE_FILE: String = "user://e2e_room_code.txt"

var _started: bool = false
var _elapsed: float = 0.0
var _game_started_at: float = -1.0
var _nm: Node = null


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _started:
		_started = true
		if FileAccess.file_exists(CODE_FILE):
			DirAccess.remove_absolute(CODE_FILE)
		_nm = root.get_node("NetworkManager")
		_nm.connected_to_server.connect(func():
			print("[TEST] connected — creating room")
			_nm.request_create_room("Testeur"))
		_nm.connection_failed.connect(func(): print("[TEST] CONNECTION FAILED"); quit(1))
		_nm.room_created.connect(func(code):
			print("[TEST] room %s — saving code, 3 bots + start" % code)
			var f = FileAccess.open(CODE_FILE, FileAccess.WRITE)
			f.store_string(code)
			f.close()
			_nm.request_set_bot_count(3)
			await create_timer(1.0).timeout
			_nm.request_start_game())
		_nm.game_started.connect(func(_p, idx, _z):
			print("[TEST] game started, I am player %d — dropping soon" % idx)
			_game_started_at = _elapsed)
		_nm.connect_to_server("ws://127.0.0.1:9080")
		return false
	if _game_started_at > 0.0 and _elapsed - _game_started_at > 8.0:
		print("[TEST] dropping connection abruptly NOW")
		quit(0)
	if _elapsed > 40.0:
		print("[TEST] TIMEOUT before game start")
		quit(1)
	return false
