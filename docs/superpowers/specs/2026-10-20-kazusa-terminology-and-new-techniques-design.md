# 数独技巧中文表述标准化（对齐 Kazusa 规范）与未覆盖技巧扩展设计文档

- **日期**：2026-10-20
- **参考规范**：[kyoyama-kazusa/Sudoku 教程与术语索引](https://github.com/kyoyama-kazusa/Sudoku/blob/main/docs/tutorial/SUMMARY.md)
- **范围**：
  1. **Task 1（中文表述标准化）**：将技巧目录名称、提示解释（`SudokuHint.explanation`）、教学正文（`TechniqueInfo`）、结构校验器与评审文档（`docs/techniques.md`）中的生硬翻译腔统一为 Kazusa 教程规范术语。
  2. **Task 2（新增 1/2/3/4 四档教学与高可实现度 Finder）**：按可实现度分档，为分档 1、2 的技巧新增教学条目与独立求解器（`teachingOnly: false`），为分档 3、4 的高阶技巧新增教学条目与机器可复核的结构声明（`teachingOnly: true`）。

---

## 一、 Task 1：中文术语与技巧名标准化方案

### 1.1 核心技巧名称映射表

在保持向后兼容（`TechniqueCatalog._finderAliases` 收录全部旧名）的前提下，将主名称统一为 Kazusa 标准名称：

| 原名称 | 标准名称（Kazusa 规范） | 英文对照 | 备注 |
|---|---|---|---|
| 唯余法 | 唯一余数 | Naked Single | 直观技巧 |
| 摒除法 | 排除 | Hidden Single / Crosshatching | 直观技巧 |
| 带鳍 X-Wing | 鳍 X-Wing | Finned X-Wing | 鱼类 |
| 带鳍 Swordfish | 鳍 Swordfish | Finned Swordfish | 鱼类 |
| 带鳍 Jellyfish | 鳍 Jellyfish | Finned Jellyfish | 鱼类 |
| 刺身鱼 | 退化鱼 | Sashimi Fish | 鱼类 |
| 双生鱼 | 孪生鱼 | Siamese Fish | 鱼类 |
| Mutant 鱼 | 交叉鱼 | Mutant Fish | 复杂鱼 |
| 不完整唯一矩形 | 残缺唯一矩形 | Incomplete Unique Rectangle | 致命结构 |
| 扩展矩形 Type 1–4 | 拓展矩形 Type 1–4 | Extended Rectangle (XR) | 致命结构 |
| 全双值坟墓+1 / +n | 全双值格致死解法+1 / +n | Bivalue Universal Grave (BUG) | 致命结构 |
| 全双值坟墓 Type 2–4 | 全双值格致死解法 Type 2–4 | BUG Type 2–4 | 致命结构 |
| 待定扩展矩形 | 待定拓展矩形 | Almost Extended Rectangle | 待定致命结构 |
| 待定全双值坟墓 | 待定全双值格致死解法 | Almost BUG | 待定致命结构 |
| 强制扩展矩形 | 强制拓展矩形 | Forcing Extended Rectangle | 强制致命结构 |
| 融合式待定数组 | 融合待定数组 | Sue de Coq (SdC) | 零秩结构 |
| DDS | 跨区数组 | Distributed Disjoint Subset | 零秩结构 |
| 弱待定数组 | 隐性待定数组 | Almost Hidden Set (AHS) | 链与待定集 |
| 飞鱼导弹 | 初级飞鱼 | Junior Exocet (JE) | 飞鱼 |

### 1.2 行文术语替换规范

全面清理 `lib/models/technique_examples_*.dart`、`lib/services/advanced_techniques.dart`、`lib/services/sudoku_solver.dart` 与 `docs/techniques.md` 中的生硬口语及机器翻译词汇：

| 生硬/旧表述 | Kazusa 标准表述 |
|---|---|
| 房屋 / 单元 | 区域（行、列、宫的统称） |
| 大行 / 带、竖带 | 大行（Band）、大列（Tower）、大行列（Chute） |
| 已知数 | 提示数（已知数） |
| 成数 / 填数 | 填入数（明数）、出数（赋值） |
| 候选 | 候选数 |
| 删掉 / 拿掉 | 删数 / 排除 |
| 支点（Wing 中） | 拐点 / 折点（Pivot） |
| 限制公共候选 | 严格共享候选数（RCC） |
| 基格 / 目标格 / 伴随格 / S 格 / 镜像格 | 基准单元格（基格） / 目标单元格（目标格） / 伴随单元格 / 交叉单元格（S 格） / 镜面单元格（镜面格） |
| 强区域 / 弱区域（鱼与秩理论） | 定义域（强区域/基线） / 删除域（弱区域/覆盖线） |
| 逼出 / 逼成 / 盯住 | 推出 / 迫使 / 观察数字 |

---

## 二、 Task 2：新增 1/2/3/4 四档技巧教学与求解器设计

所有新增条目均严格遵守仓库门禁：
1. 每条技巧配备**全库唯一**的 81 位 `examplePuzzle`，候选数与删数/出数结论通过回溯求解器真值检验；
2. `rank` 严格递增，并与 `docs/techniques.md` 总表及 `test/technique_catalog_test.dart` 的 `_reviewTableNames` 一一对应；
3. `teachingOnly: false` 的技巧接入 `SudokuSolver.hintSearchOrder`、`DifficultyAnalyzer.techniqueScores`（保持单调不降）与 `PuzzleGrade`；
4. `teachingOnly: true` 的技巧配备 `TeachingStructure` 声明并通过 `teaching_verifier.dart` 独立复核。

### 2.1 分档 1：高可实现度・细分直观与组合技巧（`teachingOnly: false`，带独立 Finder）

| ID | 名称 | 档位 | 难度分 | Rank | 核心判定与实现设计 |
|---|---|---|---:|---:|---|
| `full_house` | 单元唯一 | 入门 | 1 | 30 | 某行、列或宫内恰好只剩 1 个空格，直接得出该区域唯一缺少的数字（排在 `唯一余数` 之前或同档最前） |
| `last_digit` | 数字唯一 | 入门 | 1 | 40 | 某个数字在全盘已出现 8 次，余下唯一未出现该数字的行与列交点即为出数位置 |
| `direct_locked` | 直观区块 | 基础 | 12 | 142 | 某宫内的数字候选数虽未锁定到单格，但全部落于同一行/列，从而封锁相邻宫的同行/列，使相邻宫内该数字只剩唯一空位直接出数 |
| `direct_subset` | 直观数组 | 基础 | 14 | 146 | 某区域内隐性数对占住两个格子后，该区域另一个数字在这两格之外只剩唯一空位，直接得出该格填数 |
| `locked_subset` | 死锁数组 | 基础 | 18 | 180 | 显性数对/三数组恰好全部位于同一宫与同一行（或列）的交集内，同时排除该宫与该行（列）其余格的候选数 |
| `remote_pairs` | 远程数对 | 高级 | 71 | 420 | 由至少 4 个具有完全相同候选数对 `{a,b}` 的双值格组成的偶数长链，同时看到链头与链尾的单元格可同时删去 `a` 和 `b` |

### 2.2 分档 2：高可实现度・独立几何与代数技巧（`teachingOnly: false`，带独立 Finder）

| ID | 名称 | 档位 | 难度分 | Rank | 核心判定与实现设计 |
|---|---|---|---:|---:|---|
| `alc` | 欠一数组 | 中级 | 53 | 355 | 宫线交界格与宫外/宫内格构成 $N$ 格 $N$ 数的双向锁定（Almost Locked Candidates），同时清理宫内与线上的冗余候选数 |
| `firework` | 烟花数组 | 中级 | 57 | 365 | 同宫不同行不同列的两格（或加交点三格）与宫外同行一格、同列一格共同锁定 3 个数字，删去三格内部的其他候选数或外部交汇候选数 |
| `dual_er` | 对交空矩形 | 高级 | 73 | 430 | 两个空矩形在行与列上互相对交形成闭合或双向强弱传导，删去交汇处的同数字候选数 |
| `pom` | 图案叠加删数 | 高级 | 85 | 460 | 对单个数字枚举全盘所有合法的 9 格无冲突摆放模板，删除在所有合法模板中从不出现的候选数位置 |
| `m_wing` | M-Wing | 高级 | 88 | 470 | 具名异数四节点短链：双值格 `{a,b}` 与含 `{a,b}` 的格通过一条 `a` 的强链与一条 `b` 的弱链（在同一格内转折）相连，删去共同可见的候选数 |
| `s_wing` | S-Wing | 高级 | 89 | 480 | 具名异数短链（含 H-Wing / L-Wing 同族说明）：中间一条数字 `x` 的强链向两端分别连接双值格 `{x,a}` 与 `{x,b}`（当 $a=b$ 时删两端共同可见的 $a$） |
| `doubly_als_xz` | 双强链待定数组 | 专家 | 95 | 665 | 两朵待定数组（ALS）同时存在两个严格共享候选数（RCC）$X_1, X_2$，构成零秩互锁，可删外部所有可见的 $X_1, X_2$ 以及两朵 ALS 内部非 $X_1, X_2$ 的同区域可见候选数 |
| `als_w_wing` | 待定数组・W-Wing | 专家 | 96 | 685 | 两朵均含候选数 $x, z$ 的待定数组（ALS），通过一条数字 $x$ 的共轭强链相连，删去同时看见两朵 ALS 中所有 $z$ 的候选数 |
| `region_forcing` | 区域强制链 | 极限 | 98 | 745 | 针对某行、列或宫内某个数字仅有的 2~3 个候选位置分别作假设推导，取所有分支共同得出的出数或删数结论 |

### 2.3 分档 3：中可实现度・高阶结构教学条目（`teachingOnly: true`，带 `TeachingStructure` 校验）

| ID | 名称 | 档位 | 难度 | 实现 | 核心结构与 `TeachingStructure` 复核方式 |
|---|---|---|---:|---:|---|
| `lol` | 割补 | 中级 | 5.1 | 5.0 | 宫与行/列交叉后剩余两部分的数字集合恒等（Law of Leftovers），通过 `lockedSet` / 集合守恒复核结论 |
| `finned_franken_fish` | 鳍宫内鱼 | 高级 | 7.2 | 6.5 | 含宫作为定义域/删除域且带鱼鳍的复杂鱼，复用 `TeachingFamily.fish` 校验器 |
| `grouped_nice_loop` | 区块环 | 专家 | 9.4 | 6.8 | 含有区块节点的连续/不连续环，复用动态/锁定链复核 |
| `finned_chain` | 鳍链 | 专家 | 9.5 | 7.1 | 主链带鱼鳍分支（Kraken / Finned AIC），复核主链与鳍分支共同删数 |
| `als_chain` | 待定数组链 | 专家 | 9.7 | 7.3 | 4 朵及以上 ALS 通过 RCC 串联，复核首尾公共候选删数 |
| `domino_loop` | 多米诺环 | 极限 | 9.7 | 7.6 | 跨四宫八骨牌的 16 格零秩环（SK Loop），通过 `multiSectorLockedSet`（Rank 0）复核 |
| `trivalue_oddagon` | 三值死环 | 极限 | 9.6 | 7.7 | 三个候选数在奇数个区域内构成的带守护者死环，扩展守护者环复核 |
| `double_exocet` | 双飞鱼 | 极限 | 9.8 | 8.2 | 同大行/大列内共用交叉线的对称双初级飞鱼（同时介绍高级飞鱼 SE），复用 `exocet` 复核 |

### 2.4 分档 4：低可实现度・理论与全局结构教学条目（`teachingOnly: true`，带 `TeachingStructure` 复核）

| ID | 名称 | 档位 | 难度 | 实现 | 核心结构与 `TeachingStructure` 复核方式 |
|---|---|---|---:|---:|---|
| `reversed_deadly` | 反转致命结构 | 高级 | 7.6 | 5.2 | 局部双值致死（BUG-Lite / RUR / RXR），局部格内候选数在各区域均成对出现，套用致命结构复核 |
| `unique_matrix` | 唯一矩阵 | 高级 | 8.0 | 7.0 | 3×3 宫格内或跨宫的多底数致命矩阵置换结构，套用致命置换复核 |
| `ucc` | 唯一性提示数覆盖 | 高级 | 8.4 | 7.5 | 利用提示数覆盖关系避免局部无提示子结构多解，套用致命结构复核 |
| `multifish` | 复数鱼 | 极限 | 9.8 | 8.6 | 多数字联合零秩覆盖（同时涵盖负秩结构原理说明），通过零秩 `sectorLinks` 复核 |
| `gsp` | 宇宙法 | 极限 | 9.9 | 8.8 | 基于盘面对称性与数字自同构映射的宇宙法（Gurth's Symmetrical Placement），复核对称格映射与唯一解结论 |

---

## 三、 架构与实现步骤拆解

1. **阶段 1：中文术语与技巧名全面标准化**
   - 更新 `lib/models/technique_catalog.dart`（主名称与 `_finderAliases`）、`lib/services/sudoku_solver.dart`、`lib/services/advanced_techniques.dart`、`lib/services/difficulty_analyzer.dart`、`lib/models/puzzle_grade.dart`。
   - 润色 `lib/models/technique_examples_*.dart` 全部 14 个文件中的生硬表述，同时顺手修复此前审查指出的 `初级飞鱼`（原飞鱼导弹）Rule 5 最小覆盖线判定与教学图多余弱链箭头。
   - 同步更新 `docs/techniques.md` 与测试文件中的技巧名称断言，确保全量现有测试通过。
2. **阶段 2：实现分档 1 & 2 的 15 个高可实现度技巧（Finder + 教学页 + 单测）**
   - 在 `lib/services/sudoku_solver.dart` 与 `lib/services/advanced_techniques.dart` 中实现 15 个独立 Finder。
   - 新增对应的教学条目（专属 81 位盘面、标记、四段式 Kazusa 风格说明）并接入 `hintSearchOrder` 与 `techniqueScores`。
3. **阶段 3：实现分档 3 & 4 的 13 个高阶/理论教学条目（`teachingOnly: true` + `TeachingStructure` 校验）**
   - 必要时在 `lib/models/technique_structure.dart` 与 `test/support/teaching_verifier.dart` 中补充对新增教学结构的复核分支。
   - 构造并通过全部 13 个教学盘面与 `TeachingStructure` 机器校验。
4. **阶段 4：字体子集重生成与全量测试回归**
   - 运行 `python3 tools/build_font_subset.py` 更新内置中文字体子集（避免新增汉字缺字）。
   - 运行 `flutter analyze` 与 `flutter test` 确保零警告、全绿通过。
