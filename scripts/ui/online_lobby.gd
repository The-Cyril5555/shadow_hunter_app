## OnlineLobby - Online multiplayer lobby screen
## Handles room creation/joining and shows player list before game start.
class_name OnlineLobby
extends Control


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const SERVER_URL_PROD: String = "wss://shadow-hunter-app.onrender.com"
const SERVER_URL_DEV: String = "ws://localhost:9080"
const HEALTH_URL: String = "https://shadow-hunter-app.onrender.com/health"
const KEEPALIVE_INTERVAL: float = 600.0  # 10 minutes — prevent Render free-tier spin-down
const RETRY_DELAY: float = 30.0
const MAX_RETRIES: int = 4


# -----------------------------------------------------------------------------
# UI References (set in _build_ui)
# -----------------------------------------------------------------------------
var _name_input: LineEdit
var _code_input: LineEdit
var _status_label: Label
var _room_code_label: Label
var _player_list: VBoxContainer
var _create_btn: Button
var _join_btn: Button
var _start_btn: Button
var _back_btn: Button
var _main_panel: Control
var _lobby_panel: Control
var _custom_url_input: LineEdit


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
var _is_host: bool = false
var _connected: bool = false
var _ping_http: HTTPRequest
var _ping_timer: Timer
var _retry_timer: Timer
var _retry_count: int = 0


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	_build_ui()
	_connect_network_signals()
	_setup_keepalive()
	print("[OnlineLobby] Ready")


func _exit_tree() -> void:
	_disconnect_network_signals()


# -----------------------------------------------------------------------------
# UI Building
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 32)
	center.add_child(outer_vbox)

	# Title
	var title = Label.new()
	title.text = "SHADOW HUNTER — EN LIGNE"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	# Main panel (create/join)
	_main_panel = _build_main_panel()
	outer_vbox.add_child(_main_panel)

	# Lobby panel (player list + start)
	_lobby_panel = _build_lobby_panel()
	_lobby_panel.visible = false
	outer_vbox.add_child(_lobby_panel)

	# Back button
	_back_btn = Button.new()
	_back_btn.text = "← Retour"
	_back_btn.custom_minimum_size = Vector2(200, 44)
	_back_btn.add_theme_font_size_override("font_size", 18)
	_back_btn.pressed.connect(_on_back_pressed)
	outer_vbox.add_child(_back_btn)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = ""
	outer_vbox.add_child(_status_label)


func _build_main_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 32
	style.content_margin_top = 28
	style.content_margin_right = 32
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Name input
	var name_label = Label.new()
	name_label.text = "Votre nom"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Entrez votre nom..."
	_name_input.custom_minimum_size = Vector2(0, 44)
	_name_input.add_theme_font_size_override("font_size", 18)
	_name_input.max_length = 20
	vbox.add_child(_name_input)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Create room button
	_create_btn = Button.new()
	_create_btn.text = "Créer une partie"
	_create_btn.custom_minimum_size = Vector2(0, 50)
	_create_btn.add_theme_font_size_override("font_size", 20)
	_create_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_create_btn.pressed.connect(_on_create_pressed)
	vbox.add_child(_create_btn)

	# OR separator
	var or_lbl = Label.new()
	or_lbl.text = "— ou —"
	or_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(or_lbl)

	# Code input + join button
	var join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	vbox.add_child(join_row)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "Code du salon (ex: 1234)"
	_code_input.custom_minimum_size = Vector2(0, 44)
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.add_theme_font_size_override("font_size", 18)
	_code_input.max_length = 6
	join_row.add_child(_code_input)

	_join_btn = Button.new()
	_join_btn.text = "Rejoindre"
	_join_btn.custom_minimum_size = Vector2(140, 44)
	_join_btn.add_theme_font_size_override("font_size", 18)
	_join_btn.pressed.connect(_on_join_pressed)
	join_row.add_child(_join_btn)

	# Advanced: custom server URL (for ngrok / local host)
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var url_label = Label.new()
	url_label.text = "Serveur perso (ngrok / local) — laisser vide pour Render"
	url_label.add_theme_font_size_override("font_size", 12)
	url_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(url_label)

	_custom_url_input = LineEdit.new()
	_custom_url_input.placeholder_text = "wss://xxxx.ngrok-free.app  ou  ws://localhost:9080"
	_custom_url_input.custom_minimum_size = Vector2(0, 38)
	_custom_url_input.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_custom_url_input)

	return panel


