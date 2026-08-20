# 数独解题技巧说明

本文档说明数独应用中支持的所有解题技巧，按难度从易到难排序。

## 1. 基础技巧

### 1.1 唯一候选数（Naked Single）
**难度：** ⭐

**描述：** 某个格子只有一个可能的候选数字。

**示例：** 如果格子 (5,5) 通过排除同行、同列和同宫格中已有的数字后，只剩下数字 5 可以填入，则该格子必定是 5。

**实现位置：** `sudoku_solver.dart:78-97`

---

### 1.2 隐藏单元（Hidden Single）
**难度：** ⭐⭐

**描述：** 某个数字在某行/列/宫格中只能放在一个位置。

**示例：** 如果数字 7 在第 3 行只能放在第 5 列，即使该格子还有其他候选数字，也必须填入 7。

**实现位置：** `sudoku_solver.dart:100-197`

---

## 2. 中级技巧

### 2.1 数字对（Naked Pair）
**难度：** ⭐⭐⭐

**描述：** 某行/列/宫格中有两个格子只有相同的两个候选数字，可以从该区域其他格子中删除这两个候选数字。

**示例：** 如果第 2 行的两个格子都只能是 {3, 7}，那么第 2 行的其他格子都不能是 3 或 7。

**实现位置：** `sudoku_solver.dart:200-321`

---

### 2.2 数字三元组（Naked Triple）
**难度：** ⭐⭐⭐

**描述：** 某行/列/宫格中有三个格子，它们的候选数字合并后只有三个，可以从该区域其他格子中删除这三个候选数字。

**示例：** 如果三个格子的候选分别是 {1,2}、{2,3}、{1,3}，那么这行其他格子都不能是 1、2 或 3。

**实现位置：** `sudoku_solver.dart:323-472`

---

### 2.3 指向对/三元组（Pointing Pair/Triple）
**难度：** ⭐⭐⭐

**描述：** 宫格内某数字的所有候选位置都在同一行或列，可以删除该行/列其他位置的该候选数字。

**示例：** 如果某宫格中数字 6 只能在第 4 行，那么第 4 行其他宫格的格子都不能是 6。

**实现位置：** `sudoku_solver.dart:474-550`

---

### 2.4 盒线削减（Box/Line Reduction）
**难度：** ⭐⭐⭐

**描述：** 某数字在行/列中的所有候选位置都在同一个宫格，可以删除该宫格其他位置的该候选数字。

**示例：** 如果第 7 列中数字 9 只能在某一个宫格，那么该宫格其他列的格子都不能是 9。

**实现位置：** `sudoku_solver.dart:552-635`

---

## 3. 高级技巧

### 3.1 X-Wing
**难度：** ⭐⭐⭐⭐

**描述：** 某数字在两行中各只有两个候选位置，且这些位置在相同的两列，可以删除这两列其他行的该候选数字。

**原理：** 形成一个矩形的四个角，该数字必定在对角线的两个格子中。

**示例：**
```
行1: 第3列和第7列可以是5
行5: 第3列和第7列可以是5
→ 第3列和第7列的其他行都不能是5
```

**实现位置：** `sudoku_solver.dart:637-731`

---

### 3.2 Swordfish
**难度：** ⭐⭐⭐⭐⭐

**描述：** X-Wing 的扩展版本，涉及三行三列的模式。

**原理：** 某数字在三行中的候选位置合并后只涉及三列，可以删除这三列其他行的该候选数字。

**实现位置：** `sudoku_solver.dart:733-832`

---

## 4. 专家级技巧

### 4.1 XY-Wing
**难度：** ⭐⭐⭐⭐⭐

**描述：** 三个只有两个候选数字的格子形成特定的 Y 型模式，可以删除特定位置的候选数字。

**结构：**
- 支点（Pivot）：有候选 {X, Y}
- 翅膀1（Wing1）：有候选 {X, Z}，能看到支点
- 翅膀2（Wing2）：有候选 {Y, Z}，能看到支点
- 结论：能同时看到两个翅膀的格子不能是 Z

**示例：**
```
格子A(支点): {3, 5}
格子B(翅膀1): {3, 8} - 能看到A
格子C(翅膀2): {5, 8} - 能看到A
→ 同时能看到B和C的格子不能是8
```

**实现位置：** `sudoku_solver.dart:834-913`

---

### 4.2 XYZ-Wing
**难度：** ⭐⭐⭐⭐⭐

**描述：** XY-Wing 的变体，支点有三个候选数字。

**结构：**
- 支点：有候选 {X, Y, Z}
- 翅膀1：有候选 {X, Y}，能看到支点
- 翅膀2：有候选 {Y, Z} 或 {X, Z}，能看到支点
- 结论：能同时看到三个格子的位置不能是它们的共同候选

**实现位置：** `sudoku_solver.dart:915-1000`

---

## 技巧应用顺序

`SudokuSolver.getHint()` 方法按以下顺序尝试各种技巧：

1. ✓ 唯一候选数（Naked Single）
2. ✓ 隐藏单元（Hidden Single）
3. ✓ 数字对（Naked Pair）
4. ✓ 数字三元组（Naked Triple）
5. ✓ 指向对（Pointing Pair）
6. ✓ 盒线削减（Box/Line Reduction）
7. ✓ X-Wing
8. ✓ Swordfish
9. ✓ XY-Wing
10. ✓ XYZ-Wing
11. 高级技巧（回溯算法）

## 使用方法

```dart
// 获取下一步提示
var hint = SudokuSolver.getHint(board);
if (hint != null) {
  print('技巧: ${hint.technique}');
  print('位置: (${hint.row}, ${hint.col}) = ${hint.value}');
  print('说明: ${hint.explanation}');
  
  // 应用提示
  board.set(hint.row, hint.col, hint.value);
}

// 获取完整解题步骤
var steps = SudokuSolver.getSolutionSteps(board);
for (var step in steps) {
  print('${step.technique}: (${step.row}, ${step.col}) = ${step.value}');
  print(step.explanation);
}
```

## 测试

运行测试以验证所有技巧：

```bash
flutter test test/sudoku_techniques_test.dart
```

## 性能优化

1. **早期终止**：一旦找到可应用的技巧，立即返回，不继续搜索更复杂的技巧。
2. **候选数字缓存**：`SudokuBoard` 维护每个格子的候选数字集合，避免重复计算。
3. **复杂度递增**：按难度顺序尝试技巧，简单技巧优先。

## 扩展建议

未来可以添加的更多高级技巧：

- **Unique Rectangle**：利用唯一解的特性
- **Coloring**：基于链式推理的着色技巧
- **Forcing Chains**：强制链技巧
- **ALS (Almost Locked Sets)**：几乎锁定集
- **Sue de Coq**：特殊的数字组合模式

## 难度评估

可以根据使用的技巧类型来评估数独的难度：

- **简单**：只需要 Naked Single 和 Hidden Single
- **中等**：需要 Naked Pair/Triple 或 Pointing Pair
- **困难**：需要 X-Wing 或 Swordfish
- **专家**：需要 XY-Wing、XYZ-Wing 或更高级的技巧
- **邪恶**：需要多次使用高级技巧或猜测

## 参考资料

- [Sudoku解题技巧大全](https://www.sudokuwiki.org/)
- [数独技巧图解](https://www.learn-sudoku.com/advanced-techniques.html)
- [Hodoku - Sudoku技巧](https://hodoku.sourceforge.net/en/techniques.php)
