# Hodoku Notation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this session) or subagent-driven-development.

**Goal:** Teaching copy and hint text use Hodoku cell/candidate/chain notation instead of 「第 x 行第 x 列」.

**Architecture:** One `notation.dart` helper. Finders and the hint drawer call it. Teaching walkthroughs are rewritten to the same tokens; chain techniques include one `=`/`-` expression.

**Tech Stack:** Flutter / Dart, existing `SudokuHint` / `TechniqueInfo`.

## Global Constraints

- Notation: cell `r3c5`, candidate `6r3c5`, row/col/box `r3`/`c5`/`b5`, strong `=`, weak `-`, fill `填 r3c5=8`, elim `删 6r1c2, 6r1c5`.
- Package remains `sudoku_app`.
- Do not change catalog IDs, example puzzles, or board drawing.
- `flutter test` and `flutter analyze` must pass.

---

### Task 1: notation helper

**Files:**
- Create: `lib/models/notation.dart`
- Create: `test/notation_test.dart`

**Interfaces:**
- Produces:
```dart
String cellRef(int row, int col); // 0-based → r3c5
String candRef(int row, int col, int digit);
String rowRef(int row);
String colRef(int col);
String boxRef(int boxRow, int boxCol); // 0-based box coords → b1..b9
String fillLine(int row, int col, int digit);
String elimLine(Iterable<({int row, int col, int digit})> elims);
String chainExpr(List<MarkupArrow> arrows);
```

- [ ] **Step 1: Failing tests** in `test/notation_test.dart` for the signatures above (`cellRef(2,4)=='r3c5'`, `candRef(2,4,6)=='6r3c5'`, `boxRef(0,0)=='b1'`, `boxRef(2,2)=='b9'`, fill/elim/chain samples).
- [ ] **Step 2: FAIL**
- [ ] **Step 3: Implement `lib/models/notation.dart`**
- [ ] **Step 4: Tests pass**
- [ ] **Step 5: Commit** `feat: add Hodoku cell and chain notation helpers`

---

### Task 2: Hint explanations + drawer line

**Files:**
- Modify: `lib/services/sudoku_solver.dart` — `_allUnits` labels, `_boxLabel`, every `explanation:`
- Modify: `lib/services/advanced_techniques.dart` — same
- Modify: `lib/screens/game_screen.dart` — ready-hint `detail` line
- Modify: `test/hint_apply_button_test.dart` or new `test/hint_notation_test.dart` if any assertion depends on old copy

**Interfaces:**
- Consumes: `cellRef`, `candRef`, `rowRef`, `colRef`, `boxRef`, `fillLine`, `elimLine`, `chainExpr`
- Produces: no `第 ${row + 1} 行` / `格子 (r,c)` in generated explanations

Unit labels: `r1` / `c1` / `b5` (not Chinese 第 n 行).
Drawer: fill → `fillLine`; elim → `elimLine` from `hint.eliminations`.
If `hint.links` is non-empty, append `\n` + `chainExpr(hint.links)`.

- [ ] **Step 1: Test** a classic-board hint explanation contains `r` and does not contain `第`+`行第`
- [ ] **Step 2: FAIL**
- [ ] **Step 3: Rewrite finder strings**
- [ ] **Step 4: `flutter test` focused files + analyze**
- [ ] **Step 5: Commit** `fix: use Hodoku notation in hint explanations`

---

### Task 3: Teaching walkthroughs

**Files:**
- Modify: `lib/models/technique_examples_basic.dart`
- Modify: `lib/models/technique_examples_fish.dart`
- Modify: `lib/models/technique_examples_wings.dart`
- Modify: `lib/models/technique_examples_chains.dart`
- Modify: `test/technique_catalog_test.dart`

**Interfaces:**
- Walkthrough (and any howToSpot/definition/caveats that name cells) use `r3c5` / `6r3c5`.
- Chain-family entries include at least one ` = ` and ` - ` expression matching their markup arrows via `chainExpr`.
- Completeness test: no catalog text matches `第\\s*\\d+\\s*行第`.

- [ ] **Step 1: Add the completeness assertion (FAIL)**
- [ ] **Step 2: Rewrite copy; chain pages call `chainExpr` on their arrow list**
- [ ] **Step 3: Tests pass**
- [ ] **Step 4: Commit** `fix: use Hodoku notation in teaching walkthroughs`

---
