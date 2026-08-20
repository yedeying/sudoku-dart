# Board Markup Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make on-board markup exclusive and predictable, keep auto candidates independent from pencil notes, highlight same digits only when markup is off, and show hint text under the board instead of covering it.

**Architecture:** `SudokuBoard` exposes a visible candidate union. `GameState` owns `MarkupMode` and routes cell/number taps. `SudokuGrid` renders circle candidate colors, chain anchors, and same-digit weak highlight without writing markup. `HintPanel` sits between the grid and controls. `AppTheme` seed is near-black; markup palette stays a separate color list.

**Tech Stack:** Flutter/Dart, `provider`, `flutter_test`.

## Global Constraints

- Do not add solver techniques in this plan.
- Same-digit highlight must not write `BoardMarkup` or use the color palette.
- Number pad must not combine fill, color, and full-board filter in one unmodeled tap.
- App chrome is black/white/gray; gold/green/blue/red exist only on markup and hints.
- Manual conjugate chip is removed; conjugate arrows come only from auto conjugate (rows, columns, and boxes).
- Spec: `docs/superpowers/specs/2026-08-20-board-markup-interaction-design.md`.

## File map

- Modify: `lib/models/sudoku_board.dart` — `visibleCandidates`
- Modify: `lib/models/board_markup.dart` — `MarkupMode`, `MarkupPalette`
- Modify: `lib/models/game_state.dart` — mode routing, conjugate scan, hint session flag
- Modify: `lib/widgets/sudoku_grid.dart` — union display, circles, anchor, weak same-digit highlight
- Create: `lib/widgets/hint_panel.dart`
- Modify: `lib/screens/game_screen.dart` — toolbar, pad, hint panel, stop covering dialogs
- Modify: `lib/theme/app_theme.dart` — near-black seed
- Test: `test/visible_candidates_test.dart`, `test/markup_mode_test.dart`, `test/same_digit_highlight_test.dart`, `test/auto_conjugate_test.dart`, `test/hint_panel_test.dart`

---

### Task 1: Visible candidate union

**Files:**
- Create: `test/visible_candidates_test.dart`
- Modify: `lib/models/sudoku_board.dart`
- Modify: `lib/widgets/sudoku_grid.dart` (`_buildCandidates`)

**Interfaces:**
- Consumes: existing `candidates`, `userCandidates`
- Produces: `Set<int> SudokuBoard.visibleCandidates(int row, int col)` — empty if cell filled; otherwise `candidates[row][col] ∪ userCandidates[row][col]`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';

void main() {
  test('笔记加上 2 不会丢掉自动候选 8', () {
    final board = SudokuBoard.fromString(
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    );
    // (0,2) is empty in this classic puzzle; force auto set to {8}
    board.candidates[0][2] = {8};
    board.userCandidates[0][2] = {};
    board.toggleUserCandidate(0, 2, 2);
    expect(board.visibleCandidates(0, 2), {2, 8});
    expect(board.getCandidates(0, 2), {8});
    expect(board.getUserCandidates(0, 2), {2});
  });
}
```

If `(0,2)` is filled in that string, pick any empty cell and assign `candidates` the same way. Do not use `userCands.isNotEmpty ? user : auto` in the test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/visible_candidates_test.dart`

Expected: FAIL because `visibleCandidates` is undefined.

- [ ] **Step 3: Write minimal implementation**

Add on `SudokuBoard`:

```dart
Set<int> visibleCandidates(int row, int col) {
  if (board[row][col] != 0) return {};
  return {...candidates[row][col], ...userCandidates[row][col]};
}
```

In `sudoku_grid.dart` `_buildCandidates`, replace the ternary with:

```dart
final autoCands = board.getCandidates(row, col);
final userCands = board.getUserCandidates(row, col);
final candidates = board.visibleCandidates(row, col);
```

