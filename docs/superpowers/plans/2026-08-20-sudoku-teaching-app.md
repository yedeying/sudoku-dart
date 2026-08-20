# 数独教学程序 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 对局逐步提示（含箭头与深搜确认）+ 技巧说明静态页 + 标记画板，引擎按从易到难目录扩展并配公开题单测。

**Architecture:** 底栏 `MainShell` 持有对局 `GameState` 与独立的技巧说明路由。棋盘渲染统一消费 `BoardMarkup`（格色、候选色、箭头、划掉）。`SudokuHint` 带 `BoardMarkup` 与搜索深度标记。求解器按 `TechniqueCatalog` 顺序查找，禁止无说明回溯填数。

**Tech Stack:** Flutter / Dart, provider, flutter_test。无新第三方绘图库，箭头用 `CustomPainter`。

## Global Constraints

- 底栏名称必须是「对局」和「技巧说明」，禁止「教学」。
- 禁止 `_findBruteForceSolution` 作为用户可见填数；失败走深搜询问或失败对话框。
- 提示弹窗未点应用前不得改盘。
- 技巧说明页只读，不得调用 `getHint` / `applyHint`。
- 测试命令：`flutter test`；分析：`flutter analyze lib`。

## File map

- Create: `lib/models/board_markup.dart` — 标记数据
- Create: `lib/models/technique_catalog.dart` — 技巧元数据与顺序
- Create: `lib/screens/main_shell.dart` — 底栏
- Create: `lib/screens/technique_list_screen.dart`
- Create: `lib/screens/technique_detail_screen.dart`
- Create: `lib/widgets/board_arrows_painter.dart`
- Create: `lib/widgets/markup_toolbar.dart`
- Modify: `lib/main.dart`, `lib/widgets/sudoku_grid.dart`, `lib/screens/game_screen.dart`, `lib/screens/home_screen.dart`, `lib/models/game_state.dart`, `lib/services/sudoku_solver.dart`
- Create: `test/markup_test.dart`, `test/technique_catalog_test.dart`, `test/hint_search_policy_test.dart`
- Create: `test/fixtures/` 81-char puzzles with source comments

---

### Task 1: BoardMarkup 模型

**Files:**
- Create: `lib/models/board_markup.dart`
- Test: `test/markup_test.dart`

**Produces:** `BoardMarkup`, `CandidateRef`, `MarkupArrow`, `ArrowKind {strong, weak, conjugate}`

- [ ] 写测试：共轭箭头仅当同数字且行或列或宫内该数字候选恰为 2 个时合法
- [ ] `flutter test test/markup_test.dart` 先失败
- [ ] 实现 `BoardMarkup.canAddConjugate` / `addArrow`
- [ ] 测试通过

### Task 2: 技巧目录

**Files:**
- Create: `lib/models/technique_catalog.dart`
- Test: `test/technique_catalog_test.dart`

**Produces:** 有序列表 `TechniqueInfo {id, name, summary, difficultyRank, examplePuzzle, exampleMarkup}`

- [ ] 测试：顺序 rank 严格递增；含 Simple Coloring、不含独立 3D Medusa；含「技巧说明」所需中文名
- [ ] 实现目录（已有技巧填真实例盘；未实现技巧可先有文案与例盘、finder 后接）

### Task 3: 棋盘绘制标记与箭头

**Files:**
- Create: `lib/widgets/board_arrows_painter.dart`
- Modify: `lib/widgets/sudoku_grid.dart`

- [ ] 测试 widget：给定一格着色，该格背景变化（`test/markup_widget_test.dart`）
- [ ] Grid 接收 `BoardMarkup`，候选点为箭头端点，CustomPaint 画实线/虚线

### Task 4: 底栏与技巧说明

**Files:**
- Create: `lib/screens/main_shell.dart`
- Create: `lib/screens/technique_list_screen.dart`
- Create: `lib/screens/technique_detail_screen.dart`
- Modify: `lib/main.dart` home → MainShell
- Modify: `test/widget_test.dart` 断言底栏「对局」「技巧说明」

- [ ] 技巧说明页只读棋盘，不出现数字键盘
- [ ] 从技巧说明返回后对局 board 不变（用两个 Provider 或 GameState 与说明页本地数据分离）

### Task 5: 对局标记工具条

**Files:**
- Create: `lib/widgets/markup_toolbar.dart`
- Modify: `lib/models/game_state.dart`, `lib/screens/game_screen.dart`

- [ ] 开关「标记」；工具：格色、候选色、强/弱/共轭、滤镜、共轭提示、划掉、清层
- [ ] 不影响 `getScore`

### Task 6: 提示 UX

**Files:**
- Modify: `lib/services/sudoku_solver.dart` `SudokuHint` 增加 `markup`、`fromDeepSearch`
- Modify: `lib/screens/game_screen.dart` 去掉查看解法；提示弹窗应用 `hint.markup`
- Modify: `lib/models/game_state.dart` `getHint({int maxAicLength})`

- [ ] 未应用前 board 数字不变
- [ ] 消除提示不填数

### Task 7: 搜索策略

**Files:**
- Modify: `lib/services/sudoku_solver.dart` 删除用户路径上的 brute fill
- Test: `test/hint_search_policy_test.dart`

- [ ] `getHint(board, depth: shallow)` 找不到返回 null 而非填数
- [ ] `getHint(board, depth: deep)` 更长链
- [ ] UI：null + 未完成 → 深搜对话框；深搜仍 null → 失败对话框

### Task 8–N: 按目录补技巧 finder + fixtures

每个技巧：`test/fixtures/<id>.txt` + 测试「更浅技巧 getHint 不为该 id」+ 「开启到该 rank 时命中期望消除」。实现对应 finder，接入 catalog 顺序。

最后：HoDoKu 若干盘 `getSolutionSteps` 全程无 `高级技巧` 填数。

---

## Spec coverage

- 底栏/技巧说明/只读例盘 → Task 4
- 标记与箭头 → Task 1,3,5
- 逐步提示与去掉查看解法 → Task 6
- 深搜台词与禁止回溯填数 → Task 7
- 技巧目录与题集 → Task 2, 8–N
