## DetectiveNotebook - Live deduction panel for the human player
##
## Shows, for every unrevealed opponent, the faction probabilities computed
## by BeliefTracker from PUBLIC evidence only (visions, attacks, reveals).
## The human sees exactly what a perfect logician could deduce - no cheating.
##
## Toggle: N key, or call toggle() from any button.
## Accessibility: faction letters (H/S/N) shown alongside colors.
##
## Integration: instanced by game_board.gd. Builds its whole UI in code.
class_name DetectiveNotebook
extends PanelContainer


const FACTION_COLORS: Dictionary = {
	"hunter": Color(0.35, 0.55, 1.0),
	"shadow": Color(1.0, 0.35, 0.35),
	"neutral": Color(0.95, 0.85, 0.35)
}
const FACTION_LETTERS: Dictionary = {"hunter": "H", "shadow": "S", "neutral": "N"}
const BAR_WIDTH: float = 90.0

var _rows_container: VBoxContainer
var _human: Player = null


func _ready() -> void:
	name = "DetectiveNotebook"
	visible = false
	custom_minimum_size = Vector2(340, 0)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position += Vector2(-12, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.92)
	style.border_color = Color(0.6, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = Tr.t("notebook.title")
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Tr.t("notebook.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(subtitle)

	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_rows_container)

	_find_human()
	BeliefTracker.beliefs_updated.connect(_on_beliefs_updated)


func toggle() -> void:
	visible = not visible
	if visible:
		AudioManager.play_sfx("panel_open")
		_rebuild()
	else:
		AudioManager.play_sfx("panel_close")


# Private methods

func _find_human() -> void:
	# Online: every player is flagged human on clients — use the local network index
	if GameState.is_network_game:
		var idx: int = GameState.my_network_player_index
		if idx >= 0 and idx < GameState.players.size():
			_human = GameState.players[idx]
		return
	for p in GameState.players:
		if p.is_human:
			_human = p
			return


func _rebuild() -> void:
	if _human == null:
		return

	for child in _rows_container.get_children():
		child.queue_free()

	for target in GameState.players:
		if target.id == _human.id or not target.is_alive:
			continue
		_rows_container.add_child(_build_player_row(target))


func _build_player_row(target: Player) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	# --- Line 1: name + top suspect ---
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = target.display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var suspect_label := Label.new()
	if target.is_revealed:
		suspect_label.text = "= %s ✓" % target.character_name
		suspect_label.add_theme_color_override("font_color", FACTION_COLORS.get(target.faction, Color.WHITE))
	else:
		var suspect: Dictionary = BeliefTracker.top_suspect(_human.id, target.id)
		if not suspect.is_empty() and suspect["p"] >= 0.35:
			suspect_label.text = "%s ? (%d%%)" % [suspect["name"], int(suspect["p"] * 100)]
			suspect_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		else:
			suspect_label.text = "???"
			suspect_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	suspect_label.add_theme_font_size_override("font_size", 12)
	header.add_child(suspect_label)
	row.add_child(header)

	# --- Line 2: three faction probability bars ---
	if not target.is_revealed:
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 6)
		var probs: Dictionary = BeliefTracker.get_faction_probs(_human.id, target.id)
		for faction in ["hunter", "shadow", "neutral"]:
			bars.add_child(_build_faction_bar(faction, probs.get(faction, 0.0)))
		row.add_child(bars)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.3, 0.4, 0.5))
	row.add_child(sep)
	return row


func _build_faction_bar(faction: String, p: float) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var letter := Label.new()
	letter.text = FACTION_LETTERS[faction]
	letter.add_theme_font_size_override("font_size", 11)
	letter.add_theme_color_override("font_color", FACTION_COLORS[faction])
	box.add_child(letter)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH * 0.55, 12)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = p * 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = FACTION_COLORS[faction]
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.2)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)

	var pct := Label.new()
	pct.text = "%d%%" % int(p * 100)
	pct.add_theme_font_size_override("font_size", 10)
	pct.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	pct.custom_minimum_size = Vector2(30, 0)
	box.add_child(pct)
	return box


# Signal handlers

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			toggle()


func _on_beliefs_updated(observer_id: int) -> void:
	if _human == null:
		_find_human()
	if _human != null and observer_id == _human.id and visible:
		_rebuild()
