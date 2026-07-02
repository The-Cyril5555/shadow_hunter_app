## BeliefTracker - Bayesian faction deduction engine (Autoload)
##
## Maintains, for every observer, a probability distribution over which
## character each other player might be. Updates from PUBLIC evidence only:
## - Character reveals (hard evidence + exclusivity propagation)
## - Vision card results (faction conditions, hp_max conditions)
##   including Unknown's "Duperie" lie handling
## - Attack patterns (soft evidence: attackers rarely hit allies)
##
## Pattern: Autoload Node, event-driven via GameState signals (zero coupling)
## Usage:
##   BeliefTracker.p_enemy(bot, target)                  -> float 0..1
##   BeliefTracker.get_faction_probs(bot.id, target.id)  -> {hunter, shadow, neutral}
##   BeliefTracker.pick_max_entropy_target(bot, targets) -> Player (best vision target)
##   BeliefTracker.top_suspect(bot.id, target.id)        -> {char_id, name, p}
extends Node


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted whenever any observer's beliefs change (UI refresh hook)
signal beliefs_updated(observer_id: int)


# =============================================================================
# CONSTANTS - Evidence strength tuning
# =============================================================================

## Weight kept on "unknown" when a faction vision fails on them (Duperie lie)
const LIE_WEIGHT: float = 0.85
## Multiplier on attacker-faction characters for the victim (revealed attacker)
const ATTACK_EVIDENCE_REVEALED: float = 0.80
## Same but when the attacker is not revealed (much weaker evidence)
const ATTACK_EVIDENCE_HIDDEN: float = 0.95
## If true, observers know exactly which characters are in play (public lineup).
## If false, they reason over the full roster (harder deduction).
const KNOW_EXACT_POOL: bool = true

const FACTIONS: Array = ["hunter", "shadow", "neutral"]


# =============================================================================
# STATE
# =============================================================================

## char_id -> {"faction": String, "hp_max": int, "name": String}
var _char_pool: Dictionary = {}
## observer_id -> { target_id -> { char_id -> weight (float, unnormalized) } }
var _beliefs: Dictionary = {}
var _initialized: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	GameState.turn_started.connect(_on_turn_started)
	GameState.character_revealed.connect(_on_character_revealed)
	GameState.damage_dealt.connect(_on_damage_dealt)
	GameState.game_reset.connect(reset)
	if GameState.has_signal("vision_resolved"):
		GameState.vision_resolved.connect(_on_vision_resolved)
	print("[BeliefTracker] Ready - waiting for first turn to build priors")


## Reset all beliefs (new game)
func reset() -> void:
	_char_pool.clear()
	_beliefs.clear()
	_initialized = false
	print("[BeliefTracker] Reset")


# =============================================================================
# INITIALIZATION - Build uniform priors
# =============================================================================

func _on_turn_started(_player, _turn_number: int) -> void:
	if not _initialized:
		# First turn of a new game, or loaded mid-game without save data:
		# build best-effort priors from current public state
		_initialize_from_game()


func _initialize_from_game() -> void:
	var players: Array = GameState.players
	if players.is_empty():
		return

	_build_character_pool(players)

	for observer in players:
		var obs_beliefs: Dictionary = {}
		for target in players:
			if target.id == observer.id:
				continue
			var row: Dictionary = {}
			for char_id in _char_pool.keys():
				# An observer knows their own character: exclude it from candidates
				if char_id == observer.character_id:
					continue
				row[char_id] = 1.0
			obs_beliefs[target.id] = row
		_beliefs[observer.id] = obs_beliefs

	_initialized = true
	print("[BeliefTracker] Priors built: %d observers, %d characters in pool" % [
		players.size(), _char_pool.size()
	])

	# Retro-apply already-revealed players (e.g. game loaded from save)
	for p in players:
		if p.is_revealed:
			_apply_reveal(p.id, p.character_id)


