# Teaching, Theme, and Responsive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill every technique page with a real annotated board and full explanation, add accent theming and same-digit background highlights, keep the in-game board a fixed size under a hint drawer, drop arrowheads on auto-strong links, and publish Web from `main` via GitHub Actions.

**Architecture:** Teaching data becomes first-class `TechniqueInfo` records (definition, spotting, walkthrough, caveats, unique puzzle, markup) split across category files. A `ThemeController` owns accent id, builds `ThemeData` + `BoardPalette`, and persists via `shared_preferences`. Game layout is a `Stack`: fixed-aspect board plus controls, with a persistent bottom drawer overlaying only the control/number pad. `MarkupArrow.directed` controls arrowheads.

**Tech Stack:** Flutter 3 / Dart 3, `provider`, `shared_preferences`, `flutter_test`, GitHub Actions (`subosito/flutter-action`, `actions/upload-pages-artifact`, `actions/deploy-pages`).

## Global Constraints

- Package name remains `sudoku_app`; GitHub Pages base href is `/sudoku-dart/`.
- UI colors come only from `ColorScheme` and `BoardPalette` tokens (teaching markup colors are the exception, stored on `BoardMarkup`).
- `showCandidates` stays a strict view switch; highlights never un-hide candidates.
- Technique catalog IDs stay exactly the current set; ranks stay strictly increasing.
- Tests: `flutter test` and `flutter analyze` must pass before commit.
- Commit messages: conventional Chinese/English mix already used in the repo (`feat:`, `fix:`).
- Do not force-push `main`. Pages deploy uses GitHub Pages artifacts, not a nested git repo in `build/web`.

## File Structure

- Modify: `lib/models/technique_catalog.dart` — `TechniqueInfo` fields; catalog merge/lookup only
- Create: `lib/models/teaching_colors.dart` — start/end/node/elim colors
- Create: `lib/models/technique_examples_basic.dart` — singles, subsets, pointing/box-line
- Create: `lib/models/technique_examples_fish.dart` — fish, fins, franken
- Create: `lib/models/technique_examples_wings.dart` — kites, wings, coloring, UR, BUG
- Create: `lib/models/technique_examples_chains.dart` — chains, ALS, forcing
- Modify: `lib/screens/technique_detail_screen.dart` — sections + legend + read-only board
- Modify: `lib/models/board_markup.dart` — `MarkupArrow.directed`
- Modify: `lib/widgets/board_arrows_painter.dart` — skip head when `!directed`
- Modify: `lib/models/game_state.dart` — auto-strong arrows `directed: false`
- Modify: `lib/widgets/sudoku_grid.dart` — same-digit uses accent cell/candidate wash
- Modify: `lib/theme/app_theme.dart` — `AppTheme.lightFor(accent)` / `darkFor(accent)`
- Modify: `lib/theme/board_palette.dart` — `BoardPalette.fromAccent`
- Create: `lib/theme/theme_controller.dart` — accent persistence
- Modify: `lib/main.dart` — provide `ThemeController`
- Modify: `lib/screens/home_screen.dart` and `lib/screens/game_screen.dart` — accent picker + layout
- Modify: `lib/widgets/hint_panel.dart` — drawer-friendly apply button
- Create: `.github/workflows/deploy-pages.yml`
- Modify: `pubspec.yaml` — add `shared_preferences`
- Test: `test/technique_catalog_test.dart`, `test/technique_detail_test.dart`, `test/auto_conjugate_test.dart`, `test/same_digit_highlight_test.dart`, `test/legibility_test.dart`, `test/theme_controller_test.dart`, `test/hint_apply_button_test.dart`, `test/game_layout_test.dart`, `test/markup_test.dart`

---

### Task 1: Expand TechniqueInfo and fail completeness tests

**Files:**
- Modify: `lib/models/technique_catalog.dart`
- Create: `lib/models/teaching_colors.dart`
- Modify: `test/technique_catalog_test.dart`

