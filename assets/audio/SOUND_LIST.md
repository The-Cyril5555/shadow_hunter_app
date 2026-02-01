# Shadow Hunter - Sound Effects List

## Naming Convention
- **Format**: `{category}_{action}.wav` or `.ogg`
- **Lowercase**: All filenames in lowercase with underscores
- **No spaces**: Use underscores instead of spaces
- **Extension**: Prefer `.wav` for SFX (lossless), `.ogg` for music (compressed)

## Required Sound Effects (22 sounds)

### UI Sounds (4 sounds)
1. `button_click.wav` - Generic button press/click
2. `button_hover.wav` - Button hover feedback (subtle)
3. `panel_open.wav` - Panel/menu opening sound
4. `panel_close.wav` - Panel/menu closing sound

### Card Sounds (3 sounds)
5. `card_draw.wav` - Card drawn from deck
6. `card_play.wav` - Card played/used
7. `card_shuffle.wav` - Deck shuffling sound

### Combat Sounds (3 sounds)
8. `attack_swing.wav` - Attack action initiated
9. `damage_hit.wav` - Damage dealt/received
10. `player_death.wav` - Player eliminated/killed

### Dice Sounds (2 sounds)
11. `dice_roll.wav` - Dice rolling sound
12. `dice_land.wav` - Dice landing/result shown

### Character Sounds (2 sounds)
13. `reveal_dramatic.wav` - Character reveal (dramatic)
14. `ability_use.wav` - Special ability activated

### Game Event Sounds (4 sounds)
15. `turn_start.wav` - Turn begins
16. `turn_end.wav` - Turn ends
17. `win_game.wav` - Victory sound
18. `lose_game.wav` - Defeat sound

### Zone/Movement Sounds (4 sounds)
19. `zone_hermit.wav` - Enter Hermit zone
20. `zone_church.wav` - Enter Church zone (White deck)
21. `zone_cemetery.wav` - Enter Cemetery zone (Black deck)
22. `move_player.wav` - Player movement on board

## Sound Characteristics

### Duration Guidelines
- **UI sounds**: 50-200ms (quick, responsive)
- **Card sounds**: 200-500ms (satisfying)
- **Combat sounds**: 300-800ms (impactful)
- **Dice sounds**: 500-1500ms (dice_roll longer)
- **Character sounds**: 800-2000ms (dramatic)
- **Game events**: 1000-3000ms (celebratory/emotional)

### Frequency Guidelines
- **UI**: 2000-8000 Hz (bright, clear)
- **Cards**: 800-3000 Hz (crisp paper/plastic)
- **Combat**: 200-1500 Hz (punchy, bass)
- **Dice**: 1000-4000 Hz (rattling, impact)
- **Character**: Full spectrum (dramatic orchestral)
- **Game events**: Full spectrum (musical)

### Volume Guidelines (RMS)
- **UI**: -18dB to -12dB (subtle)
- **Cards**: -15dB to -10dB (moderate)
- **Combat**: -12dB to -6dB (loud, impactful)
- **Dice**: -12dB to -8dB (moderate-loud)
- **Character**: -10dB to -6dB (dramatic)
- **Game events**: -8dB to -3dB (loud, celebratory)

## Placeholder Strategy (Current Implementation)

Since we don't have final audio assets yet, we'll use:

1. **Sine wave tones** - Simple generated sounds for testing
2. **Free sound libraries** - Freesound.org, OpenGameArt.org
3. **Synthesized sounds** - Godot AudioStreamGenerator for procedural sounds

## Future Sound Replacement

When replacing placeholder sounds:
1. Keep exact same filename
2. Match or exceed duration guidelines
3. Normalize to target RMS volume
4. Export as 16-bit 44.1kHz WAV or OGG
5. Test in-game for balance

## Integration Points

### UI Integration
- Main menu buttons
- Game setup screen
- All interactive controls

### Gameplay Integration
- `DeckManager.draw_card()` → `card_draw.wav`
- `DeckManager.shuffle_deck()` → `card_shuffle.wav`
- `CombatSystem.resolve_combat()` → `attack_swing.wav`, `damage_hit.wav`
- `Dice.roll()` → `dice_roll.wav`, `dice_land.wav`
- `Player.reveal_character()` → `reveal_dramatic.wav`
- `GameBoard.move_player()` → `move_player.wav`
- `GameBoard.enter_zone()` → `zone_*.wav`

## Notes
- All sounds should support ±10% pitch variation (handled by AudioManager)
- Max 10 concurrent sounds (pool limit)
- Sounds auto-stop when finished (no manual cleanup needed)
- Volume controlled via UserSettings → AudioManager → AudioServer buses
