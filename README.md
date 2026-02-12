# Shadow Hunter

> A premium digital adaptation of the **Shadow Hunter** board game — featuring hidden identities, strategic deduction, intelligent bot opponents, and Balatro-inspired visual polish.

![Godot 4.5](https://img.shields.io/badge/Godot-4.5-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-Language-478CBF)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Resolution](https://img.shields.io/badge/Resolution-1920x1080-blue)

---

## About

Shadow Hunter is a turn-based social deduction game for **4 to 8 players** (any mix of humans and bots). Each player is secretly assigned a character from one of three factions — **Hunters**, **Shadows**, or **Neutrals** — each with conflicting win conditions. Players move across 6 zones, draw cards, attack opponents, and use deduction to figure out who's who before it's too late.

**Key numbers:** 20 unique characters | 60+ cards across 3 decks | 6 board zones | 3 bot personality types

---

## Features

### Gameplay
- **20 Unique Characters** — 10 base + 10 expansion, each with active or passive special abilities
- **3 Factions** — Hunters (eliminate Shadows), Shadows (eliminate Hunters), Neutrals (personal objectives)
- **60+ Cards** — Vision cards for deduction, equipment for combat bonuses, instant effects
- **6 Board Zones** — 3 with card decks, 3 with special effects (heal/damage, steal equipment, choose any deck)
- **D6 + D4 Dice System** — Dice roll determines zone movement, combat uses D6 + equipment bonuses

### Bot System
- **3 Personality Types** — Aggressive, Prudent, Balanced — each with distinct strategic tendencies
- **Multi-Factor Decision Engine** — Zone scoring, threat assessment, target prioritization, risk/reward evaluation
- **Adaptive Behavior** — Bots react to revealed identities, HP thresholds, and faction knowledge

### Polish & UX
- **Balatro-Inspired Visuals** — Custom animated background shader, 3D card tilt on hover, particle effects
- **22 Sound Effects** — Combat, cards, dice, UI interactions, zone-specific ambiance
- **Tween-Based Animations** — Smooth movement, damage feedback, card reveals, dramatic ability activations
- **Tutorial System** — Step-by-step overlay guiding new players through their first game
- **Save/Load** — Auto-save every 5 actions + 3 manual save slots with metadata

### Accessibility
- **4 Colorblind Modes** — Deuteranopia, Protanopia, Tritanopia + symbol-based faction indicators
- **Adjustable Text Size** — Small / Medium / Large
- **Reduced Motion** — 70% particle reduction, 30% animation slowdown
- **Localization** — French and English

---

## Technical Highlights

### Architecture

The codebase follows an **event-driven architecture** where 16+ systems communicate exclusively through **signals** — no direct cross-references. This keeps systems decoupled, testable, and easy to extend.

**Design patterns used:**

| Pattern | Usage |
|---|---|
| **Singleton** | 6 autoloads (GameState, AudioManager, UserSettings, etc.) |
| **State Machine** | Game mode transitions, turn phase management |
| **Strategy** | Bot personalities with swappable decision weights |
| **Observer** | Signal-based UI updates and inter-system events |
| **Object Pool** | Particle effect recycling for stable frame rate |
| **Serialization** | `to_dict()` / `from_dict()` on all entities for save/load |
| **Data-Driven** | All game content defined in JSON — zero hardcoded data |

### Bot Intelligence

The bot system is split into three layers:

```
PersonalityManager          → Defines decision weights (aggression, defense, risk, card draw)
    ↓
AIDecisionEngine            → Scores zones, evaluates targets, calculates risk/reward
    ↓
BotController               → Executes actions with human-readable delays for observability
```

Each personality produces measurably different play patterns — aggressive bots attack early and often, prudent bots prioritize healing and card advantage, balanced bots adapt to the game state.

### Custom Shaders (GLSL)

- **`balatro_bg.gdshader`** — Procedural animated gradient background
- **`card_3d_tilt.gdshader`** — Mouse-reactive perspective tilt on card hover
- **`pixel_art_3d.gdshader`** — Retro pixel art depth effect

### Save System

Full game state serialization with version checking:
- Player data (HP, equipment, hand, character, faction knowledge)
- Deck states (draw pile, discard pile, card order)
- Board state (zone positions, turn counter, phase)
- Game log for replay

---

## Project Structure

```
shadow_hunter_app/
├── scripts/
│   ├── autoloads/          # 6 singletons (GameState, AudioManager, UserSettings...)
│   ├── systems/            # 16 game systems (Combat, AI, Decks, Save, Abilities...)
│   ├── entities/           # Data models (Player, Card)
│   ├── game/               # Main orchestrator (game_board.gd)
│   ├── board/              # Board components (Zone, PlayerToken, DamageTracker)
│   ├── ui/                 # 16 UI controllers (menus, popups, HUD)
│   └── utils/              # Helpers (AnimationHelper, PlayerColors)
├── scenes/
│   ├── ui/screens/         # Main menu, game setup, settings, game over
│   ├── ui/components/      # Reusable UI components
│   ├── game/               # Main game board scene
│   ├── board/              # Board-specific component scenes
│   └── cards/              # Card display scenes
├── data/
│   ├── characters.json     # 20 characters with abilities and stats
│   ├── cards.json          # 60+ cards across 3 decks
│   ├── ai_personalities.json   # Bot personality definitions
│   └── polish_config.json  # Animation and VFX tuning
├── assets/
│   ├── audio/sfx/          # 22 sound effects (.wav)
│   ├── shaders/            # 3 custom GLSL shaders
│   ├── sprites/            # Game sprites and icons
│   └── fonts/              # UI typography
└── images/                 # Card artwork (characters, zones, decks)
```

**50+ GDScript files** across 16 interconnected systems, with strict typing, standardized file organization, and consistent naming conventions.

---

## Tech Stack

| Category | Technology |
|---|---|
| Engine | Godot 4.5 |
| Language | GDScript (statically typed) |
| Shaders | GLSL (Godot Shading Language) |
| Data | JSON configuration files |
| Audio | WAV + bus-based mixing |
| VCS | Git |

---

## Getting Started

### Prerequisites
- [Godot 4.5](https://godotengine.org/download/) or later

### Run
1. Clone the repository
   ```bash
   git clone https://github.com/your-username/shadow-hunter-app.git
   ```
2. Open the project in Godot (`project.godot`)
3. Press **F5** to run — the main scene is `res://scenes/ui/screens/main_menu.tscn`

---

## Game Rules (Summary)

| Phase | Description |
|---|---|
| **Setup** | Each player receives a secret character card (Hunter, Shadow, or Neutral) |
| **Movement** | Roll D6 + D4, move to the zone matching the dice sum |
| **Action** | Draw a card from the zone's deck OR attack a player in your zone group |
| **Special Zones** | Weird Woods (damage/heal), Underworld Gate (pick any deck), Altar (steal equipment) |
| **Combat** | Roll D6 + equipment bonuses − target's defense = damage dealt |
| **Victory** | Hunters win when all Shadows are dead (and vice versa). Neutrals have personal objectives. |

Characters are revealed on death or voluntarily — revealing unlocks your special ability.

---

## Credits

Based on the **Shadow Hunters** board game by Yasutaka Ikeda (published by Game Republic / Z-Man Games).

All game mechanics faithfully adapted. Card artwork sourced from the original game.

---

## License

This project is a fan-made digital adaptation for personal and educational use.