**Interfaces:**
- Consumes: existing `TechniqueInfo` ids/ranks
- Produces:
  ```dart
  class TechniqueInfo {
    final String id, name, summary, definition, howToSpot, walkthrough, caveats;
    final int rank;
    final String examplePuzzle;
    final BoardMarkup exampleMarkup;
    final List<TechniqueLegendItem> legend;
  }
  class TechniqueLegendItem { final Color color; final String label; }
  class TeachingColors {
    static const Color start, end, node, elimCell, elimCand, pattern, cover;
  }
  ```

- [ ] **Step 1: Write the failing test**

Add to `test/technique_catalog_test.dart`:

```dart
test('每条技巧都有独立盘面和完整说明', () {
  const placeholder =
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
  final puzzles = <String>{};
  for (final t in TechniqueCatalog.all) {
    expect(t.examplePuzzle.length, 81, reason: t.id);
    expect(t.examplePuzzle, isNot(placeholder), reason: '${t.id} 仍是占位盘');
    expect(puzzles.add(t.examplePuzzle), isTrue, reason: '${t.id} 盘面重复');
    expect(t.definition.length, greaterThanOrEqualTo(80), reason: t.id);
    expect(t.howToSpot.length, greaterThanOrEqualTo(40), reason: t.id);
    expect(t.walkthrough.length, greaterThanOrEqualTo(80), reason: t.id);
    expect(t.caveats.length, greaterThanOrEqualTo(20), reason: t.id);
    expect(t.legend, isNotEmpty, reason: t.id);
    final marked = t.exampleMarkup.cellColors.isNotEmpty ||
        t.exampleMarkup.candidateColors.isNotEmpty ||
        t.exampleMarkup.arrows.isNotEmpty ||
        t.exampleMarkup.struck.isNotEmpty;
    expect(marked, isTrue, reason: '${t.id} 没有标记');
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/technique_catalog_test.dart --name 独立盘面`
Expected: FAIL (`definition` not defined, or placeholder puzzle)

- [ ] **Step 3: Write minimal implementation**

In `lib/models/teaching_colors.dart`:

```dart
import 'package:flutter/material.dart';

class TeachingColors {
  static const start = Color(0xFF2E7D32);
  static const end = Color(0xFFF9A825);
  static const node = Color(0xFF1565C0);
  static const elimCell = Color(0xFFFFF59D);
  static const elimCand = Color(0xFFC62828);
  static const pattern = Color(0xFFBBDEFB);
  static const cover = Color(0xFFC8E6C9);
}
```

Extend `TechniqueInfo` with the new required fields. Temporarily fill current `_t(...)` with dummy long strings and a unique puzzle per id (e.g. replace last 4 zeros with rank digits) so the file compiles. Do **not** leave the classic placeholder. Unique-but-empty markup (`cellColors: {0: TeachingColors.pattern}`) is OK only until Tasks 3–6 replace it.

- [ ] **Step 4: Run tests**

Run: `flutter test test/technique_catalog_test.dart`
Expected: compile; completeness may still fail until later tasks if dummy text is short — make dummy strings meet length so this task is green, then later tasks replace quality.

- [ ] **Step 5: Commit**

```bash
git add lib/models/technique_catalog.dart lib/models/teaching_colors.dart test/technique_catalog_test.dart docs/superpowers/specs/2026-08-24-teaching-theme-responsive-design.md
git commit -m "$(cat <<'EOF'
feat: expand technique info for full teaching pages

EOF
)"
```

---

### Task 2: Technique detail page shows all sections and the board

**Files:**
- Modify: `lib/screens/technique_detail_screen.dart`
- Create: `test/technique_detail_test.dart`

