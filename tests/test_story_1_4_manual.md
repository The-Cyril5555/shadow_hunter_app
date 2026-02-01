# Story 1.4: Dice Rolling & Movement - Manual Test Plan

## Test Environment
- Godot 4.5.1
- Resolution: 1920x1080
- Test with 4 players minimum

## Test Scenarios

### Test 1: Dice Rolling with Animation
**Acceptance Criteria:** AC1

**Steps:**
1. Start new game with 4 players
2. Click "Roll Dice" button
3. Observe dice animation

**Expected Results:**
- ✅ Both dice show rotation animation (720°)
- ✅ Both dice scale up to 1.2 then back to 1.0
- ✅ Each die shows random result 1-6
- ✅ Sum is displayed clearly ("Total: X")
- ✅ Animation is smooth (60 FPS)
- ✅ Roll Dice button disabled during animation

**Pass/Fail:** _____

---

### Test 2: Valid Zone Highlighting
**Acceptance Criteria:** AC2

**Steps:**
1. Complete dice roll (note the sum)
2. Observe zone highlighting

**Expected Results:**
- ✅ Zones reachable within dice sum are highlighted (yellow border)
- ✅ Unreachable zones remain unhighlighted
- ✅ Highlighting matches zone adjacency rules
- ✅ Starting zone (Hermit's Cabin) connections correct

**Test Cases:**
- **Dice Sum 2:** Should highlight 2 zones from Hermit (Church, Weird Woods)
- **Dice Sum 3:** Should highlight up to 3 steps away
- **Dice Sum 12:** Should highlight all zones (entire board reachable)

**Pass/Fail:** _____

---

### Test 3: Character Movement
**Acceptance Criteria:** AC3

**Steps:**
1. Roll dice
2. Click on a highlighted zone
3. Observe player token movement

**Expected Results:**
- ✅ Player token moves from current zone to selected zone
- ✅ Movement is animated smoothly (not instant teleport)
- ✅ Movement uses CUBIC easing over 0.6s
- ✅ Bounce effect at end (scale 1.1 → 1.0)
- ✅ Token correctly reparented to new zone
- ✅ Zone highlights cleared after movement
- ✅ No input allowed during animation

**Pass/Fail:** _____

---

### Test 4: Turn Phase Advancement
**Acceptance Criteria:** AC4

**Steps:**
1. Observe initial phase (should be "Phase: Movement")
2. Roll dice
3. Move to a zone
4. Observe phase change

**Expected Results:**
- ✅ Initial phase: "Phase: Movement"
- ✅ After movement completes: "Phase: Action"
- ✅ Phase label updates correctly
- ✅ Roll Dice button disabled in ACTION phase
- ✅ Phase label color: yellow/gold

**Pass/Fail:** _____

---

### Test 5: Zone Adjacency System
**Acceptance Criteria:** AC2 (Zone adjacency validation)

**Zone Adjacency Map:**
```
hermit → [church, weird_woods]
church → [hermit, cemetery, altar]
cemetery → [church, underworld, weird_woods]
weird_woods → [hermit, cemetery, underworld]
underworld → [cemetery, weird_woods, altar]
altar → [church, underworld]
```

**Test Cases:**
1. **From Hermit, Dice Sum 1:** Should highlight Church, Weird Woods
2. **From Hermit, Dice Sum 2:** Should highlight Church, Cemetery, Altar, Weird Woods, Underworld
3. **From Church, Dice Sum 1:** Should highlight Hermit, Cemetery, Altar
4. **From Altar, Dice Sum 1:** Should highlight Church, Underworld

**Pass/Fail:** _____

---

### Test 6: Edge Cases
**Acceptance Criteria:** All

**Test 6.1: Minimum Dice Roll (2)**
- Roll dice until sum = 2
- Verify only adjacent zones (1-2 steps) highlighted

**Test 6.2: Maximum Dice Roll (12)**
- Roll dice until sum = 12
- Verify all zones highlighted (entire board reachable)

**Test 6.3: Click Non-Highlighted Zone**
- Roll dice
- Click on non-highlighted zone
- Verify no movement, warning logged

**Test 6.4: Roll During Animation**
- Roll dice
- Immediately click Roll Dice button again
- Verify button disabled, no double-roll

**Test 6.5: Movement Input Block**
- Roll dice
- Click highlighted zone to start movement
- During animation, click another zone
- Verify input blocked, no interruption

**Pass/Fail:** _____

---

### Test 7: Full Game Flow
**Acceptance Criteria:** All

**Steps:**
1. Start game with 4 players
2. Player 1: Roll dice → Move → End turn
3. Player 2: Roll dice → Move → End turn
4. Player 3: Roll dice → Move → End turn
5. Player 4: Roll dice → Move → End turn
6. Verify turn counter increments to 2
7. Verify Player 1 active again

**Expected Results:**
- ✅ Turn count increments correctly
- ✅ Current player cycles through all players
- ✅ Phase resets to MOVEMENT for each new player
- ✅ All player tokens moved to new zones
- ✅ Console logs show correct turn flow

**Pass/Fail:** _____

---

### Test 8: Performance (60 FPS)
**Acceptance Criteria:** Architecture requirement

**Steps:**
1. Enable FPS counter in Godot
2. Roll dice and move multiple times
3. Monitor FPS during animations

**Expected Results:**
- ✅ Dice animation maintains 60 FPS
- ✅ Movement animation maintains 60 FPS
- ✅ No frame drops during transitions
- ✅ Logic budget < 5ms per frame
- ✅ Render budget < 8ms per frame

**Pass/Fail:** _____

---

## Test Summary

**Total Tests:** 8
**Passed:** _____
**Failed:** _____

**Critical Issues Found:**
1. _____
2. _____
3. _____

**Notes:**
_____

---

## Console Log Validation

**Expected Log Sequence (1 turn):**
```
[GameBoard] Initializing game board
[GameBoard] Initialized 6 zones
[GameBoard] Placed 4 player tokens in starting zone
[GameBoard] Game started with 4 players
[GameBoard] Rolling dice...
[GameBoard] Dice rolled: 7
[GameBoard] Highlighted 5 reachable zones from hermit with distance 7
[GameBoard] Zone clicked: Church by Player 1
[GameBoard] Moved Player 1 from Hermit's Cabin to Church
[GameState] Phase: MOVEMENT → ACTION
[GameBoard] Phase changed to: 1
[GameBoard] Turn ended. Now: Player 2, Turn 1
[GameState] Phase: ACTION → END
[GameState] Phase: END → MOVEMENT (Next player: Player 2, Turn 1)
```

**Actual Log:**
_____

---

## Regression Testing

**Previous Stories to Verify:**
- ✅ Story 1.1: Main Menu still loads correctly
- ✅ Story 1.2: Game Setup still works (4-8 players, human/bot selection)
- ✅ Story 1.3: Board zones still display correctly
- ✅ Story 1.3: Player tokens still placed at starting zone
- ✅ Story 1.3: Deck counts still display correctly

**Pass/Fail:** _____