Bold a digit when `userCands.contains(num)` or it has a candidate color. Auto-only digits stay normal weight.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/visible_candidates_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/visible_candidates_test.dart lib/models/sudoku_board.dart lib/widgets/sudoku_grid.dart
git commit -m "fix: show auto candidates and pencil notes as a union"
```

---

### Task 2: MarkupMode and cell-color only in cellColor mode

**Files:**
- Create: `test/markup_mode_test.dart`
- Modify: `lib/models/board_markup.dart`
- Modify: `lib/models/game_state.dart`

**Interfaces:**
- Consumes: `BoardMarkup.cellColors`, `selectCell`
- Produces:
  - `enum MarkupMode { off, cellColor, candidateColor, strong, weak, autoConjugate }`
  - `class MarkupPalette { static const colors = [Color(0xFFC9A227), Color(0xFF2E7D32), Color(0xFF1565C0), Color(0xFFC62828)]; }`
  - `void GameState.setMarkupMode(MarkupMode mode)` — clears `arrowAnchor`; sets `markupEnabled` true iff `mode != off`
  - `void GameState.setMarkupColor(Color color)`
  - `void GameState.onCellTap(int row, int col)` — select always; paint cell iff `markupMode == cellColor`
  - Remove call path that paints on every tap when `_markupEnabled` is true

- [ ] **Step 1: Write the failing test**

```dart
test('未进格色模式时选格不上色', () {
  final g = GameState()..loadExampleGame('easy');
  g.setMarkupMode(MarkupMode.off);
  g.onCellTap(0, 0);
  expect(g.userMarkup.cellColors, isEmpty);
});

test('格色模式点格写入当前色，同色再点取消', () {
  final g = GameState()..loadExampleGame('easy');
  g.setMarkupColor(MarkupPalette.colors.first);
  g.setMarkupMode(MarkupMode.cellColor);
  g.onCellTap(1, 1);
  expect(g.userMarkup.cellColors[BoardMarkup.cellKey(1, 1)],
      MarkupPalette.colors.first);
  g.onCellTap(1, 1);
  expect(g.userMarkup.cellColors.containsKey(BoardMarkup.cellKey(1, 1)), isFalse);
});
```

`loadExampleGame` must leave a playable board. If it is empty in this repo, use `loadCustomGame` with the 81-char classic string from the spec tests.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/markup_mode_test.dart`

Expected: FAIL (`MarkupMode` / `onCellTap` missing, or `paintSelectedCell` still runs from the old enabled flag).

- [ ] **Step 3: Write minimal implementation**

In `board_markup.dart` add `MarkupMode` and `MarkupPalette`.

In `GameState`:
- Field `MarkupMode markupMode = MarkupMode.off`.
- `toggleMarkupEnabled()` becomes: if currently off, switch to `cellColor`; if any mode on, switch to `off` and clear `arrowAnchor`. Prefer exposing `setMarkupMode` for the toolbar.
- `onCellTap`: `selectCell` without the deselect-toggle if you need stable selection for coloring; keep existing toggle when `markupMode == off`. When `cellColor`, after select, if `userMarkup.cellColors[key] == markupColor` remove it, else set it.
- `game_screen.dart` `onCellTap` must call `gameState.onCellTap` instead of `selectCell` + `paintSelectedCell`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/markup_mode_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/markup_mode_test.dart lib/models/board_markup.dart lib/models/game_state.dart lib/screens/game_screen.dart
git commit -m "feat: exclusive cell-color markup mode"
```

---

### Task 3: Same-digit weak highlight only when markup is off

**Files:**
- Create: `test/same_digit_highlight_test.dart`
- Modify: `lib/models/game_state.dart` or a small helper on `SudokuGrid` / `GameState`
- Modify: `lib/widgets/sudoku_grid.dart`

**Interfaces:**
- Consumes: `markupMode`, selected cell value
- Produces: `Set<int> GameState.sameDigitHighlightCells()` cell keys; `Set<CandidateRef> GameState.sameDigitHighlightCandidates()`
  - Empty if `markupMode != off` or no selection or selected cell is 0
  - Otherwise all filled cells with that value, and all visible candidates equal to that value (including other cells)

- [ ] **Step 1: Write the failing test**

Build a board with a `5` at (0,0) as given, another `5` at (1,1) given, and an empty (2,2) whose `visibleCandidates` contains 5.

```dart
test('标记关闭时选中成数 5 弱高亮其它 5 和候选 5', () {
  // ...
  g.selectCell(0, 0);
  expect(g.sameDigitHighlightCells(), contains(BoardMarkup.cellKey(1, 1)));
  expect(g.sameDigitHighlightCandidates(), contains(CandidateRef(2, 2, 5)));
});