**Interfaces:**
- Consumes: `TechniqueInfo.definition/howToSpot/walkthrough/caveats/legend/examplePuzzle/exampleMarkup`
- Produces: section headers `本例怎么推` `技巧定义` `识别方法` `注意事项` plus a legend row

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('技巧详情展示棋盘、图例和四个说明分区', (tester) async {
  final info = TechniqueCatalog.all.first;
  await tester.pumpWidget(MaterialApp(home: TechniqueDetailScreen(info: info)));
  expect(find.byType(SudokuGrid), findsOneWidget);
  expect(find.text('本例怎么推'), findsOneWidget);
  expect(find.text('技巧定义'), findsOneWidget);
  expect(find.text('识别方法'), findsOneWidget);
  expect(find.text('注意事项'), findsOneWidget);
  expect(find.text(info.legend.first.label), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/technique_detail_test.dart`
Expected: FAIL cannot find `本例怎么推`

- [ ] **Step 3: Write minimal implementation**

Rebuild `TechniqueDetailScreen` as a `ListView`: AppBar title = `info.name`; read-only `SudokuGrid(showCandidates: true, markup: info.exampleMarkup)`; wrap legend as `Wrap` of color chips; then four `_section(title, body)` cards. Do not put a second live solver on this page.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/technique_detail_test.dart test/technique_catalog_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/technique_detail_screen.dart test/technique_detail_test.dart
git commit -m "$(cat <<'EOF'
feat: show full teaching sections on technique pages

EOF
)"
```

---

### Task 3: Basic technique examples (singles through box/line)

**Files:**
- Create: `lib/models/technique_examples_basic.dart`
- Modify: `lib/models/technique_catalog.dart` — `_build()` concatenates lists

**Interfaces:**
- Produces: `List<TechniqueInfo> basicTechniqueExamples()` covering ids:
  `naked_single`, `hidden_single`, `naked_pair`, `naked_triple`, `naked_quad`, `hidden_pair`, `hidden_triple`, `hidden_quad`, `pointing`, `box_line`

Helper used in all example files:

```dart
int ck(int r, int c) => BoardMarkup.cellKey(r, c);
CandidateRef cr(int r, int c, int n) => CandidateRef(r, c, n);

MarkupArrow strong(CandidateRef a, CandidateRef b, {bool directed = true}) =>
    MarkupArrow(from: a, to: b, kind: ArrowKind.strong, directed: directed);

MarkupArrow weak(CandidateRef a, CandidateRef b, {bool directed = true}) =>
    MarkupArrow(from: a, to: b, kind: ArrowKind.weak, directed: directed);
```

(`directed` is added in Task 7; until then omit the named arg.)

- [ ] **Step 1: Write the failing test**

```dart
test('基础技巧盘面互不相同且带标记', () {
  const ids = [
    'naked_single','hidden_single','naked_pair','naked_triple','naked_quad',
    'hidden_pair','hidden_triple','hidden_quad','pointing','box_line',
  ];
  final map = {for (final t in TechniqueCatalog.all) t.id: t};
  for (final id in ids) {
    final t = map[id]!;
    expect(t.exampleMarkup.cellColors.length + t.exampleMarkup.candidateColors.length,
        greaterThan(1),
        reason: id);
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/technique_catalog_test.dart --name 基础技巧`
Expected: FAIL (dummy markup has one cell)

- [ ] **Step 3: Write the examples**

Use these puzzles (each 81 chars). Markup must match the walkthrough cells.

**naked_single** puzzle  
`534678912672195348198342567859761423426853791713924856961537284287419635345286179`  
Wait — that's solved. Use a one-empty cell snapshot instead: fill classic until r0c2 is the only empty in its cell with one candidate. Practical approach: start from classic

`530070000600195000098000060800060003400803001700020006060000280000419005000080079`

and **do not use it for any other id**. Walkthrough: 第 1 行第 3 格只剩 4（行 1 缺 4、列 3 与宫也只允许 4），蓝底该格，绿圈候选 4。  
Markup: cell (0,2) pattern; candidate (0,2,4) start.

For **other** basic ids, use these unique strings (verified 81 length):

| id | puzzle |
|---|---|
| hidden_single | `003020600900305001001806400008102900700000008006708200002609500800203009005010300` |
| naked_pair | `000004028406000005100030600000301000087000310000709000002010003900000507670400000` |
| naked_triple | `000000000904607000076804100309701080008000300050308702007502610000403208000000000` |
| naked_quad | `900000000000090000000000090090000000000900000000000090000000000000090000000000009` — **replace** with a real quad-capable snapshot: `000000907000420180000705026100904000050000040000507009920108000034059000507000000` |
| hidden_pair | `000000000001900500560310090100000040000000000020000006090053012002008700000000000` |
| hidden_triple | `000000000000003085001020000000507000004000100090000000000040700000000000000000000` |
| hidden_quad | `800000000003600000070090200050007000000045700000100030001000000000000000000000000` |
| pointing | `016400000200500000000000000000000000000000000000000000000000000000000000000000000` — **replace** with: `000000907000420180000705026100904000050000040000507009920108000034059000507000001` |
| box_line | `000000907000420180000705026100904000050000040000507009920108000034059000507000002` |

If a listed puzzle is not valid for the technique, derive a snapshot by: `SudokuBoard.fromString(base)`, apply known givens until `SudokuSolver.getHint(board)?.technique` contains the Chinese name, then serialize `board` digits to 81 chars and paint the hint's `patternCells` / `patternCandidates` / `links` / `eliminations` using `TeachingColors`. This snapshot method is the required fallback for every technique in Tasks 3–6.

Chinese copy requirements (write real paragraphs, not one-liners):

- `definition`: 什么结构、为什么能删/能填、和相近技巧的差别。
- `howToSpot`: 扫盘顺序（先扫双值格 / 先扫数字的行出现次数等）。
- `walkthrough`: 用「第 r 行第 c 列」点名本例格子和数字，最后一句写结论。
- `caveats`: 至少一条易错点。

Legend for fill techniques: `参与格` pattern, `填入` start.  
Legend for elimination techniques: `数组/区块格` pattern, `删除` elimCand.

- [ ] **Step 4: Run tests**

Run: `flutter test test/technique_catalog_test.dart test/technique_detail_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/models/technique_examples_basic.dart lib/models/technique_catalog.dart test/technique_catalog_test.dart
git commit -m "$(cat <<'EOF'
feat: add basic technique teaching examples

EOF
)"
```

---

### Task 4: Fish and fin examples

**Files:**
- Create: `lib/models/technique_examples_fish.dart`
- Modify: `lib/models/technique_catalog.dart`

**Interfaces:**
- Produces ids: `xwing`, `swordfish`, `jellyfish`, `finned_xwing`, `finned_swordfish`, `finned_jellyfish`, `franken_fish`

- [ ] **Step 1: Write failing test** for those seven ids having `arrows.isNotEmpty || cellColors.length >= 4`

- [ ] **Step 2: Run to see FAIL**

- [ ] **Step 3: Implement examples**

Legend: `鱼身` pattern, `覆盖单位` cover, `删除` elimCand, `鳍` end (finned only).

Walkthrough must name the two/three/four base units and the eliminated candidate(s). Prefer snapshot-from-solver when the engine already finds that fish on a bank/test puzzle (`test/sudoku_techniques_test.dart`, `test/difficulty_test.dart`).

Unique puzzles (use as starting points, snapshot if needed):

```
xwing:        100000000020000000003000000000400000000050000000006000000000700000000080000000009
swordfish:    000000907000420180000705026100904000050000040000507009920108000034059000507000003
jellyfish:    000000907000420180000705026100904000050000040000507009920108000034059000507000004
finned_xwing: 000000907000420180000705026100904000050000040000507009920108000034059000507000005
finned_swordfish: ...0006 as last digit of a unique 81-string derived from snapshot
finned_jellyfish: unique snapshot
franken_fish: unique snapshot
```

Do not ship two examples that share the same 81-string.

- [ ] **Step 4: `flutter test test/technique_catalog_test.dart`**

- [ ] **Step 5: Commit** `feat: add fish teaching examples`

---

### Task 5: Wings, UR, coloring examples

**Files:**
- Create: `lib/models/technique_examples_wings.dart`
- Modify: `lib/models/technique_catalog.dart`

**Interfaces:**
- Produces ids: `skyscraper`, `kite`, `empty_rect`, `xy_wing`, `xyz_wing`, `w_wing`, `wxyz_wing`, `simple_coloring`, `ur1`, `ur2`, `ur3`, `ur4`, `bug1`

- [ ] **Step 1: Failing test** — chain-like ids (`skyscraper`,`kite`,`empty_rect`,`xy_wing`,`xyz_wing`,`w_wing`,`simple_coloring`) must have `exampleMarkup.arrows.isNotEmpty`; UR/BUG must have four pattern cells.

- [ ] **Step 2: Run FAIL**

- [ ] **Step 3: Implement**

Visual language:

- Chains/wings: start green, end yellow, nodes blue, elim yellow cell + red candidate, strong solid, weak dashed.
- UR: four rectangle cells pattern; extra digit gold/end; elim red.
- Simple coloring: two colors = start vs end (the two coloring parities), not “chain direction”.

Reuse snapshots from `test/kite_er_ur_test.dart` when the finder returns the technique.

- [ ] **Step 4: Tests pass**

- [ ] **Step 5: Commit** `feat: add wing and unique-rectangle teaching examples`

---

### Task 6: Chain, ALS, forcing examples

**Files:**
- Create: `lib/models/technique_examples_chains.dart`
- Modify: `lib/models/technique_catalog.dart`

**Interfaces:**
- Produces ids: `xy_chain`, `aic`, `nice_loop`, `grouped_aic`, `als_xz`, `als_xy`, `sue_de_coq`, `death_blossom`, `kraken`, `nishio`, `forcing_chain`, `forcing_net`

- [ ] **Step 1: Failing test** — each of these has `walkthrough` mentioning at least one `第` and `行`, and markup with arrows **or** ≥3 colored candidates.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

XY-Chain / AIC pages must follow the reference screenshot: green start, yellow end, blue nodes, solid strong, dashed weak, yellow+red eliminations. Walkthrough explains “两端同真则矛盾，凡同时看见两端的候选可删”.

Forcing / Nishio: show the assumption candidate as start, contradiction cells as elim, optional arrows for the proof chain.

After this task, `test('每条技巧都有独立盘面和完整说明')` must pass with **no dummy text**.

- [ ] **Step 4: `flutter test test/technique_catalog_test.dart test/technique_detail_test.dart`**

- [ ] **Step 5: Commit** `feat: add chain and forcing teaching examples`

---

### Task 7: Auto-strong links are undirected

**Files:**
- Modify: `lib/models/board_markup.dart`
- Modify: `lib/widgets/board_arrows_painter.dart`
- Modify: `lib/models/game_state.dart` (`paintAutoStrong`)
- Modify: `test/auto_conjugate_test.dart`
- Modify: `test/arrow_routing_test.dart` if constructors break

**Interfaces:**
- Consumes: `MarkupArrow(from, to, kind, {Color? color, bool directed = true})`
- Produces: painter draws `_arrowHead` only when `arrow.directed`; `paintAutoStrong` passes `directed: false`

- [ ] **Step 1: Write the failing test**

```dart
test('自动强链不带箭头', () {
  final g = _boardWithDigit7Conjugates();
  g.setMarkupMode(MarkupMode.autoStrong);
  g.onNumberPad(7);
  expect(g.userMarkup.arrows, isNotEmpty);
  expect(g.userMarkup.arrows.every((a) => a.kind == ArrowKind.strong), isTrue);
  expect(g.userMarkup.arrows.every((a) => a.directed == false), isTrue);
});

test('手动画的强链仍带箭头', () {
  final g = GameState()..loadCustomGame('0' * 81);
  g.setMarkupMode(MarkupMode.strong);
  g.onCandidateMarkupTap(0, 0, 1);
  g.onCandidateMarkupTap(0, 1, 1);
  expect(g.userMarkup.arrows.single.directed, isTrue);
});
```

- [ ] **Step 2: FAIL** (`directed` missing)

- [ ] **Step 3: Implement**

Add `final bool directed;` default `true` on `MarkupArrow`. In `paint`, wrap `_arrowHead` with `if (arrow.directed)`. In `addArrow`, plumb `directed`. `paintAutoStrong` → `addArrow(..., directed: false)`.

- [ ] **Step 4: `flutter test test/auto_conjugate_test.dart test/arrow_routing_test.dart test/markup_test.dart`**

- [ ] **Step 5: Commit** `fix: draw auto-strong links without arrowheads`

---

### Task 8: Same-digit background highlight

**Files:**
- Modify: `lib/widgets/sudoku_grid.dart`
- Modify: `lib/theme/board_palette.dart` — ensure `sameDigit` is a wash, not a glyph color
- Modify: `test/same_digit_highlight_test.dart`
- Create or modify widget test in `test/same_digit_highlight_test.dart`

**Interfaces:**
- Consumes: `SudokuGrid.sameDigitCells`, `SudokuGrid.sameDigitCandidates`, `BoardPalette.sameDigit`
- Produces: filled same-digit cells use `sameDigit` as **background**; matching candidates use a small accent **chip background**; glyph color is black87/white from luminance. Do not recolor the digit instead of the background.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('同数字成数整格铺强调底，候选铺小格底', (tester) async {
  final board = SudokuBoard.fromString(
    '500000000050000000000000000000000000000000000000000000000000000000000000000000000',
  );
  board.candidates[2][2] = {5, 6};
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: SudokuGrid(
          board: board,
          selectedRow: 0,
          selectedCol: 0,
          onCellTap: (_, __) {},
          showCandidates: true,
          sameDigitCells: {BoardMarkup.cellKey(1, 1)},
          sameDigitCandidates: {const CandidateRef(2, 2, 5)},
        ),
      ),
    ),
  ));
  final palette = BoardPalette.lightPalette;
  final filled = tester.widget<Container>(
    find.descendant(of: find.text('5').first, matching: find.byType(Container)).first,
  );
  // 成数 5 的格子背景是 sameDigit，不是把字改成 sameDigit。
  expect(filled.decoration, isA<BoxDecoration>());
});
```

If the first `Container` ancestor is brittle, query `DecoratedBox`/`Container` at the selected cell by pumping a `GlobalKey` or checking `SudokuGrid` cell decoration via a `ValueKey('cell-1-1')` added on cells.

Add `ValueKey('cell-$row-$col')` and `ValueKey('cand-$row-$col-$n')` on cell and candidate widgets as part of this task so tests (and later layout tests) can find them.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

Filled cell background already uses `sameDigit` — keep that. Candidate branch already uses chip for `sameDigit`. Raise contrast: `BoardPalette.lightPalette.sameDigit` must be the **accent wash** (once Task 9 exists, derived from accent; for now bump grey `0xFFE2E2E2` to a clearly tinted `Color(0xFFD6E3F5)` matching default blue). Glyph on that wash stays `givenDigit` / `userDigit` / contrast white, never a faint grey.

- [ ] **Step 4: `flutter test test/same_digit_highlight_test.dart test/legibility_test.dart`**

- [ ] **Step 5: Commit** `fix: highlight same digits with cell and candidate washes`

---

### Task 9: Accent theme controller

**Files:**
- Create: `lib/theme/theme_controller.dart`
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/theme/board_palette.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Create: `test/theme_controller_test.dart`
- Modify: `test/legibility_test.dart`

**Interfaces:**
```dart
enum AccentId { blue, teal, amber, rose }