func _build_lobby_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.06, 0.16, 0.95)
	style.border_color = Color(0.4, 0.7, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 32
	style.content_margin_top = 24
	style.content_margin_right = 32
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Room code display
	var code_row = HBoxContainer.new()
	vbox.add_child(code_row)

	var code_title = Label.new()
	code_title.text = "Code du salon : "
	code_title.add_theme_font_size_override("font_size", 18)
	code_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	code_row.add_child(code_title)

	_room_code_label = Label.new()
	_room_code_label.add_theme_font_size_override("font_size", 28)
	_room_code_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_room_code_label.text = "----"
	code_row.add_child(_room_code_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Player list title
	var players_title = Label.new()
	players_title.text = "Joueurs connectés"
	players_title.add_theme_font_size_override("font_size", 16)
	players_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vbox.add_child(players_title)

	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_player_list)

	# Start button (host only)
	_start_btn = Button.new()
	_start_btn.text = "Lancer la partie"
	_start_btn.custom_minimum_size = Vector2(0, 50)
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_start_btn.visible = false
	_start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_btn)

	return panel


# -----------------------------------------------------------------------------
# Network Signal Connections
# -----------------------------------------------------------------------------
func _connect_network_signals() -> void:
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_join_failed.connect(_on_room_join_failed)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.game_started.connect(_on_game_started)


func _disconnect_network_signals() -> void:
	if not is_instance_valid(NetworkManager):
		return
	if NetworkManager.connected_to_server.is_connected(_on_connected_to_server):
		NetworkManager.connected_to_server.disconnect(_on_connected_to_server)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
	if NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.disconnect(_on_server_disconnected)
	if NetworkManager.room_created.is_connected(_on_room_created):
		NetworkManager.room_created.disconnect(_on_room_created)
	if NetworkManager.room_joined.is_connected(_on_room_joined):
		NetworkManager.room_joined.disconnect(_on_room_joined)
	if NetworkManager.room_join_failed.is_connected(_on_room_join_failed):
		NetworkManager.room_join_failed.disconnect(_on_room_join_failed)
	if NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
		NetworkManager.lobby_updated.disconnect(_on_lobby_updated)
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)


# -----------------------------------------------------------------------------
# Signal Handlers — UI
# -----------------------------------------------------------------------------
func _on_create_pressed() -> void:
	var player_name = _name_input.text.strip_edges()
	if player_name.is_empty():
		_set_status("Entrez votre nom avant de créer une partie.", Color(1.0, 0.5, 0.3))
		return
	_set_status("Connexion au serveur...", Color(0.7, 0.8, 1.0))
	_set_buttons_disabled(true)
	_is_host = true
	var url = _get_server_url()
	NetworkManager.connect_to_server(url)


func _on_join_pressed() -> void:
	var player_name = _name_input.text.strip_edges()
	var code = _code_input.text.strip_edges()
	if player_name.is_empty():
		_set_status("Entrez votre nom.", Color(1.0, 0.5, 0.3))
		return
	if code.is_empty():
		_set_status("Entrez un code de salon.", Color(1.0, 0.5, 0.3))
		return
	_set_status("Connexion au serveur...", Color(0.7, 0.8, 1.0))
	_set_buttons_disabled(true)
	_is_host = false
	var url = _get_server_url()
	NetworkManager.connect_to_server(url)
	# Store code for after connection
	_code_input.text = code


func _on_start_pressed() -> void:
	if not _is_host:
		return
	_set_status("Lancement de la partie...", Color(0.5, 1.0, 0.5))
	_start_btn.disabled = true
	NetworkManager.request_start_game()


func _on_back_pressed() -> void:
	_retry_count = 0
	if is_instance_valid(_retry_timer):
		_retry_timer.stop()
	AudioManager.play_sfx("button_click")
	NetworkManager.disconnect_from_server()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# Signal Handlers — Network
# -----------------------------------------------------------------------------
func _on_connected_to_server() -> void:
	_retry_count = 0
	_connected = true
	var player_name = _name_input.text.strip_edges()
	if _is_host:
		_set_status("Connecté. Création du salon...", Color(0.7, 0.8, 1.0))
		NetworkManager.request_create_room(player_name)
	else:
		_set_status("Connecté. Rejoindre le salon...", Color(0.7, 0.8, 1.0))
		var code = _code_input.text.strip_edges()
		NetworkManager.request_join_room(code, player_name)


func _on_connection_failed() -> void:
	_connected = false
	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		_set_status("Connexion échouée. Nouvelle tentative %d/%d dans 30s..." % [_retry_count, MAX_RETRIES], Color(1.0, 0.75, 0.3))
		_start_retry_timer()
	else:
		_retry_count = 0
		_set_buttons_disabled(false)
		_set_status("Impossible de se connecter. Vérifiez votre connexion.", Color(1.0, 0.4, 0.4))


func _on_server_disconnected() -> void:
	_connected = false
	_lobby_panel.visible = false
	_main_panel.visible = true
	_set_buttons_disabled(false)
	_set_status("Déconnecté du serveur.", Color(1.0, 0.5, 0.3))


func _on_room_created(code: String) -> void:
	_room_code_label.text = code
	_main_panel.visible = false
	_lobby_panel.visible = true
	_start_btn.visible = true
	_start_btn.disabled = true  # Wait for minimum players
	_set_status("Salon créé ! Partagez le code avec vos amis.", Color(0.5, 1.0, 0.5))
	_update_player_list([{"name": _name_input.text.strip_edges(), "id": multiplayer.get_unique_id()}])


