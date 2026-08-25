# 未知技巧收录

只收录，不实现、不改引擎、不写教学页。后续追问直接往表里加行。

收录起点：鱼类泛化（Sashimi / Siamese）及之后。已在目录或 `getHint` 里的不算新技巧。

| 收录 | 名称 | 家族 | 工作理解 | 现状 | 备注 |
|---|---|---|---|---|---|
| 2026-08-25 | Sashimi（刺身鱼） | 鱼 | 带鳍鱼缺一个覆盖顶点；去鳍后鱼退化。X-Wing 常等于摩天楼 | 带鳍要求鳍线占满覆盖，找不到刺身 | Swordfish/Jellyfish 才有新删除 |
| 2026-08-25 | Siamese（双生鱼） | 鱼 | 两条同型带鳍/刺身共用鱼身、覆盖差一条、删除不同 | 无。连点会先后报两条 | Hodoku 可选项。最简双生刺身 X-Wing = 摩天楼 |
| 2026-08-25 | Incomplete UR | 唯一性 | 四角不必都还留着一对数字；给定数没堵死仍可认 UR | Type 1–4 要求四角都含底数对 | 先前删除后会漏 |
| 2026-08-25 | Locked UR | 唯一性 | 若指 Type 4（强链锁住底数之一）则已有；若指 Hidden UR / Type 6 则无 | Type 4 已有 | 待确认是否 Hidden UR |
| 2026-08-25 | UL（with extend） | 唯一性 | Unique Loop：6+ 格偶环，类型同 UR 1–4；extend = Type 2–4 / 再配数组 | 无 | Type 1 相对独立；extend 工作量同 UR3 |
| 2026-08-25 | XR（with extend） | 唯一性 | Extended Rectangle：2×3 / 3×2 两数字致命矩形；extend = 其上 Type 1–4 | 无 | 新几何，例盘难找 |
| 2026-08-25 | AR（with extend） | 唯一性 | Avoidable Rectangle：已填格须为玩家填入、非给定数；extend = Type 2–4 / Avoidable Loop | 无。盘面已有 `isInitial` | 与 UR 平行 |
| 2026-08-25 | BUG+2 | BUG | 两个例外把全盘 BUG 撑开；真数不能同时为假 | 仅 BUG+1 | 常需再接 Type 或链才有单步结论 |
| 2026-08-25 | BUG+3 | BUG | 同上，三个例外 | 仅 BUG+1 | 并入 +n 叙述，不必单独占提示名 |
| 2026-08-25 | BUG+n | BUG | n 个例外格（或 n 个多余候选）；+n 数个数，Type 数用法 | 仅 +1 | 与 Type 1–4 交叉，不是另一套并列技巧 |
| 2026-08-25 | BUG Type 2 | BUG | 例外格多同一个数字 → 删同时可见处 | 无 | 对 UR Type 2 |
| 2026-08-25 | BUG Type 3 | BUG | 例外格多余数字与同区域其它格配数组 | 无 | 对 UR Type 3；须虚拟格，不能当裸对 |
| 2026-08-25 | BUG Type 4 | BUG | 例外格所在区域底数之一成强链 → 删另一底数 | 无 | 对 UR Type 4 |
| 2026-08-25 | ABUG | BUG | 暂按 Almost BUG（待定 BUG）：差一步成 BUG/+n，作 AIC 节点 | 无 | 若实为 Reverse BUG 再改；未确认 |
| 2026-08-25 | SDC | 分离子集 | Sue de Coq / Two-Sector Disjoint Subsets：宫×线交叉，两堆不交锁定集 | 基础形态已有 | 未收 Isolated / Cannibalism / 三维 |
| 2026-08-25 | DDS | 分离子集 | Distributed Disjoint Subsets：SDC 推到三个及以上区域；N 格 N 数且同数字互相看见 | 无 | 与 MSLS / 三维 SDC 相邻 |
| 2026-08-25 | 多宝鱼（链） | 链 | Turbot Fish：同数字 强-弱-强 短 AIC，两端共同可见处可删 | 特例已有：摩天楼、双线风筝、空矩形 | 未收一般几何、Grouped Turbot、统一成链的报法 |
| 2026-08-25 | 死环 | 链 | 暂按全强链死环（Broken Loop）：环上相邻皆强链，奇数圈则同真矛盾可删 | 无独立报法 | 若指唯一环则见 UL；若指连续 Nice Loop 则已有 AIC 环 |
| 2026-08-25 | WALS | ALS | 两说待确认：① ALS-W-Wing；② 中文术语表「弱待定数组」Weak ALS（隐性侧） | 有 W-Wing、ALS-XZ、ALS-XY-Wing | 未收 ALS-W-Wing / 弱 ALS 独立报法 |
| 2026-08-25 | 毛刺数组 | ALS/链 | Burred / Finned Subset：数组多出一块「毛刺」，作链节点（显/隐皆可） | ALS 只作为 XZ / XY-Wing 构件 | 未收毛刺数组链；鳍是毛刺用在鱼上的特例 |
| 2026-08-25 | Almost UR | 唯一性/链 | AUR：差一步成致命矩形，多余候选作 AIC 强弱节点 | UR 1–4 只报完整矩形 | 与 ABUG 同类 |
| 2026-08-25 | Almost XR | 唯一性/链 | AXR：差一步成扩展矩形，作链节点 | 无 XR | 依赖 XR 几何 |
| 2026-08-25 | Almost UL | 唯一性/链 | AUL：差一步成唯一环，作链节点 | 无 UL | 依赖 UL |
| 2026-08-25 | Forcing UR | 唯一性/强制 | 以 UR 为假设分支：真则避开/构成致命矩形，取各支共同删数或填 | 有 Forcing Chain/Net，无 UR 型强制 | 和 Almost UR 不同：Almost 是链节点，Forcing 是分情况 |
| 2026-08-25 | Forcing XR | 唯一性/强制 | 同上，对象换成扩展矩形 | 无 XR | 依赖 XR |
| 2026-08-25 | Forcing UL | 唯一性/强制 | 同上，对象换成唯一环 | 无 UL | 依赖 UL |
| 2026-08-25 | Dynamic AIC | 链 | 动态 AIC：假设下新出现的强弱关系也可入链，不只用盘面静态共轭 | 有静态 AIC 开链 / Nice Loop / Grouped AIC | 靠近 Forcing Chain/Net；未收嵌套动态链 |
| 2026-08-25 | Franken Fish | 鱼 | 覆盖单位不限于纯行对纯列，宫可当一条基线 | 仅一线+一宫、覆盖恰两条（Franken X-Wing 级） | 未收 Franken SF/JF、带鳍/双生 Franken；Mutant 另条 |
| 2026-08-25 | Mutant Fish | 鱼 | 基线与覆盖都可混用行、列、宫，比 Franken 更自由 | 名字写在 Franken/Mutant 里，实现不是 Mutant | 未收任何 Mutant 规格或带鳍/双生 |
| 2026-08-25 | 自噬 | 修饰 | Cannibalism：结构删到自己身上的候选（鱼身/SDC 内部等） | 无 | 鱼、SDC、ALS 都可自噬；SDC 条已点名未收 Cannibalism |
| 2026-08-25 | 飞鱼导弹（with extend） | Exocet | Exocet：一带两宫里两个基格锁定 2–3 个数字，目标格受镜像约束 | 无 | extend：Junior / Senior / Weak / Double / Locked Member 等 |
| 2026-08-25 | MSLS | 分离子集 | Multi-Sector Locked Sets：多区域锁定集，格数与数字集平衡（rank 0） | 无 | SDC/DDS 的更一般形；DDS 条已写相邻 |
| 2026-08-25 | Deadly Pattern | 唯一性 | 总称：可互换填法且不影响盘外，唯一解下必被打破 | 仅 UR 1–4、BUG+1 | 已拆收 UL/XR/AR/BUG+/Almost/Forcing/探长/淑芬；未点名还有 UM、UCC、ADP、BUG-Lite 等 |
| 2026-08-25 | 探长（BDP） | 唯一性 | Borescoper's Deadly Pattern：直角支点+两翼，三数或四数，用法同 UR 1–4 | 无 | 亦称 abc-UR / abcd-UR |
| 2026-08-25 | 淑芬（QDP） | 唯一性 | Qiu's Deadly Pattern（邱少）：多宫行列可互换的致命形，三数或四数 | 无 | 另有锁定/外延/双淑芬 |

已有、不收入：普通/带鳍鱼，UR Type 1–4，BUG+1，摩天楼、双线风筝、空矩形，基础 Sue de Coq。基础 Franken（一线+一宫）已有，更大规格见上表。