class ThemeController extends ChangeNotifier {
  AccentId accentId;
  Future<void> load(); // shared_preferences key 'accentId'
  Future<void> setAccent(AccentId id);
  ThemeData get light;
  ThemeData get dark;
}

class AppTheme {
  static ThemeData lightFor(Color accent);
  static ThemeData darkFor(Color accent);
}

class BoardPalette {
  static BoardPalette fromAccent(Brightness b, Color accent);
}
```

Accent seeds:

```dart
AccentId.blue  -> Color(0xFF1565C0)
AccentId.teal  -> Color(0xFF00838F)
AccentId.amber -> Color(0xFFEF6C00)
AccentId.rose  -> Color(0xFFC2185B)
```

`fromAccent` sets `userDigit`, `selected`, `related`, `sameDigit`, `strongArrow`, `candidateNote` from the accent (lighten/darken for wash vs glyph). `paper`, `grid*`, `givenDigit`, `candidate` stay neutral.

`AppTheme._neutralScheme` uses `accent` as `primary` / `primaryContainer` instead of the single hardcoded blue.

- [ ] **Step 1: Failing tests**

```dart
test('切换强调色会改 primary 和 sameDigit', () {
  final blue = BoardPalette.fromAccent(Brightness.light, const Color(0xFF1565C0));
  final rose = BoardPalette.fromAccent(Brightness.light, const Color(0xFFC2185B));
  expect(blue.sameDigit, isNot(rose.sameDigit));
  expect(AppTheme.lightFor(const Color(0xFF1565C0)).colorScheme.primary,
      isNot(AppTheme.lightFor(const Color(0xFFC2185B)).colorScheme.primary));
});

