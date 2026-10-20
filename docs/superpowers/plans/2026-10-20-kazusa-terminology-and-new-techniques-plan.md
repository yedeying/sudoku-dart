# 数独技巧中文表述标准化与未覆盖技巧扩展 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将项目中的技巧名称、提示解释与教学正文全面对齐 Kazusa 数独教程规范术语（并修复初级飞鱼 Rule 5 覆盖线判定），同时补齐分档 1、2 的 15 个高可实现度技巧（含独立 Finder 与教学页）以及分档 3、4 的 13 个高阶/理论教学页（含机器复核结构声明）。

**Architecture:**
1. 在 `TechniqueCatalog._finderAliases` 中保留旧名称兼容，将 `TechniqueCatalog`、`SudokuSolver.hintSearchOrder`、`DifficultyAnalyzer.techniqueScores`、`PuzzleGrade` 与 `docs/techniques.md` 的主技巧名统一为 Kazusa 规范名，并润色生硬文案。
2. 在 `SudokuSolver` 与 `AdvancedTechniques` 中实现分档 1（6 项）和分档 2（9 项）共 15 个独立 Finder，并在 `lib/models/technique_examples_*.dart` 中新增对应教学条目与专属 81 位盘面。
3. 在 `lib/models/technique_structure.dart` 与 `test/support/teaching_verifier.dart` 中支持新增教学结构复核，新增分档 3（8 项）和分档 4（5 项）共 13 个 `teachingOnly: true` 教学条目，最后重生成中文字体子集并通过全量测试。

**Tech Stack:** Flutter / Dart (`flutter test`, `flutter analyze`), Python (`tools/build_font_subset.py`).

## Global Constraints

- 所有盘面（`examplePuzzle`）在 `TechniqueCatalog.all` 中必须 81 位且两两互不重复。
- `TechniqueCatalog.all` 的 `rank` 必须严格递增，且与 `docs/techniques.md` 总表及 `test/technique_catalog_test.dart` 的 `_reviewTableNames` 完全一致。
- `SudokuSolver.hintSearchOrder` 中的技巧名称必须与 `DifficultyAnalyzer.techniqueScores` 一一对应，且难度分单调不降（通过 `test/hint_order_monotonic_test.dart`）。
- 教学文案与提示解释使用 Hodoku 坐标记号（`r1c3`、`6r1c2`），禁止出现 `第 x 行第 x 列`，使用「区域」而非「房屋/单元」。
- 每个 `teachingOnly: true` 的条目必须包含非空 `structure: TeachingStructure(...)`，并通过 `test/teaching_structure_test.dart` 的独立校验。

---

### Task 1: 技巧主名称与生硬术语全面标准化（对齐 Kazusa 规范）+ 初级飞鱼 Rule 5 修复

**Files:**
- Modify: `lib/models/technique_catalog.dart`
- Modify: `lib/services/sudoku_solver.dart`
- Modify: `lib/services/advanced_techniques.dart`
- Modify: `lib/services/difficulty_analyzer.dart`
- Modify: `lib/models/puzzle_grade.dart`
- Modify: `lib/models/technique_examples_basic.dart`
- Modify: `lib/models/technique_examples_fish.dart`
- Modify: `lib/models/technique_examples_fish_variants.dart`
- Modify: `lib/models/technique_examples_wings.dart`
- Modify: `lib/models/technique_examples_uniqueness.dart`
- Modify: `lib/models/technique_examples_extended_rect.dart`
- Modify: `lib/models/technique_examples_unique_loop.dart`
- Modify: `lib/models/technique_examples_bug.dart`
- Modify: `lib/models/technique_examples_pending.dart`
- Modify: `lib/models/technique_examples_forcing_patterns.dart`
- Modify: `lib/models/technique_examples_chains.dart`
- Modify: `lib/models/technique_examples_advanced_chains.dart`
- Modify: `lib/models/technique_examples_advanced_sets.dart`
- Modify: `docs/techniques.md`
- Modify: `test/technique_catalog_test.dart` 及关联测试文件