test('标记开启后同数字高亮为空', () {
  g.setMarkupMode(MarkupMode.cellColor);
  g.selectCell(0, 0);
  expect(g.sameDigitHighlightCells(), isEmpty);
  expect(g.sameDigitHighlightCandidates(), isEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/same_digit_highlight_test.dart`

Expected: FAIL, methods missing.

- [ ] **Step 3: Implement**

Compute the two sets in `GameState`. Pass them into `SudokuGrid` as `sameDigitCells` / `sameDigitCandidates`.

Render: filled matching cells use a light gray wash (`scheme.surfaceContainerHighest`), not tertiary/primary. Matching candidates use a light gray circle or slightly darker glyph — weaker than selected-cell primary container. Do not write `userMarkup`.

Remove or gate the existing `samePeerValue` tertiary tint so it only runs when `markupMode == off` (same helper).

- [ ] **Step 4: Run tests**

Run: `flutter test test/same_digit_highlight_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/same_digit_highlight_test.dart lib/models/game_state.dart lib/widgets/sudoku_grid.dart lib/screens/game_screen.dart
git commit -m "feat: weak same-digit highlight when markup is off"
```

---

### Task 4: Candidate color via number pad and circle background

**Files:**
- Modify: `test/markup_mode_test.dart` (add cases)
- Modify: `lib/models/game_state.dart` — `onNumberPad(int number)`
- Modify: `lib/widgets/sudoku_grid.dart` — circle behind candidate
- Modify: `lib/screens/game_screen.dart` — pad enablement and `onNumberPad`

**Interfaces:**
- Consumes: `MarkupMode.candidateColor`, `visibleCandidates`, `markupColor`
- Produces: `void GameState.onNumberPad(int number)`
  - `off` + not candidateMode: existing `placeNumber`
  - `off` + candidateMode: existing pencil toggle
  - `candidateColor`: if selected empty cell’s `visibleCandidates` contains `number`, toggle `userMarkup.candidateColors[CandidateRef]` between `markupColor` and unset; do not change `userCandidates`
  - `strong`/`weak`: treat as choosing the candidate at the selected cell (see Task 5); if cell has no that candidate, no-op
  - `autoConjugate`: call `paintConjugates(number)` (Task 5)
  - `cellColor`: number pad ignored (or still fill if you keep fill — spec says candidate color uses the pad; cell color uses cell taps). Ignore pad in `cellColor`.

Pad button enabled when:
- `off`: current rules (selected, not given)
- `candidateColor` / `strong` / `weak`: selected empty cell and `visibleCandidates.contains(n)`
- `autoConjugate`: always enable 1–9 (digit chosen globally)
- `cellColor`: all disabled

- [ ] **Step 1: Write the failing test**

```dart
test('候选色：选色选格点数字键给该候选上色，不改笔记集合', () {
  final g = GameState()..loadCustomGame(classic);
  g.setMarkupColor(MarkupPalette.colors[1]);
  g.setMarkupMode(MarkupMode.candidateColor);
  // choose an empty cell that visibly contains 8
  g.selectCell(r, c);
  g.onNumberPad(8);
  expect(g.userMarkup.candidateColors[CandidateRef(r, c, 8)],
      MarkupPalette.colors[1]);
  expect(g.board!.getUserCandidates(r, c).contains(8), isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/markup_mode_test.dart`

Expected: FAIL (`onNumberPad` missing or still `placeNumber`).

- [ ] **Step 3: Implement pad routing and circle UI**

In `_buildCandidates`, if `cColor != null`, wrap the digit in a `Container` with `shape: BoxShape.circle`, `color: cColor`, contrasting glyph. Do not only change `TextStyle.color`.

Game screen number pad calls `onNumberPad`. Toolbar: mode chips + 4 color dots. Status line under chips when `candidateColor`: `选格后点数字上色`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/markup_mode_test.dart test/visible_candidates_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/markup_mode_test.dart lib/models/game_state.dart lib/widgets/sudoku_grid.dart lib/screens/game_screen.dart
git commit -m "feat: paint candidate circles from the number pad"
```

---

### Task 5: Chain anchors and auto conjugate on rows, columns, and boxes

**Files:**
- Create: `test/auto_conjugate_test.dart`
- Modify: `lib/models/game_state.dart` — `paintConjugates`, `onCandidateMarkupTap`, `onNumberPad`
- Modify: `lib/widgets/sudoku_grid.dart` — draw filled circle on `arrowAnchor`

**Interfaces:**
- Consumes: `MarkupMode.strong|weak|autoConjugate`, `BoardMarkup.addArrow`, `isLegalConjugate`
- Produces:
  - `paintConjugates(int digit)` scans 9 rows, 9 cols, 9 boxes; for each unit with exactly two cells containing `digit` in `visibleCandidates` (or `getCandidates` — use `getCandidates` so notes-only extras do not invent conjugates), add `ArrowKind.conjugate` if not already present. Returns `int` added count.
  - `bool GameState.lastConjugateEmpty` or return count so UI can snackbar `该数字没有共轭对` when 0.
  - Switching mode clears `arrowAnchor`.

- [ ] **Step 1: Write the failing tests**

Construct a board (via `candidates` mutation on an empty-ish custom grid) where digit `7` has:
- exactly two in row 0
- exactly two in column 1
- exactly two in box 8 (bottom-right)
and more than two in some other unit (must not draw).

```dart
test('自动共轭画出行、列、宫，且不只扫行', () {
  final g = GameState()..loadCustomGame('0' * 81);
  // set candidates as needed...
  g.setMarkupMode(MarkupMode.autoConjugate);
  g.onNumberPad(7);
  expect(g.userMarkup.arrows.where((a) => a.kind == ArrowKind.conjugate).length, 3);
});

test('强链第一点留下锚点，第二点画线并清空锚点', () {
  g.setMarkupMode(MarkupMode.strong);
  g.onCandidateMarkupTap(0, 1, 7);
  expect(g.arrowAnchor, CandidateRef(0, 1, 7));
  g.onCandidateMarkupTap(0, 7, 7);
  expect(g.arrowAnchor, isNull);
  expect(g.userMarkup.arrows, isNotEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auto_conjugate_test.dart`

Expected: FAIL (current `paintConjugates` only loops rows, so length is 1 not 3).

- [ ] **Step 3: Implement**

Rewrite `paintConjugates` with a local `void addPair(List<CandidateRef> hits)` when `hits.length == 2`.

`onNumberPad` in strong/weak: if selected cell has that candidate, call `onCandidateMarkupTap(row, col, number)`.

Grid: if `arrowAnchor == CandidateRef(row,col,num)`, draw a black filled circle behind that candidate (in addition to any color).

Toolbar: chips 格色 / 候选色 / 强链 / 弱链 / 自动共轭 / 关闭. Remove 共轭 and 画共轭. When `arrowAnchor != null`, show `已选起点，再点终点`.

If `paintConjugates` adds 0, `GameState.conjugateNotice = '该数字没有共轭对'` and `notifyListeners`; game screen shows a `SnackBar` and clears the notice.

- [ ] **Step 4: Run tests**

Run: `flutter test test/auto_conjugate_test.dart test/markup_mode_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/auto_conjugate_test.dart lib/models/game_state.dart lib/widgets/sudoku_grid.dart lib/screens/game_screen.dart
git commit -m "feat: chain anchors and auto conjugate on rows columns boxes"
```

---

### Task 6: Hint panel under the board

**Files:**
- Create: `lib/widgets/hint_panel.dart`
- Create: `test/hint_panel_test.dart`
- Modify: `lib/models/game_state.dart` — `HintSession? hintSession` with fields `{SudokuHint hint, bool fromDeepSearch, HintPhase phase}` where `HintPhase { none, offerDeep, failed, ready }`
- Modify: `lib/screens/game_screen.dart` — stop `AlertDialog` for hint / deep / fail

**Interfaces:**
- Consumes: `getHint`, `applyHint`, `clearHintMarkup`
- Produces: `HintPanel` widget: title, explanation, 取消, 应用本步/应用删除. Game screen inserts it between `SudokuGrid` and control buttons. `_showHint` sets session instead of `showDialog`. If `hintSession.phase != none`, ignore another hint tap.

- [ ] **Step 1: Write the failing widget test**

Pump a `MaterialApp` with `ChangeNotifierProvider` + a stubbed `GameState` that already has a board and a fake ready hint, **or** pump `HintPanel` directly:

```dart
testWidgets('HintPanel 显示技巧名和应用按钮', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: HintPanel(
        title: '显性数对（行）',
        body: '可删除候选',
        actionLabel: '应用删除',
        onCancel: () {},
        onApply: () {},
      ),
    ),
  ));
  expect(find.text('显性数对（行）'), findsOneWidget);
  expect(find.text('应用删除'), findsOneWidget);
});
```

Add a `game_screen` test only if you can load a board without generating: `loadCustomGame` then `getHint` may return a naked single. Then `find.byType(AlertDialog)` for hint title should be `findsNothing` and `find.byType(HintPanel)` `findsOneWidget`. Skip the full screen test if generation is slow; the panel widget + `GameState.hintSession` unit test is enough:

```dart
test('getHint 写入 hintSession 而不依赖对话框', () {
  final g = GameState()..loadCustomGame(classic);
  final h = g.getHint();
  expect(h, isNotNull);
  expect(g.hintSession, isNotNull);
});
```

Extend `getHint` to set `hintSession` with `HintPhase.ready`. If null, set `offerDeep`. `requestDeepSearch()` sets ready or failed.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/hint_panel_test.dart`

Expected: FAIL (`HintPanel` / `hintSession` missing).

- [ ] **Step 3: Implement**

Create `HintPanel`. Wire game screen. Keep dialogs for validate / reset / victory / autofill.

- [ ] **Step 4: Run tests**

Run: `flutter test test/hint_panel_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/hint_panel.dart test/hint_panel_test.dart lib/models/game_state.dart lib/screens/game_screen.dart
git commit -m "feat: show hints in a panel under the board"
```

---

### Task 7: Black-and-white chrome

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/screens/game_screen.dart` control buttons if they still use colorful active fills — active mode chips use black fill / white text, not green/orange/purple
- Modify: `test/widget_test.dart` if it still expects the app to load

**Interfaces:**
- Consumes: `AppTheme._build`
- Produces: `AppTheme.seed = Color(0xFF1A1A1A)` (or `Color(0xFF111111)`). Markup palette unchanged.

- [ ] **Step 1: Write a smoke test**

```dart
testWidgets('应用使用近黑种子色', (tester) async {
  await tester.pumpWidget(const SudokuApp());
  final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
  expect(theme.colorScheme.brightness, Brightness.light);
  expect(theme.colorScheme.primary.computeLuminance() < 0.2, isTrue);
});
```

Add to `test/widget_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL while seed is indigo (`0xFF4F46E5` is not that dark).

- [ ] **Step 3: Change seed; keep markup colors**

Active control buttons: black/white, not `scheme.primary` saturated purple. Number pad in note mode: gray filled, not tertiary container color.

- [ ] **Step 4: Run tests**

Run: `flutter analyze lib test && flutter test`

Expected: analyze clean, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart lib/screens/game_screen.dart test/widget_test.dart
git commit -m "style: black-and-white chrome; keep markup palette"
```

---

## Spec coverage

| Spec item | Task |
| --- | --- |
| Candidate union | 1 |
| Exclusive modes, cell color not on mere select | 2 |
| Same-digit highlight off when markup on | 3 |
| Candidate circles via pad | 4 |
| Chain start glyph | 5 |
| Auto conjugate row/col/box; remove 画共轭 / 共轭 chip | 5 |
| Hint under board, no covering dialog | 6 |
| Black/white chrome | 7 |
| Deep search on same card | 6 (`HintPhase.offerDeep` / `failed`) |