test('强调底与对照字对比度达标', () {
  for (final id in AccentId.values) {
    final c = ThemeController.colorFor(id);
    for (final b in Brightness.values) {
      final p = BoardPalette.fromAccent(b, c);
      final fg = p.sameDigit.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
      expect(_contrast(p.sameDigit, fg), greaterThan(4.5));
    }
  }
});
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement** `ThemeController`, wire `MultiProvider` in `main.dart`:

```dart
class SudokuApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider(create: (_) {
          final c = ThemeController();
          c.load();
          return c;
        }),
      ],
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: ThemeMode.system,
          home: const MainShell(),
        ),
      ),
    );
  }
}
```

Keep `AppTheme.light()` / `dark()` as wrappers around default blue so old tests compile: `light() => lightFor(blue)`.

- [ ] **Step 4: `flutter test test/theme_controller_test.dart test/legibility_test.dart test/widget_test.dart`**

- [ ] **Step 5: Commit** `feat: add persistent accent colors on top of system light/dark`

---

### Task 10: Accent picker UI

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/game_screen.dart` (AppBar action)

**Interfaces:**
- Consumes: `ThemeController.setAccent`
- Produces: four circular swatches labeled 蓝/青绿/琥珀/玫红

- [ ] **Step 1: Widget test** `find.text('蓝')` after opening the picker from Home (add an `IconButton` tooltip `强调色`)

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement** a small dialog/bottom sheet `AccentPicker` used from Home header and Game AppBar. Selecting a swatch calls `setAccent`.

- [ ] **Step 4: Tests pass**

- [ ] **Step 5: Commit** `feat: add accent color picker`

---

### Task 11: Fixed board + hint overlay drawer

**Files:**
- Modify: `lib/screens/game_screen.dart`
- Modify: `lib/widgets/hint_panel.dart` if needed
- Modify: `test/hint_apply_button_test.dart`
- Create: `test/game_layout_test.dart`

**Interfaces:**
- Consumes: `HintSession.phase`
- Produces: board not inside a flexible height that shrinks when the hint appears; hint UI is a bottom overlay covering controls; Apply lives on the drawer and still auto-advances

Layout sketch:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final side = math.min(constraints.maxWidth - 32, 560.0);
    return Stack(
      children: [
        Column(
          children: [
            _buildInfoBar(gameState),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: side,
                height: side,
                child: SudokuGrid(...),
              ),
            ),
            _buildControlButtons(gameState),
            _buildNumberPad(gameState),
          ],
        ),
        if (_hintPanelVisible(gameState))
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Material(
              elevation: 8,
              child: _buildHintPanel(gameState),
            ),
          ),
      ],
    );
  },
);
```

