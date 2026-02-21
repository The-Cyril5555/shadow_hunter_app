## PlayerEquipmentPopup - Shows a player's equipment and hand cards on click
class_name PlayerEquipmentPopup
extends PanelContainer


# -----------------------------------------------------------------------------
# UI References
# -----------------------------------------------------------------------------
var _title_label: Label
var _equip_container: VBoxContainer
var _hand_container: VBoxContainer


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	_build_ui()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show popup with a player's equipment and hand
func show_player(player: Player) -> void:
	_populate(player)
	_show_animated()


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

func _populate(player: Player) -> void:
	_title_label.text = PlayerColors.get_label(player)

	for child in _equip_container.get_children():
		child.queue_free()
	for child in _hand_container.get_children():
		child.queue_free()

	if player.equipment.is_empty():
		_add_empty_label(_equip_container, Tr.t("popup.no_equipment"))
	else:
		for card in player.equipment:
			_add_card_label(_equip_container, card, Color(1.0, 0.85, 0.3))

	if player.hand.is_empty():
		_add_empty_label(_hand_container, Tr.t("popup.no_hand"))
	else:
		for card in player.hand:
			_add_card_label(_hand_container, card, Color(0.7, 0.9, 1.0))


func _build_ui() -> void:
	custom_minimum_size = Vector2(380, 0)
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -190
	offset_top = -160
	offset_right = 190
	offset_bottom = 160
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header row: title + close button
	var header = HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Equipment section
	var equip_title = Label.new()
	equip_title.text = Tr.t("popup.equipment_title")
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	vbox.add_child(equip_title)

	_equip_container = VBoxContainer.new()
	_equip_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_equip_container)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Hand section
	var hand_title = Label.new()
	hand_title.text = Tr.t("popup.hand_title")
	hand_title.add_theme_font_size_override("font_size", 14)
	hand_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(hand_title)

	_hand_container = VBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_hand_container)


func _add_card_label(container: VBoxContainer, card: Card, color: Color) -> void:
	var lbl = Label.new()
	var effect_desc = card.effect.get("description", "")
	if effect_desc != "":
		lbl.text = "• %s — %s" % [card.name, effect_desc]
	else:
		lbl.text = "• %s" % card.name
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(lbl)


func _add_empty_label(container: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(lbl)


func _show_animated() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