func _on_room_joined(code: String, players: Array) -> void:
	_room_code_label.text = code
	_main_panel.visible = false
	_lobby_panel.visible = true
	_start_btn.visible = false  # Only host sees start button
	_set_status("Salon rejoint ! En attente du lancement...", Color(0.5, 1.0, 0.5))
	_update_player_list(players)


func _on_room_join_failed(reason: String) -> void:
	_set_buttons_disabled(false)
	match reason:
		"room_not_found":
			_set_status("Code de salon invalide.", Color(1.0, 0.4, 0.4))
		"game_already_started":
			_set_status("La partie a déjà commencé.", Color(1.0, 0.4, 0.4))
		"room_full":
			_set_status("Le salon est complet (8 joueurs max).", Color(1.0, 0.4, 0.4))
		_:
			_set_status("Impossible de rejoindre le salon.", Color(1.0, 0.4, 0.4))
	NetworkManager.disconnect_from_server()


func _on_lobby_updated(players: Array) -> void:
	_update_player_list(players)
	# Enable start if host and >= 2 players
	if _is_host:
		_start_btn.disabled = players.size() < 2


func _on_game_started(initial_players: Array, my_player_index: int) -> void:
	_set_status("La partie commence !", Color(0.3, 1.0, 0.5))
	# Reconstruct GameState from initial data received from server
	GameState.reset()
	GameState.is_network_game = true
	GameState.my_network_player_index = my_player_index
	for p_data in initial_players:
		var player = Player.from_dict(p_data)
		GameState.players.append(player)
	GameState.turn_count = 1
	GameState.current_player_index = 0
	GameState.current_phase = GameState.TurnPhase.MOVEMENT
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME)


# -----------------------------------------------------------------------------
# UI Helpers
# -----------------------------------------------------------------------------
func _update_player_list(players: Array) -> void:
	for child in _player_list.get_children():
		child.queue_free()

	for player_data in players:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = Color(0.4, 1.0, 0.4)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)

		var name_lbl = Label.new()
		name_lbl.text = player_data.get("name", "Joueur")
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		row.add_child(name_lbl)

		if player_data.get("id", 0) == multiplayer.get_unique_id():
			var you_lbl = Label.new()
			you_lbl.text = "(vous)"
			you_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
			you_lbl.add_theme_font_size_override("font_size", 14)
			row.add_child(you_lbl)

		_player_list.add_child(row)

	# Enable start when >= 2 players (host only)
	if _is_host and is_instance_valid(_start_btn):
		_start_btn.disabled = players.size() < 2


func _set_status(text: String, color: Color = Color.WHITE) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)


func _set_buttons_disabled(disabled: bool) -> void:
	if is_instance_valid(_create_btn):
		_create_btn.disabled = disabled
	if is_instance_valid(_join_btn):
		_join_btn.disabled = disabled


func _get_server_url() -> String:
	# Custom URL takes priority (use ws://localhost:9080 for local server)
	if is_instance_valid(_custom_url_input):
		var custom: String = _custom_url_input.text.strip_edges()
		if custom != "":
			return custom
	return SERVER_URL_PROD


# -----------------------------------------------------------------------------
# Connection Retry — handles Render cold-start race condition
# -----------------------------------------------------------------------------
func _start_retry_timer() -> void:
	if not is_instance_valid(_retry_timer):
		_retry_timer = Timer.new()
		_retry_timer.one_shot = true
		_retry_timer.timeout.connect(_do_retry)
		add_child(_retry_timer)
	_retry_timer.start(RETRY_DELAY)


func _do_retry() -> void:
	if not is_visible_in_tree():
		return
	_set_status("Reconnexion en cours...", Color(0.7, 0.8, 1.0))
	NetworkManager.connect_to_server(_get_server_url())


# -----------------------------------------------------------------------------
# Server Keepalive — prevents Render free-tier from spinning down
# -----------------------------------------------------------------------------
func _setup_keepalive() -> void:
	_ping_http = HTTPRequest.new()
	add_child(_ping_http)
	_ping_http.request_completed.connect(_on_ping_completed)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = KEEPALIVE_INTERVAL
	_ping_timer.one_shot = false
	_ping_timer.autostart = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	_set_status("Vérification du serveur...", Color(0.7, 0.7, 0.9))
	_send_ping()


func _send_ping() -> void:
	if not is_instance_valid(_ping_http):
		return
	if _ping_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # Already in progress
	_ping_http.request(HEALTH_URL)


func _on_ping_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_set_status("Serveur en ligne ✓", Color(0.4, 1.0, 0.5))
		if not _ping_timer.is_stopped():
			pass  # Already running
		else:
			_ping_timer.start()
	else:
		# Server sleeping — let user know, they can retry in a minute
		_set_status("Serveur en cours de démarrage... réessayez dans ~1 minute.", Color(1.0, 0.75, 0.3))