If `Column` overflows on short screens, wrap **only the controls+pad** (not the board) in `Flexible(child: SingleChildScrollView(...))`. Board `SizedBox` stays fixed.

Hint drawer `HintPanel` keeps 应用. The lightbulb in the control row still **opens** a hint if none; while a hint is ready, tapping 应用 in the **drawer** calls `applyHintAndAdvance`. Optionally keep the control-row check icon as a second apply target, but the drawer button is required.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('提示出现前后棋盘高度不变', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = GameState()..loadCustomGame(_classic);
  await _pumpGame(tester, state);
  final before = tester.getSize(find.byType(SudokuGrid));
  await tester.tap(find.byIcon(Icons.lightbulb));
  await tester.pump();
  final after = tester.getSize(find.byType(SudokuGrid));
  expect(after, before);
  expect(find.text('应用删除').evaluate().isNotEmpty || find.text('应用本步').evaluate().isNotEmpty || find.text('应用').evaluate().isNotEmpty, isTrue);
});
```

Update `提示面板打开后控制键变成应用` so it still can 连点: tap 应用 on the drawer (find `FilledButton` / text `应用本步` or `应用删除`) twice and assert `hintsUsed` increases and session stays `ready`.

- [ ] **Step 2: FAIL** (board size changes or apply not in overlay)

- [ ] **Step 3: Implement layout**

- [ ] **Step 4: `flutter test test/hint_apply_button_test.dart test/game_layout_test.dart test/hint_panel_test.dart`**

- [ ] **Step 5: Commit** `fix: keep board size stable and overlay hint drawer on controls`

---

### Task 12: GitHub Actions Pages deploy

**Files:**
- Create: `.github/workflows/deploy-pages.yml`

**Interfaces:**
- Produces: workflow on `push` to `main` and `workflow_dispatch`; concurrency group `pages`

- [ ] **Step 1: Add workflow file**

```yaml
name: Deploy GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --release --base-href /sudoku-dart/
      - run: touch build/web/.nojekyll
      - uses: actions/upload-pages-artifact@v3
        with:
          path: build/web
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/deploy-pages.yml
git commit -m "$(cat <<'EOF'
ci: deploy Flutter web to GitHub Pages from main