**Interfaces:**
- Consumes: 现有 76 条 `TechniqueInfo` 与 `SudokuSolver.hintSearchOrder`
- Produces: 标准化后的 19 个主技巧名（并在 `TechniqueCatalog._finderAliases` 中保留全部 19 个旧名映射），以及修复后的 `AdvancedTechniques.findExocet` Rule 5 最小覆盖线判定。

- [ ] **Step 1: 在 `test/exocet_test.dart` 与 `test/technique_catalog_test.dart` 中更新标准名称断言并添加初级飞鱼 Rule 5 回归测试**
- [ ] **Step 2: 运行 `flutter test test/exocet_test.dart test/technique_catalog_test.dart` 确认因旧名与未修复逻辑而失败**
- [ ] **Step 3: 更新 `lib/models/technique_catalog.dart`、`lib/services/sudoku_solver.dart`、`lib/services/advanced_techniques.dart`、`lib/services/difficulty_analyzer.dart`、`lib/models/puzzle_grade.dart`、`lib/models/technique_examples_*.dart`、`docs/techniques.md` 及测试文件中的技巧名称与 Kazusa 术语表述**
- [ ] **Step 4: 运行 `flutter test` 确认全部现有测试通过**
- [ ] **Step 5: Commit (`refactor: 将技巧名称与教学提示术语全面标准化为 Kazusa 规范`)**

---

### Task 2: 新增分档 1（6 项高可实现度直观与拆步组合技巧：Finder + 教学页 + 测试）

**Files:**
- Modify: `lib/services/sudoku_solver.dart`
- Modify: `lib/services/advanced_techniques.dart`
- Modify: `lib/services/difficulty_analyzer.dart`
- Modify: `lib/models/puzzle_grade.dart`
- Modify: `lib/models/technique_examples_basic.dart`
- Modify: `lib/models/technique_examples_chains.dart`
- Modify: `docs/techniques.md`
- Modify: `test/technique_catalog_test.dart`
- Modify: `test/teaching_finders_test.dart`

**Interfaces:**
- Produces:
  - `SudokuSolver._findFullHouse(SudokuBoard)` -> `'单元唯一'` (score: 1, rank: 30)
  - `SudokuSolver._findLastDigit(SudokuBoard)` -> `'数字唯一'` (score: 1, rank: 40)
  - `AdvancedTechniques.findDirectLocked(SudokuBoard)` -> `'直观区块'` (score: 12, rank: 142)
  - `AdvancedTechniques.findDirectSubset(SudokuBoard)` -> `'直观数组'` (score: 14, rank: 146)
  - `AdvancedTechniques.findLockedSubset(SudokuBoard)` -> `'死锁数组'` (score: 18, rank: 180)
  - `AdvancedTechniques.findRemotePairs(SudokuBoard)` -> `'远程数对'` (score: 71, rank: 420)

- [ ] **Step 1: 在 `test/teaching_finders_test.dart` 与 `test/technique_catalog_test.dart` 中添加 6 个新技巧的测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 实现 6 个 Finder，补充 6 个专属盘面与 `TechniqueInfo` 教学条目，并更新 `docs/techniques.md`**
- [ ] **Step 4: 运行 `flutter test test/technique_catalog_test.dart test/teaching_finders_test.dart test/hint_order_monotonic_test.dart` 确认通过**
- [ ] **Step 5: Commit (`feat: 新增分档 1 六项直观与组合技巧教学及求解器`)**

---

### Task 3: 新增分档 2（9 项高可实现度独立几何与代数技巧：Finder + 教学页 + 测试）

**Files:**
- Modify: `lib/services/advanced_techniques.dart`
- Modify: `lib/services/sudoku_solver.dart`
- Modify: `lib/services/difficulty_analyzer.dart`
- Modify: `lib/models/puzzle_grade.dart`
- Modify: `lib/models/technique_examples_advanced_sets.dart`
- Modify: `lib/models/technique_examples_wings.dart`
- Modify: `lib/models/technique_examples_chains.dart`
- Modify: `docs/techniques.md`
- Modify: `test/technique_catalog_test.dart`
- Modify: `test/teaching_finders_test.dart`

