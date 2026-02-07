## TutorialOverlay - Step-by-step interactive tutorial overlay
##
## Guides new players through game mechanics with highlighted UI elements
## and contextual instructions. Each step waits for user action or "Next".
class_name TutorialOverlay
extends CanvasLayer


# =============================================================================
# SIGNALS
# =============================================================================

signal tutorial_completed()
signal tutorial_skipped()
signal step_action_required(action: String)


# =============================================================================
# CONSTANTS
# =============================================================================

const STEPS: Array[Dictionary] = [
	{
		"title": "Bienvenue dans Shadow Hunter !",
		"text": "Ce tutoriel vous guidera à travers les mécaniques de base du jeu.\n\nShadow Hunter est un jeu de plateau où des Hunters, Shadows et Neutres s'affrontent dans l'ombre. Votre identité est secrète !",
		"action": "next",
	},
	{
		"title": "Le plateau de jeu",
		"text": "Le plateau comporte 6 zones. Chaque zone a des propriétés différentes :\n\n• 3 zones ont un deck de cartes (Hermite, Lumière, Ténèbres)\n• 3 zones n'ont pas de deck\n\nLes zones sont connectées entre elles pour le déplacement.",
		"action": "next",
	},
	{
		"title": "Phase 1 : Mouvement",
		"text": "Chaque tour commence par la phase de mouvement.\n\nCliquez sur le bouton « Lancer les dés » pour déterminer votre distance de déplacement.",
		"action": "roll_dice",
		"highlight": "roll_dice_button",
	},
	{
		"title": "Choisir une zone",
		"text": "Les zones accessibles sont maintenant en surbrillance jaune.\n\nCliquez sur une zone en surbrillance pour vous y déplacer. Essayez de choisir une zone avec un deck de cartes !",
		"action": "move_to_zone",
	},
	{
		"title": "Phase 2 : Action",
		"text": "Après le mouvement, vous entrez en phase d'action. Vous pouvez :\n\n• Piocher une carte du deck de votre zone\n• Attaquer un joueur dans votre zone\n• Terminer votre tour\n\nCliquez sur « Piocher une carte » si un deck est disponible.",
		"action": "draw_card_or_next",
		"highlight": "draw_card_button",
	},
	{
		"title": "Les cartes",
		"text": "Il y a 3 types de cartes :\n\n• Instantanée — Effet immédiat (soin ou dégâts)\n• Équipement — Ajoutée à votre main, à équiper pour des bonus\n• Vision — Devinez la faction d'un autre joueur\n\nLes cartes équipement apparaissent dans votre main à gauche.",
		"action": "next",
	},
	{
		"title": "Le combat",
		"text": "Pour attaquer, vous devez être dans la même zone qu'un autre joueur.\n\nLes dégâts = D6 + bonus d'équipement.\nSi les HP d'un joueur tombent à 0, il meurt et son personnage est révélé.",
		"action": "next",
	},
	{
		"title": "Factions et victoire",
		"text": "3 factions avec des objectifs différents :\n\n• HUNTERS — Éliminer tous les Shadows\n• SHADOWS — Éliminer tous les Hunters\n• NEUTRALS — Objectif personnel unique\n\nVotre faction est secrète. Vous pouvez vous révéler pour activer des capacités spéciales.",
		"action": "next",
	},
	{
		"title": "Commandes utiles",
		"text": "• Échap — Menu pause (sauvegarde, chargement)\n• F1 — Aide et règles complètes\n• Survolez les éléments pour voir les tooltips\n\nVous pouvez rejouer ce tutoriel depuis le menu principal à tout moment.",
		"action": "next",
	},
	{
		"title": "Tutoriel terminé !",
		"text": "Vous connaissez maintenant les bases de Shadow Hunter !\n\nCliquez « Terminer » pour retourner au menu principal et commencer une vraie partie.",
		"action": "finish",
	},
]


# =============================================================================
# PROPERTIES
# =============================================================================

var _current_step: int = 0
var _panel: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _next_button: Button
var _skip_button: Button
var _step_counter: Label
var _waiting_for_action: String = ""


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_step(0)


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Notify the tutorial that an action was performed
func notify_action(action: String) -> void:
	if _waiting_for_action == "" or not visible:
		return

	# Check if the performed action matches what we're waiting for
	var matches = false
	match _waiting_for_action:
		"roll_dice":
			matches = (action == "roll_dice")
		"move_to_zone":
			matches = (action == "move_to_zone")
		"draw_card_or_next":
			matches = (action == "draw_card")

	if matches:
		_waiting_for_action = ""
		_advance_step()


## Check if tutorial is active and waiting for a specific action
func is_waiting_for(action: String) -> bool:
	return _waiting_for_action != "" and visible


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	# Semi-transparent overlay (doesn't block all input)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.3)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks through
	add_child(overlay)

	# Instruction panel at bottom
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 0.7
	margin.add_theme_constant_override("margin_left", 250)
	margin.add_theme_constant_override("margin_right", 250)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.9, 0.3, 0.8)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_step_counter = Label.new()
	_step_counter.add_theme_font_size_override("font_size", 14)
	_step_counter.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	header.add_child(_step_counter)

	# Content
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(_text_label)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_skip_button = Button.new()
	_skip_button.text = "Passer le tutoriel"
	_skip_button.add_theme_font_size_override("font_size", 14)
	_skip_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.add_theme_font_size_override("font_size", 18)
	_next_button.custom_minimum_size = Vector2(120, 40)
	_next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_button)


# =============================================================================
# STEP MANAGEMENT
# =============================================================================

func _show_step(index: int) -> void:
	if index < 0 or index >= STEPS.size():
		return

	_current_step = index
	var step = STEPS[index]

	_title_label.text = step.title
	_text_label.text = step.text
	_step_counter.text = "%d/%d" % [index + 1, STEPS.size()]

	var action = step.get("action", "next")
	_waiting_for_action = ""

	match action:
		"next":
			_next_button.text = "Suivant"
			_next_button.visible = true
		"finish":
			_next_button.text = "Terminer"
			_next_button.visible = true
		"roll_dice":
			_next_button.text = "En attente..."
			_next_button.visible = false
			_waiting_for_action = "roll_dice"
			step_action_required.emit("roll_dice")
		"move_to_zone":
			_next_button.text = "En attente..."
			_next_button.visible = false
			_waiting_for_action = "move_to_zone"
			step_action_required.emit("move_to_zone")
		"draw_card_or_next":
			_next_button.text = "Passer cette étape"
			_next_button.visible = true
			_waiting_for_action = "draw_card_or_next"
			step_action_required.emit("draw_card")

	print("[Tutorial] Step %d: %s" % [index + 1, step.title])


func _advance_step() -> void:
	if _current_step + 1 < STEPS.size():
		_show_step(_current_step + 1)
	else:
		_finish_tutorial()


func _finish_tutorial() -> void:
	visible = false
	tutorial_completed.emit()
	print("[Tutorial] Completed")


# =============================================================================
# HANDLERS
# =============================================================================

func _on_next_pressed() -> void:
	var step = STEPS[_current_step]
	var action = step.get("action", "next")

	if action == "finish":
		_finish_tutorial()
	else:
		_advance_step()


func _on_skip_pressed() -> void:
	visible = false
	tutorial_skipped.emit()
	print("[Tutorial] Skipped at step %d" % (_current_step + 1))