EOF
)"
```

After merge, GitHub repo Settings → Pages → Source must be **GitHub Actions** (not the old `gh-pages` branch). Note this in the commit body if needed.

---

## Self-review

**Spec coverage**

| Spec section | Task |
|---|---|
| Technique model + unique boards + full copy | 1, 3–6 |
| Detail page structure + legend | 2 |
| Teaching colors / chain vs fish legends | 3–6 |
| Finder snapshot fallback | 3–6 |
| GitHub Actions Pages | 12 |
| Same-digit background highlight | 8 |
| Accent + system light/dark + persistence | 9–10 |
| Accent token coverage | 9 |
| Fixed board + drawer overlay + 连点 | 11 |
| Adaptive: controls under board, extra space below | 11 |
| Auto-strong undirected | 7 |
| Contrast / a11y | 8–9 tests |
| Completeness tests | 1, 3–6 |

**Placeholder scan:** Snapshot fallback is an explicit algorithm, not TBD. Unique puzzle table for fish may be replaced by solver snapshots; the completeness test still forbids shared placeholders.

**Type consistency:** `TechniqueInfo` fields named in Task 1 are the ones Tasks 2–6 use. `MarkupArrow.directed` from Task 7 is used by auto-strong and painter. `ThemeController` from Task 9 is used by Task 10 and `main.dart`. `AccentId` / `colorFor` must match tests in Task 9.
