# 技巧总览

已实现与收录中的未知技巧放在同一套标准里：统一中英名、家族、状态、难度档。难度档按解题里「通常第几层才轮到它」，不是工程工作量。

状态：`已有` 引擎能报；`部分` 只覆盖特例或基础形；`未有` 还没有独立报法。  
难度档：入门 → 基础 → 中级 → 高级 → 专家 → 极限。同档内按常见出现顺序排。  
`*` 表示该档是建议位置，尚未写入 `DifficultyAnalyzer`。

---

## 总表

| 档 | 名称 | 英/缩写 | 家族 | 状态 | 说明 |
|---|---|---|---|---|---|
| 入门 | 唯余法 | Naked Single | 基础 | 已有 | 一格只剩一个候选，直接填 |
| 入门 | 摒除法 | Hidden Single | 基础 | 已有 | 某数字在一行/列/宫只剩一个位置 |
| 基础 | 显性数对 | Naked Pair | 数组 | 已有 | 两格同一对数字，区域内删这对 |
| 基础 | 显性三数组 | Naked Triple | 数组 | 已有 | 三格锁三个数字 |
| 基础 | 显性四数组 | Naked Quad | 数组 | 已有 | 四格锁四个数字 |
| 基础 | 隐性数对 | Hidden Pair | 数组 | 已有 | 两数字只落在两格，格内其它候选可删 |
| 基础 | 隐性三数组 | Hidden Triple | 数组 | 已有 | 三数字只落在三格 |
| 基础 | 隐性四数组 | Hidden Quad | 数组 | 已有 | 四数字只落在四格 |
| 基础 | 宫区块 | Pointing | 区块 | 已有 | 宫内某数字只在一行/列，宫外那条线可删 |
| 基础 | 行/列区块 | Box/Line | 区块 | 已有 | 行/列上某数字只在一宫，宫内其它格可删 |
| 中级 | X-Wing | X-Wing | 鱼 | 已有 | 两行锁两列（或对调），覆盖线上其它可删 |
| 中级 | Swordfish | Swordfish | 鱼 | 已有 | 三行三列的鱼 |
| 中级 | Jellyfish | Jellyfish | 鱼 | 已有 | 四行四列的鱼 |
| 中级 | 带鳍 X-Wing | Finned X-Wing | 鱼 | 已有 | 差一个鳍才成 X-Wing，只删看得到鳍的覆盖 |
| 中级 | 带鳍 Swordfish | Finned Swordfish | 鱼 | 已有 | 三鱼带鳍 |
| 中级 | 带鳍 Jellyfish | Finned Jellyfish | 鱼 | 已有 | 四鱼带鳍 |
| 中级 | 刺身鱼 | Sashimi Fish | 鱼 | 未有 | 带鳍且缺一个覆盖顶点；刺身 X-Wing 常等于摩天楼 |
| 中级 | 双生鱼 | Siamese Fish | 鱼 | 未有 | 两条同型带鳍/刺身叠在一起；求解上等于连报两次 |
| 中级 | Franken 鱼 | Franken Fish | 鱼 | 部分 | 宫可当基线。现仅一线+一宫、覆盖两条 |
| 中级 | Mutant 鱼 | Mutant Fish | 鱼 | 未有 | 基线与覆盖都可混行/列/宫。名字已挂上，实现不是 |
| 中级 | 自噬 | Cannibalism | 修饰 | 未有 | 结构删到自己身上。鱼、SDC、ALS 都可 |
| 中级 | XY-Wing | XY-Wing | 翼 | 已有 | 支点 {x,y}，两翼共享 z，删同时看见两翼的 z |
| 中级 | XYZ-Wing | XYZ-Wing | 翼 | 已有 | 支点三值，两翼各取一对 |
| 中级 | 摩天楼 | Skyscraper | 链/鱼 | 已有 | 两列（行）同数字强链共一端，删两远端共同可见 |
| 中级 | 双线风筝 | 2-String Kite | 链/鱼 | 已有 | 一行一列两条强链在宫内拐弯 |
| 高级 | 空矩形 | Empty Rectangle | 链/鱼 | 已有 | 宫内某数字空出一行一列，再接一条强链 |
| 高级 | 多宝鱼 | Turbot Fish | 链/鱼 | 部分 | 同数字强-弱-强。摩天楼/风筝/空矩形是命名特例 |
| 高级 | Simple Coloring | Simple Coloring | 链 | 已有 | 同数字双色，同色相见或异色同格则删 |
| 高级 | W-Wing | W-Wing | 翼 | 已有 | 两格同为 {a,b}，中间一条 b 的强链，删共同可见的 a |
| 高级 | WXYZ-Wing | WXYZ-Wing | 翼 | 已有 | 四格四数字的翼 |
| 高级 | 唯一矩形 1 | UR Type 1 | 唯一性 | 已有 | 三角是 AB，第四格多一个，必须填多出来的 |
| 高级 | 唯一矩形 2 | UR Type 2 | 唯一性 | 已有 | 同侧两格多同一个数字，删共同可见处 |
| 高级 | 唯一矩形 3 | UR Type 3 | 唯一性 | 已有 | 多余数字与同区域其它格配数组（虚拟格） |
| 高级 | 唯一矩形 4 | UR Type 4 | 唯一性 | 已有 | 底数之一在区域成强链，删另一底数 |
| 高级 | 不完整 UR | Incomplete UR | 唯一性 | 未有 | 四角不必都还留着一对；给定数没堵死仍可认 |
| 高级 | 隐性/锁定 UR | Hidden / Locked UR | 唯一性 | 部分 | Type 4 即锁定。Hidden UR / Type 6 未做 |
| 高级 | 可规避矩形 | Avoidable Rectangle | 唯一性 | 未有 | 已填格须是玩家填的，不能是给定数 |
| 高级 | BUG+1 | BUG+1 | BUG | 已有 | 全盘只一格非双值，填行/列/宫都奇数次的那个 |
| 高级 | BUG+n | BUG+n | BUG | 未有 | n 个例外把 BUG 撑开；真数不能同时为假 |
| 高级 | BUG Type 2 | BUG Type 2 | BUG | 未有 | 例外格多同一个数字，删共同可见处 |
| 高级 | BUG Type 3 | BUG Type 3 | BUG | 未有 | 例外格与同区域配数组 |
| 高级 | BUG Type 4 | BUG Type 4 | BUG | 未有 | 底数强链，删另一底数 |
| 专家 | 唯一环 | Unique Loop | 唯一性 | 未有 | UR 拉成 6+ 格偶环；extend 即 Type 2–4 |
| 专家 | 扩展矩形 | Extended Rectangle | 唯一性 | 未有 | 2×3 / 3×2 两数字致命矩形 |
| 专家 | 探长 | BDP | 唯一性 | 未有 | 直角支点+两翼，三数或四数 |
| 专家 | 淑芬 | QDP | 唯一性 | 未有 | 邱少致命结构；另有锁定/外延/双淑芬 |
| 专家 | XY-Chain | XY-Chain | 链 | 已有 | 只走双值格的 AIC |
| 专家 | AIC 开链 | AIC | 链 | 已有 | 强弱交替，两端共同可见可删 |
| 专家 | Nice Loop | AIC Loop | 链 | 已有 | AIC 首尾相接 |
| 专家 | Grouped AIC | Grouped AIC | 链 | 已有 | 节点可以是一组格子 |
| 专家 | 死环 | Broken Loop | 链 | 未有 | 相邻皆强链，奇数圈同真矛盾。不是 Nice Loop |
| 专家 | 动态 AIC | Dynamic AIC | 链 | 未有 | 假设后新长出的强弱关系也可入链 |
| 专家 | Sue de Coq | SDC / TSDS | 分离子集 | 部分 | 宫×线交叉、两堆不交锁定集。Isolated / 三维 / 自噬未做 |
| 专家 | DDS | Distributed Disjoint Subsets | 分离子集 | 未有 | SDC 推到三个及以上区域 |
| 专家 | ALS-XZ | ALS-XZ | ALS | 已有 | 两 ALS 共享限制数字 X，删可见的 Z |
| 专家 | ALS-XY-Wing | ALS-XY-Wing | ALS | 已有 | 三 ALS 版 XY-Wing |
| 专家 | WALS | ALS-W-Wing / Weak ALS | ALS | 未有 | 或指 ALS 版 W-Wing，或指弱待定数组 |
| 专家 | 毛刺数组 | Burred Subset | ALS/链 | 未有 | 数组多出一块当链节点；鳍是用在鱼上的毛刺 |
| 专家 | Death Blossom | Death Blossom | ALS | 已有 | 一格多候选，每个数字各接一朵 ALS |
| 专家 | Almost UR/XR/UL | AUR / AXR / AUL | 唯一性/链 | 未有 | 差一步成致命结构，作 AIC 节点 |
| 专家 | Almost BUG | ABUG | BUG/链 | 未有 | 差一步成 BUG，作链节点 |
| 极限 | Kraken Fish | Kraken | 链/鱼 | 已有 | 鱼的每个可能位置接一条链，取公共删 |
| 极限 | Nishio | Nishio | 强制 | 已有 | 假设某候选导致矛盾则删 |
| 极限 | Forcing Chain | Forcing Chain | 强制 | 已有 | 单线假设推导 |
| 极限 | Forcing Net | Forcing Net | 强制 | 已有 | 多线假设网 |
| 极限 | Forcing UR/XR/UL | Forcing UR/XR/UL | 唯一性/强制 | 未有 | 以致命结构为假设分支，取各支公共结论 |
| 极限 | MSLS | Multi-Sector Locked Sets | 分离子集 | 未有 | 多区域锁定集，SDC/DDS 的更一般形 |
| 极限 | 飞鱼导弹 | Exocet | Exocet | 未有 | 一带两宫两基格锁 2–3 数；Junior/Senior/Weak/Double 等 |