func _build_character_pool(players: Array) -> void:
	_char_pool.clear()
	if KNOW_EXACT_POOL:
		# Lineup of characters in play is public knowledge (mirrors board game setup)
		for p in players:
			if p.character_id != "":
				_char_pool[p.character_id] = {
					"faction": p.faction,
					"hp_max": p.hp_max,
					"name": p.character_name
				}
	else:
		# Reason over the full roster loaded from JSON
		var file = FileAccess.open("res://data/characters.json", FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data and data.has("characters"):
				for char_id in data["characters"].keys():
					var c: Dictionary = data["characters"][char_id]
					_char_pool[char_id] = {
						"faction": c.get("faction", "neutral"),
						"hp_max": int(c.get("hp_max", 10)),
						"name": c.get("name", char_id)
					}


# =============================================================================
# EVIDENCE HANDLERS - Hard evidence
# =============================================================================

## Build priors on first evidence if turn_started hasn't fired yet (e.g. turn 1)
func _ensure_initialized() -> bool:
	if not _initialized:
		_initialize_from_game()
	return _initialized


func _on_character_revealed(player, _character, _faction: String) -> void:
	if not _ensure_initialized():
		return
	_apply_reveal(player.id, player.character_id)


## Reveal: certainty for the target + exclusivity elimination everywhere else
func _apply_reveal(target_id: int, char_id: String) -> void:
	for observer_id in _beliefs.keys():
		var obs: Dictionary = _beliefs[observer_id]
		for tid in obs.keys():
			var row: Dictionary = obs[tid]
			if tid == target_id:
				# Certainty: only the revealed character survives
				for cid in row.keys():
					row[cid] = 1.0 if cid == char_id else 0.0
			else:
				# Exclusivity: nobody else can be that character
				if row.has(char_id):
					row[char_id] = 0.0
			_repair_row_if_dead(row, tid)
		beliefs_updated.emit(observer_id)
	print("[BeliefTracker] Reveal applied: player %d is '%s'" % [target_id, char_id])


# =============================================================================
# EVIDENCE HANDLERS - Vision cards (the heart of the deduction)
# =============================================================================

## Public vision result. effect comes straight from the card JSON.
## condition_met reflects what everyone SAW (a Duperie lie shows as false).
func _on_vision_resolved(_drawer, target, effect: Dictionary, condition_met: bool) -> void:
	if not _ensure_initialized():
		return

	var condition_factions: Array = effect.get("condition_factions", [])
	var condition_type: String = effect.get("condition_type", "")
	var cond_value: int = effect.get("condition_value", 0)

	for observer_id in _beliefs.keys():
		if observer_id == target.id:
			continue  # Target knows who they are
		var row: Dictionary = _beliefs[observer_id].get(target.id, {})
		if row.is_empty():
			continue

		if condition_type != "":
			# HP-based visions: physically impossible to lie about
			for cid in row.keys():
				var hp_max: int = int(_char_pool[cid]["hp_max"])
				var matches: bool = false
				match condition_type:
					"hp_max_lte":
						matches = hp_max <= cond_value
					"hp_max_gte":
						matches = hp_max >= cond_value
				if matches != condition_met:
					row[cid] = 0.0
		elif not condition_factions.is_empty():
			for cid in row.keys():
				var in_faction: bool = _char_pool[cid]["faction"] in condition_factions
				if condition_met:
					# Effect fired: target's real faction IS in the list
					if not in_faction:
						row[cid] = 0.0
				else:
					# No effect: either faction not in list... or Unknown lied
					if in_faction:
						if cid == "unknown":
							row[cid] *= LIE_WEIGHT
						else:
							row[cid] = 0.0

		_repair_row_if_dead(row, target.id)
		beliefs_updated.emit(observer_id)

	print("[BeliefTracker] Vision evidence on %s (met=%s, factions=%s, type=%s)" % [
		target.display_name, condition_met, condition_factions, condition_type
	])


# =============================================================================
# EVIDENCE HANDLERS - Soft evidence
# =============================================================================

## Attacks correlate with faction opposition: dampen the belief that the
## victim shares the attacker's (known or suspected) faction.
func _on_damage_dealt(attacker, victim, amount: int) -> void:
	if attacker == null or victim == null or amount <= 0:
		return
	if not _ensure_initialized():
		return
	if attacker.id == victim.id:
		return  # Self-damage (Weird Woods etc.) says nothing

	for observer_id in _beliefs.keys():
		if observer_id == victim.id:
			continue
		var row: Dictionary = _beliefs[observer_id].get(victim.id, {})
		if row.is_empty():
			continue

		if attacker.is_revealed and attacker.faction != "neutral":
			for cid in row.keys():
				if _char_pool[cid]["faction"] == attacker.faction:
					row[cid] *= ATTACK_EVIDENCE_REVEALED
		else:
			# Hidden attacker: infer via observer's beliefs about the attacker
			var att_probs: Dictionary = get_faction_probs(observer_id, attacker.id)
			var dominant: String = _dominant_faction(att_probs)
			if dominant != "neutral" and att_probs.get(dominant, 0.0) > 0.5:
				for cid in row.keys():
					if _char_pool[cid]["faction"] == dominant:
						row[cid] *= ATTACK_EVIDENCE_HIDDEN

		beliefs_updated.emit(observer_id)


# =============================================================================
# PUBLIC API - Queries
# =============================================================================

## Normalized character probabilities: {char_id -> p}
func get_char_probs(observer_id: int, target_id: int) -> Dictionary:
	var row: Dictionary = _beliefs.get(observer_id, {}).get(target_id, {})
	var total: float = 0.0
	for w in row.values():
		total += w
	var probs: Dictionary = {}
	if total <= 0.0:
		return probs
	for cid in row.keys():
		probs[cid] = row[cid] / total
	return probs


## Faction probabilities: {"hunter": p, "shadow": p, "neutral": p}
func get_faction_probs(observer_id: int, target_id: int) -> Dictionary:
	var probs: Dictionary = {"hunter": 0.0, "shadow": 0.0, "neutral": 0.0}
	var char_probs: Dictionary = get_char_probs(observer_id, target_id)
	for cid in char_probs.keys():
		probs[_char_pool[cid]["faction"]] += char_probs[cid]
	return probs


## Probability (0..1) that target belongs to the observer's OPPOSING faction.
## Neutral observers have no faction enemy -> returns 0.5 (indifference).
func p_enemy(observer: Player, target: Player) -> float:
	if target.is_revealed:
		if observer.faction == "neutral" or target.faction == "neutral":
			return 0.5
		return 1.0 if target.faction != observer.faction else 0.0
	var probs: Dictionary = get_faction_probs(observer.id, target.id)
	match observer.faction:
		"hunter":
			return probs.get("shadow", 0.0)
		"shadow":
			return probs.get("hunter", 0.0)
		_:
			return 0.5


## Probability that target is an ALLY of the observer (same non-neutral faction)
func p_ally(observer: Player, target: Player) -> float:
	if observer.faction == "neutral":
		return 0.0
	if target.is_revealed:
		return 1.0 if target.faction == observer.faction else 0.0
	return get_faction_probs(observer.id, target.id).get(observer.faction, 0.0)


## Shannon entropy of the faction distribution (0 = certain, ~1.58 = max doubt)
func get_entropy(observer_id: int, target_id: int) -> float:
	var probs: Dictionary = get_faction_probs(observer_id, target_id)
	var h: float = 0.0
	for p in probs.values():
		if p > 0.0001:
			h -= p * (log(p) / log(2.0))
	return h


## Most probable character for a target: {"char_id", "name", "p"}
func top_suspect(observer_id: int, target_id: int) -> Dictionary:
	var char_probs: Dictionary = get_char_probs(observer_id, target_id)
	var best_id: String = ""
	var best_p: float = -1.0
	for cid in char_probs.keys():
		if char_probs[cid] > best_p:
			best_p = char_probs[cid]
			best_id = cid
	if best_id == "":
		return {}
	return {"char_id": best_id, "name": _char_pool[best_id]["name"], "p": best_p}


## Best vision target = the player the observer knows the LEAST about
## (maximum expected information gain). Falls back to random if uninitialized.
func pick_max_entropy_target(observer: Player, candidates: Array) -> Player:
	if candidates.is_empty():
		return null
	if not _initialized:
		return candidates[randi() % candidates.size()]
	var best: Player = candidates[0]
	var best_h: float = -1.0
	for t in candidates:
		if t.is_revealed:
			continue  # Nothing left to learn
		var h: float = get_entropy(observer.id, t.id)
		if h > best_h:
			best_h = h
			best = t
	return best


# =============================================================================
# NETWORK SYNC — server computes beliefs, each client receives its own view
# =============================================================================

## Server: serialize one observer's beliefs + the character pool (network-safe keys)
func get_observer_snapshot(observer_id: int) -> Dictionary:
	if not _ensure_initialized():
		return {}
	var rows_out: Dictionary = {}
	var obs: Dictionary = _beliefs.get(observer_id, {})
	for tid in obs.keys():
		rows_out[str(tid)] = obs[tid].duplicate()
	return {
		"char_pool": _char_pool.duplicate(true),
		"rows": rows_out,
	}


## Client: apply the server-computed beliefs for the local observer
func apply_observer_snapshot(observer_id: int, snapshot: Dictionary) -> void:
	var pool: Dictionary = snapshot.get("char_pool", {})
	if pool.is_empty():
		return
	_char_pool = pool.duplicate(true)
	var rows: Dictionary = {}
	for tid_str in snapshot.get("rows", {}).keys():
		rows[int(tid_str)] = snapshot["rows"][tid_str].duplicate()
	_beliefs[observer_id] = rows
	_initialized = true
	beliefs_updated.emit(observer_id)


# =============================================================================
# SAVE / LOAD
# =============================================================================

func to_dict() -> Dictionary:
	# Dictionary keys must be strings for JSON round-tripping
	var beliefs_out: Dictionary = {}
	for oid in _beliefs.keys():
		var targets_out: Dictionary = {}
		for tid in _beliefs[oid].keys():
			targets_out[str(tid)] = _beliefs[oid][tid].duplicate()
		beliefs_out[str(oid)] = targets_out
	return {
		"char_pool": _char_pool.duplicate(true),
		"beliefs": beliefs_out,
		"initialized": _initialized
	}


func from_dict(data: Dictionary) -> void:
	_char_pool = data.get("char_pool", {}).duplicate(true)
	_beliefs.clear()
	var beliefs_in: Dictionary = data.get("beliefs", {})
	for oid_str in beliefs_in.keys():
		var targets: Dictionary = {}
		for tid_str in beliefs_in[oid_str].keys():
			targets[int(tid_str)] = beliefs_in[oid_str][tid_str].duplicate()
		_beliefs[int(oid_str)] = targets
	_initialized = data.get("initialized", false)
	print("[BeliefTracker] State restored from save")


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Contradictory evidence (accumulated lies) can zero a row: reset to uniform
## over still-plausible characters instead of leaving the bot brain-dead.
func _repair_row_if_dead(row: Dictionary, target_id: int) -> void:
	var total: float = 0.0
	for w in row.values():
		total += w
	if total > 0.0:
		return
	push_warning("[BeliefTracker] Contradiction on player %d - resetting row" % target_id)
	var taken: Dictionary = {}
	for p in GameState.players:
		if p.is_revealed:
			taken[p.character_id] = true
	for cid in row.keys():
		row[cid] = 0.0 if taken.has(cid) else 1.0


func _dominant_faction(probs: Dictionary) -> String:
	var best: String = "neutral"
	var best_p: float = -1.0
	for f in probs.keys():
		if probs[f] > best_p:
			best_p = probs[f]
			best = f
	return best
