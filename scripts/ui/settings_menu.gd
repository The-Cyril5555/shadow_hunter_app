## SettingsMenu - Settings UI controller
## Manages audio, accessibility, and localization settings
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_slider: HSlider = %MusicSlider

@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var music_value_label: Label = %MusicValueLabel

@onready var reduced_motion_checkbox: CheckBox = %ReducedMotionCheckBox

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton


# Dynamic controls (added programmatically)
var _colorblind_dropdown: OptionButton
var _text_size_dropdown: OptionButton
var _locale_dropdown: OptionButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Add accessibility/localization controls
	_build_extra_settings()

	# Load current settings into UI
	_load_current_settings()

	# Connect signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)

	reduced_motion_checkbox.toggled.connect(_on_reduced_motion_toggled)

	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

	print("[SettingsMenu] Settings menu ready")


## Build additional accessibility and localization controls
func _build_extra_settings() -> void:
	# Find the parent container of the reduced motion checkbox
	var parent = reduced_motion_checkbox.get_parent()
	if parent == null:
		push_warning("[SettingsMenu] Cannot find parent for accessibility controls")
		return

	# Colorblind mode
	var cb_row = HBoxContainer.new()
	var cb_label = Label.new()
	cb_label.text = "Mode daltonien :"
	cb_label.theme_override_font_sizes.font_size = 16
	cb_label.custom_minimum_size = Vector2(200, 0)
	cb_row.add_child(cb_label)

	_colorblind_dropdown = OptionButton.new()
	_colorblind_dropdown.add_item("Désactivé", 0)
	_colorblind_dropdown.add_item("Deutéranopie", 1)
	_colorblind_dropdown.add_item("Protanopie", 2)
	_colorblind_dropdown.add_item("Tritanopie", 3)
	_colorblind_dropdown.theme_override_font_sizes.font_size = 16
	_colorblind_dropdown.custom_minimum_size = Vector2(200, 0)
	_colorblind_dropdown.item_selected.connect(_on_colorblind_changed)
	_colorblind_dropdown.tooltip_text = "Ajoute des symboles aux factions pour distinguer sans couleur"
	cb_row.add_child(_colorblind_dropdown)
	parent.add_child(cb_row)

	# Text size
	var ts_row = HBoxContainer.new()
	var ts_label = Label.new()
	ts_label.text = "Taille du texte :"
	ts_label.theme_override_font_sizes.font_size = 16
	ts_label.custom_minimum_size = Vector2(200, 0)
	ts_row.add_child(ts_label)

	_text_size_dropdown = OptionButton.new()
	_text_size_dropdown.add_item("Petit (12px)", 0)
	_text_size_dropdown.add_item("Moyen (16px)", 1)
	_text_size_dropdown.add_item("Grand (20px)", 2)
	_text_size_dropdown.theme_override_font_sizes.font_size = 16
	_text_size_dropdown.custom_minimum_size = Vector2(200, 0)
	_text_size_dropdown.item_selected.connect(_on_text_size_changed)
	_text_size_dropdown.tooltip_text = "Ajuste la taille des textes dans le jeu"
	ts_row.add_child(_text_size_dropdown)
	parent.add_child(ts_row)

	# Language
	var loc_row = HBoxContainer.new()
	var loc_label = Label.new()
	loc_label.text = "Langue :"
	loc_label.theme_override_font_sizes.font_size = 16
	loc_label.custom_minimum_size = Vector2(200, 0)
	loc_row.add_child(loc_label)

	_locale_dropdown = OptionButton.new()
	_locale_dropdown.add_item("Français", 0)
	_locale_dropdown.add_item("English", 1)
	_locale_dropdown.theme_override_font_sizes.font_size = 16
	_locale_dropdown.custom_minimum_size = Vector2(200, 0)
	_locale_dropdown.item_selected.connect(_on_locale_changed)
	_locale_dropdown.tooltip_text = "Changer la langue du jeu"
	loc_row.add_child(_locale_dropdown)
	parent.add_child(loc_row)


## Load current UserSettings values into UI controls
func _load_current_settings() -> void:
	# Convert 0.0-1.0 to 0-100 for sliders
	master_slider.value = UserSettings.master_volume * 100.0
	sfx_slider.value = UserSettings.sfx_volume * 100.0
	music_slider.value = UserSettings.music_volume * 100.0

	# Update labels
	master_value_label.text = "%d%%" % master_slider.value
	sfx_value_label.text = "%d%%" % sfx_slider.value
	music_value_label.text = "%d%%" % music_slider.value

	# Load accessibility settings
	reduced_motion_checkbox.button_pressed = UserSettings.reduced_motion_enabled

	# Colorblind mode
	var cb_index = UserSettings.COLORBLIND_MODES.find(UserSettings.colorblind_mode)
	if cb_index >= 0:
		_colorblind_dropdown.selected = cb_index

	# Text size
	var ts_index = UserSettings.TEXT_SIZES.find(UserSettings.text_size)
	if ts_index >= 0:
		_text_size_dropdown.selected = ts_index

	# Locale
	var loc_index = UserSettings.LOCALES.find(UserSettings.locale)
	if loc_index >= 0:
		_locale_dropdown.selected = loc_index


# -----------------------------------------------------------------------------
# Volume Slider Handlers
# -----------------------------------------------------------------------------
func _on_master_slider_changed(value: float) -> void:
	var volume = value / 100.0
	UserSettings.set_master_volume(volume)
	master_value_label.text = "%d%%" % value


func _on_sfx_slider_changed(value: float) -> void:
	var volume = value / 100.0
	UserSettings.set_sfx_volume(volume)
	sfx_value_label.text = "%d%%" % value
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("card_draw")


func _on_music_slider_changed(value: float) -> void:
	var volume = value / 100.0
	UserSettings.set_music_volume(volume)
	music_value_label.text = "%d%%" % value


# -----------------------------------------------------------------------------
# Accessibility Handlers
# -----------------------------------------------------------------------------
func _on_reduced_motion_toggled(enabled: bool) -> void:
	UserSettings.set_reduced_motion(enabled)


func _on_colorblind_changed(index: int) -> void:
	var mode = UserSettings.COLORBLIND_MODES[index]
	UserSettings.set_colorblind_mode(mode)


func _on_text_size_changed(index: int) -> void:
	var size = UserSettings.TEXT_SIZES[index]
	UserSettings.set_text_size(size)


func _on_locale_changed(index: int) -> void:
	var new_locale = UserSettings.LOCALES[index]
	UserSettings.set_locale(new_locale)


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------
func _on_reset_pressed() -> void:
	# Reset to default values
	master_slider.value = 100.0
	sfx_slider.value = 100.0
	music_slider.value = 80.0
	reduced_motion_checkbox.button_pressed = false
	_colorblind_dropdown.selected = 0
	_text_size_dropdown.selected = 1
	_locale_dropdown.selected = 0

	UserSettings.set_master_volume(1.0)
	UserSettings.set_sfx_volume(1.0)
	UserSettings.set_music_volume(0.8)
	UserSettings.set_reduced_motion(false)
	UserSettings.set_colorblind_mode("none")
	UserSettings.set_text_size("medium")
	UserSettings.set_locale("fr")

	master_value_label.text = "100%"
	sfx_value_label.text = "100%"
	music_value_label.text = "80%"

	print("[SettingsMenu] Settings reset to defaults")


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
