## AudioDemo - Interactive audio system demo
## Test all sound effects, volume controls, and pitch variation
class_name AudioDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var master_volume_slider: HSlider = $VBoxContainer/VolumeControls/MasterVolume/Slider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/VolumeControls/SFXVolume/Slider
@onready var master_value_label: Label = $VBoxContainer/VolumeControls/MasterVolume/ValueLabel
@onready var sfx_value_label: Label = $VBoxContainer/VolumeControls/SFXVolume/ValueLabel

@onready var active_sounds_label: Label = $VBoxContainer/InfoPanel/ActiveSoundsLabel
@onready var pool_size_label: Label = $VBoxContainer/InfoPanel/PoolSizeLabel


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Setup volume sliders
	master_volume_slider.value = 1.0
	sfx_volume_slider.value = 1.0
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	# Connect all sound test buttons
	_connect_sound_buttons()

	# Connect back button
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)

	# Update info display
	_update_info_display()

	print("[AudioDemo] Audio demo ready")


func _process(_delta: float) -> void:
	# Update active sound count every frame
	_update_info_display()


# -----------------------------------------------------------------------------
# Sound Button Connections
# -----------------------------------------------------------------------------
func _connect_sound_buttons() -> void:
	# UI Sounds
	$VBoxContainer/SoundTestPanel/UISounds/ButtonClickBtn.pressed.connect(func(): AudioManager.play_sfx("button_click"))
	$VBoxContainer/SoundTestPanel/UISounds/ButtonHoverBtn.pressed.connect(func(): AudioManager.play_sfx("button_hover"))
	$VBoxContainer/SoundTestPanel/UISounds/PanelOpenBtn.pressed.connect(func(): AudioManager.play_sfx("panel_open"))
	$VBoxContainer/SoundTestPanel/UISounds/PanelCloseBtn.pressed.connect(func(): AudioManager.play_sfx("panel_close"))

	# Card Sounds
	$VBoxContainer/SoundTestPanel/CardSounds/CardDrawBtn.pressed.connect(func(): AudioManager.play_sfx("card_draw"))
	$VBoxContainer/SoundTestPanel/CardSounds/CardPlayBtn.pressed.connect(func(): AudioManager.play_sfx("card_play"))
	$VBoxContainer/SoundTestPanel/CardSounds/CardShuffleBtn.pressed.connect(func(): AudioManager.play_sfx("card_shuffle"))

	# Combat Sounds
	$VBoxContainer/SoundTestPanel/CombatSounds/AttackSwingBtn.pressed.connect(func(): AudioManager.play_sfx("attack_swing"))
	$VBoxContainer/SoundTestPanel/CombatSounds/DamageHitBtn.pressed.connect(func(): AudioManager.play_sfx("damage_hit"))
	$VBoxContainer/SoundTestPanel/CombatSounds/PlayerDeathBtn.pressed.connect(func(): AudioManager.play_sfx("player_death"))

	# Dice Sounds
	$VBoxContainer/SoundTestPanel/DiceSounds/DiceRollBtn.pressed.connect(func(): AudioManager.play_sfx("dice_roll"))
	$VBoxContainer/SoundTestPanel/DiceSounds/DiceLandBtn.pressed.connect(func(): AudioManager.play_sfx("dice_land"))

	# Character Sounds
	$VBoxContainer/SoundTestPanel/CharacterSounds/RevealBtn.pressed.connect(func(): AudioManager.play_sfx("reveal_dramatic"))
	$VBoxContainer/SoundTestPanel/CharacterSounds/AbilityBtn.pressed.connect(func(): AudioManager.play_sfx("ability_use"))

	# Game Event Sounds
	$VBoxContainer/SoundTestPanel/GameEventSounds/TurnStartBtn.pressed.connect(func(): AudioManager.play_sfx("turn_start"))
	$VBoxContainer/SoundTestPanel/GameEventSounds/TurnEndBtn.pressed.connect(func(): AudioManager.play_sfx("turn_end"))
	$VBoxContainer/SoundTestPanel/GameEventSounds/WinGameBtn.pressed.connect(func(): AudioManager.play_sfx("win_game"))
	$VBoxContainer/SoundTestPanel/GameEventSounds/LoseGameBtn.pressed.connect(func(): AudioManager.play_sfx("lose_game"))

	# Zone/Movement Sounds
	$VBoxContainer/SoundTestPanel/ZoneSounds/ZoneHermitBtn.pressed.connect(func(): AudioManager.play_sfx("zone_hermit"))
	$VBoxContainer/SoundTestPanel/ZoneSounds/ZoneChurchBtn.pressed.connect(func(): AudioManager.play_sfx("zone_church"))
	$VBoxContainer/SoundTestPanel/ZoneSounds/ZoneCemeteryBtn.pressed.connect(func(): AudioManager.play_sfx("zone_cemetery"))
	$VBoxContainer/SoundTestPanel/ZoneSounds/MovePlayerBtn.pressed.connect(func(): AudioManager.play_sfx("move_player"))


# -----------------------------------------------------------------------------
# Volume Controls
# -----------------------------------------------------------------------------
func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value)
	master_value_label.text = "%.0f%%" % (value * 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	sfx_value_label.text = "%.0f%%" % (value * 100.0)


# -----------------------------------------------------------------------------
# Info Display
# -----------------------------------------------------------------------------
func _update_info_display() -> void:
	active_sounds_label.text = "Active Sounds: %d" % AudioManager.get_active_sound_count()
	pool_size_label.text = "Pool Size: %d" % AudioManager.get_pool_size()


# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------
func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
