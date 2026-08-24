# Hodoku 记号与链表达式

## 目标

教学文案和提示文案不再用「第 x 行第 x 列」。格子、候选、链统一成 Hodoku 记号，链类技巧在教学和提示里都写出链表达式。

## 记号

| 对象 | 写法 | 例 |
|---|---|---|
| 格子 | `r{行}c{列}`，行列表 1–9 | `r3c5` |
| 候选 | `{数字}{格子}` | `6r3c5` |
| 行 / 列 / 宫 | `r3` / `c5` / `b5`（宫 1–9，行优先：上左=1） | |
| 填数结论 | `填 r3c5=8` | |
| 删除结论 | `删 6r1c2, 6r1c5` | |
| 强链 | `=` | |
| 弱链 | `-` | |
| 链 | 候选用 `=` / `-` 交替连接，两端空格 | `6r3c5 = 6r3c8 - 6r7c8 = 6r7c5` |

分组节点写成 `{6r7c2, 6r8c2, 6r9c2}`。不写「第 x 行第 x 列」「格子 (3,5)」。

整行/整列仍可用「r3 上数字 6 只出现在 c5 和 c8」这种短句，不要再展开成「第 3 行…第 5 列和第 8 列」。

## 提示

`SudokuHint.explanation` 以及 Game 提示抽屉里的位置行都用上表。

- 填数：抽屉副行改为 `填 r3c5=8`，不再写「位置：第 3 行，第 5 列 / 数字：8」。
- 删除：副行改为 `删 6r1c2, 6r1c5`。
- 链类（XY-Chain、AIC、Nice Loop、Grouped AIC、Skyscraper、Kite、Empty Rectangle、W-Wing、Coloring、Forcing / Nishio 等）：解释里必须含一行链表达式。
- 鱼 / 数组：用 `r2,r8` × `c3,c5` 或格子列表，不写「第 2 行和第 8 行都只能在第 3 列和第 5 列」。

所有解释字符串由 `lib/models/notation.dart` 的函数拼出来，禁止在 finder 里手写 `第 ${row + 1} 行`。

## 教学

`TechniqueInfo.walkthrough`（以及会点名格子的 `howToSpot` / `definition` / `caveats`）同样改记号。

能画成链的例题，walkthrough 里至少出现一行完整链表达式，与盘上绿起点 / 黄终点 / 实线强 / 虚线弱一致。

图例标签若含「第 x 行」一并改（例如「覆盖 r2,r8」）。

## 实现

- 新增 `lib/models/notation.dart`：`cellRef`、`candRef`、`rowRef`、`colRef`、`boxRef`、`chainExpr`、`fillLine`、`elimLine`。
- 改：`lib/services/sudoku_solver.dart`、`lib/services/advanced_techniques.dart`、`lib/screens/game_screen.dart` 提示副行、四份 `technique_examples_*.dart`。
- 测试：`notation` 单测；至少一条提示断言含 `6r` 或 `填 r`；教学 completeness 可加「walkthrough 不含『第』+『行第』」。

## 不做

- 不改棋盘绘制、箭头、强调色。
- 不改技巧目录 id / 名称 / 例题盘面本身。
- 不把用户界面按钮文案改成英文。