**Interfaces:**
- Produces:
  - `AdvancedTechniques.findAlc(SudokuBoard)` -> `'欠一数组'` (score: 53, rank: 355)
  - `AdvancedTechniques.findFirework(SudokuBoard)` -> `'烟花数组'` (score: 57, rank: 365)
  - `AdvancedTechniques.findDualEmptyRectangle(SudokuBoard)` -> `'对交空矩形'` (score: 73, rank: 430)
  - `AdvancedTechniques.findPom(SudokuBoard)` -> `'图案叠加删数'` (score: 85, rank: 460)
  - `AdvancedTechniques.findMWing(SudokuBoard)` -> `'M-Wing'` (score: 88, rank: 470)
  - `AdvancedTechniques.findSWing(SudokuBoard)` -> `'S-Wing'` (score: 89, rank: 480)
  - `AdvancedTechniques.findDoublyLinkedAlsXz(SudokuBoard)` -> `'双强链待定数组'` (score: 95, rank: 665)
  - `AdvancedTechniques.findAlsWWing(SudokuBoard)` -> `'待定数组・W-Wing'` (score: 96, rank: 685)
  - `AdvancedTechniques.findRegionForcingChain(SudokuBoard)` -> `'区域强制链'` (score: 98, rank: 745)

- [ ] **Step 1: 在 `test/teaching_finders_test.dart` 与 `test/technique_catalog_test.dart` 中添加 9 个新技巧的测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 实现 9 个 Finder，补充 9 个专属盘面与 `TechniqueInfo` 教学条目，并更新 `docs/techniques.md`**
- [ ] **Step 4: 运行 `flutter test test/technique_catalog_test.dart test/teaching_finders_test.dart test/hint_order_monotonic_test.dart` 确认通过**
- [ ] **Step 5: Commit (`feat: 新增分档 2 九项独立几何与代数技巧教学及求解器`)**

---

### Task 4: 新增分档 3 & 4（13 项高阶与理论教学条目：`teachingOnly: true` + `TeachingStructure` 校验）

**Files:**
- Modify: `lib/models/technique_structure.dart`
- Modify: `test/support/teaching_verifier.dart`
- Modify: `lib/models/technique_examples_basic.dart`
- Modify: `lib/models/technique_examples_fish_variants.dart`
- Modify: `lib/models/technique_examples_advanced_chains.dart`
- Modify: `lib/models/technique_examples_advanced_sets.dart`
- Modify: `lib/models/technique_examples_uniqueness.dart`
- Modify: `docs/techniques.md`
- Modify: `test/technique_catalog_test.dart`
- Modify: `test/teaching_structure_test.dart`

**Interfaces:**
- Produces: 13 个 `teachingOnly: true` 的 `TechniqueInfo` 条目（`割补`、`鳍宫内鱼`、`区块环`、`鳍链`、`待定数组链`、`多米诺环`、`三值死环`、`双飞鱼`、`反转致命结构`、`唯一矩阵`、`唯一性提示数覆盖`、`复数鱼`、`宇宙法`），均带 `TeachingStructure` 声明并通过 `structureViolations` 复核。

- [ ] **Step 1: 在 `test/technique_catalog_test.dart` 与 `test/teaching_structure_test.dart` 中登记 13 个新教学条目**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 扩展 `teaching_verifier.dart`（如需要），编写 13 个教学条目及 `TeachingStructure` 声明，更新 `docs/techniques.md`**
- [ ] **Step 4: 运行 `flutter test test/teaching_structure_test.dart test/technique_catalog_test.dart test/technique_review_doc_test.dart` 确认通过**
- [ ] **Step 5: Commit (`feat: 新增分档 3 与分档 4 十三项高阶结构教学条目及机器复核`)**

---

### Task 5: 字体子集更新与全量回归验证

**Files:**
- Modify: `assets/fonts/AppSans-Regular.ttf`
- Modify: `assets/fonts/AppSans-Bold.ttf`

- [ ] **Step 1: 运行 `python3 tools/build_font_subset.py` 重新生成中文字体子集**
- [ ] **Step 2: 运行 `flutter analyze` 与 `flutter test` 验证全量测试零警告通过**
- [ ] **Step 3: Commit (`chore: 更新内置中文字体子集并通过全量回归测试`)**