未点名、只挂在「致命结构」总称下的：唯一矩阵 UM、线索覆盖 UCC、匿名致命结构 ADP、BUG-Lite。需要时再拆行。

---

## 按家族

### 基础与数组

唯余看「这一格还剩什么」，摒除看「这个数字还能去哪」。数组是同一区域内 n 格锁 n 个数字（显性看格，隐性看数字）。区块是宫和线互相压缩候选。这些都已实现，也是提示顺序的最前段。

### 鱼

普通鱼：N 条基线把某数字锁进 N 条覆盖线，覆盖线上基线以外的该数字可删。带鳍允许基线多出一个「鳍」，删除范围缩到看得到鳍的那截覆盖。

刺身是带鳍的退化：去掉鳍后鱼不完整（缺顶点）。现有带鳍要求鳍线仍占满覆盖，所以刺身报不出来。双生是两条几乎同一条鱼、覆盖差一条，连点提示会先后报，不必单独占一个提示名。

Franken 允许宫当一条基线；现在只有「一线 + 一宫、覆盖恰好两条」。Mutant 更自由，行/列/宫都能进基线或覆盖，尚未实现。自噬是修饰：删除落在鱼身自己的候选上。

### 翼与短链

XY / XYZ / W / WXYZ 是小范围可见关系。摩天楼、双线风筝、空矩形都是同数字两条强链加一条弱链，统称多宝鱼（Turbot）。一般几何和 Grouped Turbot 还没有，提示里仍报三个特例名。Simple Coloring 是同数字共轭涂两色。

