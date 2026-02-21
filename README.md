# Shadow Hunter

> Adaptation digitale du jeu de plateau **Shadow Hunter** — identités cachées, déduction stratégique, adversaires bots intelligents et rendu visuel inspiré de Balatro.

![Godot 4.5](https://img.shields.io/badge/Godot-4.5-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-Language-478CBF)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Resolution](https://img.shields.io/badge/Resolution-1920x1080-blue)

<img width="3839" height="2022" alt="image" src="https://github.com/user-attachments/assets/b13fcddd-92b2-4280-b0ca-4d72c130bb2d" />


## Presentation

Shadow Hunter est un jeu de déduction sociale au tour par tour pour **4 à 8 joueurs** (humains et/ou bots). Chaque joueur reçoit secrètement un personnage appartenant à l'une des trois factions — **Hunters**, **Shadows** ou **Neutres** — avec des conditions de victoire opposées. Les joueurs se déplacent entre 6 zones, piochent des cartes, attaquent leurs adversaires et utilisent la déduction pour identifier les rôles de chacun.

**En chiffres :** 20 personnages uniques | 60+ cartes réparties en 3 paquets | 6 zones de jeu | 3 types de personnalité bot

---

## Fonctionnalites

### Gameplay
- **20 Personnages uniques** — 10 de base + 10 extension, chacun avec une capacité active ou passive
- **3 Factions** — Hunters (éliminer les Shadows), Shadows (éliminer les Hunters), Neutres (objectif personnel)
- **60+ Cartes** — Cartes vision pour la déduction, équipements pour les bonus de combat, effets instantanés
- **6 Zones de jeu** — 3 avec paquets de cartes, 3 avec effets spéciaux (soin/dégâts, vol d'équipement, choix de paquet)
- **Système de dés D6 + D4** — Le lancer détermine le déplacement, le combat utilise D6 + bonus d'équipement

### Systeme de bots
- **3 Types de personnalité** — Agressif, Prudent, Équilibré — chacun avec des tendances stratégiques distinctes
- **Moteur de décision multi-facteurs** — Scoring de zones, évaluation des menaces, priorisation de cibles, analyse risque/récompense
- **Comportement adaptatif** — Les bots réagissent aux identités révélées, aux seuils de PV et à la connaissance des factions

### Polish et UX
- **Visuels inspirés de Balatro** — Shader de fond animé, effet 3D au survol des cartes, particules
- **22 Effets sonores** — Combat, cartes, dés, interactions UI, ambiance par zone
- **Animations Tween** — Déplacements fluides, feedback de dégâts, révélations de cartes, activations de capacités
- **Système de tutoriel** — Overlay pas-à-pas guidant les nouveaux joueurs
- **Sauvegarde/Chargement** — Auto-save toutes les 5 actions + 3 emplacements manuels avec métadonnées

### Accessibilite
- **4 Modes daltonien** — Deutéranopie, Protanopie, Tritanopie + indicateurs de faction par symboles
- **Taille de texte ajustable** — Petit / Moyen / Grand
- **Mouvements réduits** — Réduction de 70% des particules, ralentissement de 30% des animations
- **Localisation** — Français et anglais

---

## Points techniques

### Architecture

Le code suit une **architecture événementielle** où 16+ systèmes communiquent exclusivement par **signaux** — aucune référence croisée directe. Cela maintient les systèmes découplés, testables et faciles à étendre.

**Design patterns utilisés :**

| Pattern | Utilisation |
|---|---|
| **Singleton** | 6 autoloads (GameState, AudioManager, UserSettings, etc.) |
| **State Machine** | Transitions de mode de jeu, gestion des phases de tour |
| **Strategy** | Personnalités bot avec poids de décision interchangeables |
| **Observer** | Mises à jour UI par signaux et événements inter-systèmes |
| **Object Pool** | Recyclage des effets de particules pour un framerate stable |
| **Serialization** | `to_dict()` / `from_dict()` sur toutes les entités pour la sauvegarde |
| **Data-Driven** | Tout le contenu de jeu défini en JSON — zéro donnée en dur |

### Intelligence des bots

Le système de bots est divisé en trois couches :

```
PersonalityManager          → Définit les poids de décision (agression, défense, risque, pioche)
    ↓
AIDecisionEngine            → Score les zones, évalue les cibles, calcule le risque/récompense
    ↓
BotController               → Exécute les actions avec des délais lisibles pour l'observation humaine
```

Chaque personnalité produit des patterns de jeu mesurables et distincts — les bots agressifs attaquent tôt et souvent, les prudents privilégient le soin et l'avantage en cartes, les équilibrés s'adaptent à l'état de la partie.

### Shaders custom (GLSL)

- **`balatro_bg.gdshader`** — Fond animé avec gradient procédural
- **`card_3d_tilt.gdshader`** — Effet de perspective 3D réactif au survol de la souris
- **`pixel_art_3d.gdshader`** — Effet rétro pixel art avec profondeur

### Systeme de sauvegarde

Sérialisation complète de l'état de jeu avec vérification de version :
- Données joueur (PV, équipement, main, personnage, connaissance des factions)
- États des paquets (pioche, défausse, ordre des cartes)
- État du plateau (positions dans les zones, compteur de tours, phase)
- Journal de partie pour le replay

---

## Structure du projet

```
shadow_hunter_app/
├── scripts/
│   ├── autoloads/          # 6 singletons (GameState, AudioManager, UserSettings...)
│   ├── systems/            # 16 systèmes de jeu (Combat, IA, Paquets, Sauvegarde, Capacités...)
│   ├── entities/           # Modèles de données (Player, Card)
│   ├── game/               # Orchestrateur principal (game_board.gd)
│   ├── board/              # Composants du plateau (Zone, PlayerToken, DamageTracker)
│   ├── ui/                 # 16 contrôleurs UI (menus, popups, HUD)
│   └── utils/              # Utilitaires (AnimationHelper, PlayerColors)
├── scenes/
│   ├── ui/screens/         # Menu principal, configuration, paramètres, fin de partie
│   ├── ui/components/      # Composants UI réutilisables
│   ├── game/               # Scène du plateau de jeu
│   ├── board/              # Scènes des composants du plateau
│   └── cards/              # Scènes d'affichage des cartes
├── data/
│   ├── characters.json     # 20 personnages avec capacités et stats
│   ├── cards.json          # 60+ cartes réparties en 3 paquets
│   ├── ai_personalities.json   # Définitions des personnalités bot
│   └── polish_config.json  # Paramètres d'animation et VFX
├── assets/
│   ├── audio/sfx/          # 22 effets sonores (.wav)
│   ├── shaders/            # 3 shaders GLSL custom
│   ├── sprites/            # Sprites et icônes du jeu
│   └── fonts/              # Typographie UI
└── images/                 # Illustrations des cartes (personnages, zones, paquets)
```

**50+ fichiers GDScript** répartis sur 16 systèmes interconnectés, avec typage strict, organisation standardisée et conventions de nommage cohérentes.

---

## Stack technique

| Catégorie | Technologie |
|---|---|
| Moteur | Godot 4.5 |
| Langage | GDScript (typage statique) |
| Shaders | GLSL (Godot Shading Language) |
| Données | Fichiers de configuration JSON |
| Audio | WAV + mixage par bus |
| VCS | Git |

---

## Demarrage rapide

### Prérequis
- [Godot 4.5](https://godotengine.org/download/) ou supérieur

### Lancement
1. Cloner le dépôt
   ```bash
   git clone https://github.com/The-Cyril5555/shadow_hunter_app.git
   ```
2. Ouvrir le projet dans Godot (`project.godot`)
3. Appuyer sur **F5** pour lancer — la scène principale est `res://scenes/ui/screens/main_menu.tscn`

---

## Regles du jeu (resume)

| Phase | Description |
|---|---|
| **Mise en place** | Chaque joueur reçoit une carte personnage secrète (Hunter, Shadow ou Neutre) |
| **Déplacement** | Lancer D6 + D4, se déplacer vers la zone correspondant à la somme |
| **Action** | Piocher une carte du paquet de la zone OU attaquer un joueur dans le même groupe de zones |
| **Zones spéciales** | Weird Woods (dégâts/soin), Underworld Gate (choisir n'importe quel paquet), Altar (voler un équipement) |
| **Combat** | Lancer D6 + bonus d'équipement − défense de la cible = dégâts infligés |
| **Victoire** | Les Hunters gagnent quand tous les Shadows sont morts (et inversement). Les Neutres ont des objectifs personnels. |

Les personnages sont révélés à leur mort ou volontairement — la révélation débloque la capacité spéciale.

---

## Credits

Basé sur le jeu de plateau **Shadow Hunters** de Yasutaka Ikeda (édité par Game Republic / Z-Man Games).

Mécaniques de jeu fidèlement adaptées. Illustrations des cartes issues du jeu original.

---

## Licence

Ce projet est une adaptation digitale fan-made à usage personnel et éducatif.
