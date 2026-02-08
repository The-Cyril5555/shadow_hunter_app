## HelpMenu - In-game help overlay with searchable rules
##
## Accessible via F1 key or "?" button. Shows game rules organized by topic.
## Covers: setup, movement, combat, cards, characters, win conditions.
class_name HelpMenu
extends CanvasLayer


# =============================================================================
# CONSTANTS
# =============================================================================

const RULES: Array[Dictionary] = [
	{
		"title": "Mise en place",
		"content": """• 4 à 8 joueurs (humains et/ou bots)
• Chaque joueur reçoit un personnage secret avec une faction (Hunter, Shadow ou Neutral)
• Les personnages ont des HP et une capacité spéciale unique
• Tous les joueurs commencent à la Cabane de l'Ermite
• 3 decks de cartes sont placés : Hermite, Lumière, Ténèbres"""
	},
	{
		"title": "Déroulement d'un tour",
		"content": """Chaque tour se déroule en 2 phases :

1. MOUVEMENT — Lancez les dés (d6+d4) et déplacez-vous vers la zone correspondant au résultat
2. ACTION — Choisissez une action :
   • Piocher une carte du deck de votre zone
   • Attaquer un joueur présent dans votre zone
   • Terminer votre tour sans action"""
	},
	{
		"title": "Zones du plateau",
		"content": """Le plateau comporte 6 zones :

• Cabane de l'Ermite — Deck Hermite (cartes de vision)
• Église — Deck Lumière (soins, protection)
• Cimetière — Deck Ténèbres (dégâts, malus)
• Forêt Étrange — Pas de deck
• Porte des Enfers — Pas de deck
• Autel Ancien — Pas de deck

Chaque zone a une plage de numéros (2-3, 4-5, 6, 7, 8-9, 10). Le résultat des dés détermine directement la zone de destination."""
	},
	{
		"title": "Cartes",
		"content": """Il existe 3 types de cartes :

• Instantanée — Effet appliqué immédiatement (soin, dégâts)
• Équipement — Ajoutée à votre main, peut être équipée pour des bonus permanents
• Vision — Permet de deviner la faction d'un autre joueur

Les cartes équipement peuvent être équipées (+dégâts, +défense) ou défaussées."""
	},
	{
		"title": "Combat",
		"content": """Pour attaquer :
• Vous devez être dans la même zone que votre cible
• Les dégâts sont calculés avec un D6 + bonus d'équipement
• Si les HP de la cible tombent à 0, elle meurt
• Un personnage mort est révélé automatiquement"""
	},
	{
		"title": "Factions et victoire",
		"content": """3 factions avec des objectifs différents :

• HUNTERS — Gagnent quand tous les Shadows sont morts
• SHADOWS — Gagnent quand tous les Hunters sont morts
• NEUTRALS — Chacun a un objectif personnel unique

Votre faction est secrète ! Vous pouvez vous révéler volontairement pour activer certaines capacités."""
	},
	{
		"title": "Capacités spéciales",
		"content": """Chaque personnage a une capacité unique :

• Passive — S'active automatiquement (ex: réduction de dégâts)
• Active — Activation manuelle, parfois nécessite d'être révélé

Certaines capacités sont plus puissantes une fois révélé, mais révéler votre faction donne des informations à vos adversaires."""
	},
	{
		"title": "Sauvegarde",
		"content": """• Auto-save toutes les 5 actions majeures
• 3 emplacements de sauvegarde manuelle
• Accessible via le menu pause (Échap)
• Chargement depuis le menu principal ou le menu pause"""
	},
	{
		"title": "Raccourcis clavier",
		"content": """• Échap — Menu pause
• F1 — Aide et règles (ce menu)
• Survolez n'importe quel élément pour voir son tooltip"""
	},
]


# =============================================================================
# PROPERTIES
# =============================================================================

var _overlay: ColorRect
var _content_container: VBoxContainer
var _search_field: LineEdit
var _sections: Array[Dictionary] = []  # {label: Label, content: RichTextLabel, title: String}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 101  # Above pause menu
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if visible:
			hide_help()
		else:
			show_help()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC METHODS
# =============================================================================

func show_help() -> void:
	visible = true
	_search_field.text = ""
	_filter_sections("")
	_search_field.grab_focus()
	get_tree().paused = true
	print("[HelpMenu] Opened")


func hide_help() -> void:
	visible = false
	# Only unpause if pause menu isn't also open
	if not get_tree().paused:
		return
	# Check if a PauseMenu is visible
	var pause_menus = get_tree().get_nodes_in_group("pause_menu")
	var pause_visible = false
	for pm in pause_menus:
		if pm.visible:
			pause_visible = true
			break
	if not pause_visible:
		get_tree().paused = false
	print("[HelpMenu] Closed")


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.8)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	_overlay.add_child(margin)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "AIDE & RÈGLES"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "Fermer (F1)"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(hide_help)
	header.add_child(close_btn)

	# Search field
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Rechercher..."
	_search_field.add_theme_font_size_override("font_size", 16)
	_search_field.text_changed.connect(_filter_sections)
	vbox.add_child(_search_field)

	# Separator
	vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 16)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_container)

	# Build rule sections
	for rule in RULES:
		var section = _create_section(rule.title, rule.content)
		_content_container.add_child(section.container)
		_sections.append(section)


func _create_section(title_text: String, content_text: String) -> Dictionary:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	container.add_child(title_label)

	var content_label = RichTextLabel.new()
	content_label.bbcode_enabled = false
	content_label.fit_content = true
	content_label.text = content_text.strip_edges()
	content_label.add_theme_font_size_override("normal_font_size", 15)
	content_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	content_label.scroll_active = false
	container.add_child(content_label)

	return {
		"container": container,
		"label": title_label,
		"content": content_label,
		"title": title_text.to_lower(),
		"text": content_text.to_lower(),
	}


# =============================================================================
# SEARCH / FILTER
# =============================================================================

func _filter_sections(query: String) -> void:
	var q = query.strip_edges().to_lower()
	for section in _sections:
		if q == "":
			section.container.visible = true
		else:
			var matches = section.title.contains(q) or section.text.contains(q)
			section.container.visible = matches