### 唯一性

前提都是「题目保证唯一解」。UR 四格两行两列两宫、底数一对；Type 1–4 已有。不完整 UR 允许先前删掉某个底数，只要给定数没堵死。可规避矩形用玩家填数（非题目给定）当矩形的一角。唯一环是更长的偶环；扩展矩形是 2×3 / 3×2。探长（BDP）直角支点加两翼；淑芬（QDP）是邱言哲的多宫可互换形。

Almost 是差一步、当链节点；Forcing 是拿结构做假设分支。两者都还没有。

### BUG

全盘空格都是双值、每个数字在每行每列每宫恰两次，就是致命的 BUG。+1 已有：唯一例外格填奇数次那个候选。+n 只保证「真数不能同时为假」；Type 2/3/4 才是对应 UR 的用法。Almost BUG 进链。

### 链与强制

静态 AIC：只用当前盘面的强弱关系。XY-Chain 是只走双值格的 AIC。Nice Loop 是闭环。Grouped 允许节点是一组格。动态 AIC 允许假设之后新出现的共轭也入链，靠近 Forcing。死环是全强链奇数圈，不是强弱交替的 Nice Loop。

Nishio / Forcing Chain / Net 已有，是假设推导。Kraken 是鱼的每个可能落点接一条链。

### ALS 与分离子集

ALS：n 格 n+1 个数字。ALS-XZ、ALS-XY-Wing、Death Blossom 已有。WALS 一名两义，待确认。毛刺数组是「差点是数组」的链节点。

Sue de Coq 是宫与线交叉处拆成两堆不交的锁定集，基础形已有。DDS 把区域加到三个以上。MSLS 再一般化成任意多区域、格数与数字集对齐。

### Exocet

飞鱼导弹：一带（三宫横条或竖条）里两个基格锁定两三个数字，目标格和镜像宫同步。Junior / Senior / Weak / Double / Locked Member 都算 extend。引擎里没有。

---

## 和提示顺序的关系

`getHint` 大致是：唯余/摒除 → 数组 → 区块 → 普通鱼/带鳍/基础 Franken → 翼与短链 → 着色 → UR → BUG+1 → 静态链 → SDC → ALS → Kraken / 假设。

收录而未实现的，按家族应插在：

- 刺身：带鳍之后、翼之前（刺身 X-Wing 勿抢摩天楼）
- 不完整 UR / AR：现有 UR 前后
- UL / XR / 探长 / 淑芬：UR 与 BUG 附近
- BUG Type / +n：BUG+1 之后
- SDC 变体 / DDS / MSLS：基础 SDC 之后
- 多宝鱼一般形：可统一三个短链特例，或只补剩余几何
- Almost / 毛刺 / 动态 AIC：静态链之后
- Forcing 致命结构、Exocet：最末段，和现有 Forcing / Nishio 一级

---

## 收录原文

未知技巧的逐条工作理解仍在 [2026-08-25-unknown-techniques.md](./2026-08-25-unknown-techniques.md)。本页是标准化总表，不再按追问维度拆实现难度 / 算法可行性 / 理解难度。
