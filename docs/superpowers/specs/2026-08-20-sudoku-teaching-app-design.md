# 数独教学程序设计

日期：2026-08-20

## 目标

做一个收纳完整命名技巧、能逐步给提示的数独教学程序。对局中只教一步；技巧说明是独立静态页。禁止无说明回溯填数。

## 信息架构

底栏两个入口，状态分开：

- **对局：** 选题难度 / 手动输入、计时计分、标记画板、逐步提示。
- **技巧说明：** 按从易到难的目录；每项一页固定文案 + 只读例盘（预制着色与箭头）。不演示、不填数、不跑求解、不覆盖对局棋盘。

去掉菜单「查看解法」。

## 对局提示

1. 点击提示只计算，不改盘。
2. 弹窗：技巧名、一行原理、动作细节（填哪格 / 删哪些候选）、链节点列表。
3. 棋盘高亮参与格，并在候选点之间画强/弱/共轭箭头。
4. 按钮：取消（不改盘、不计提示）/ 应用本步（填数或消候选，计一次提示）。
5. 顺序从易到难；能用短名特例就不用通用 AIC。
6. Simple Coloring 保留并排在 AIC 之前；3D Medusa 并进 AIC，不单独报。

## 搜索策略

- 浅层：命名技巧 + AIC 约 12 节点。
- 浅层无下一步且盘未完成：询问是否深度搜索。
- 深搜：同套技巧，链约 20 节点，Forcing Net 扇出加倍。成功仍报真实技巧名，附「（深度搜索）」。
- 深搜触顶仍无：告知失败，禁止回溯填数。
- 题集回归不得走到失败框。

台词：

- 邀请：标题「这一步需要更深的推理」；正文「用到目前的全部技巧后，还找不到可以填数或删除的候选。可以进行一次更深的搜索（更长的链、更大的假设网），可能会稍慢。是否继续？」按钮「先自己想」「深度搜索」。
- 失败：标题「未能找到下一步」；正文「在限定深度内没有推出新的填数或删除。可以检查已填数字是否有误，或换一题继续练习。」

## 技巧目录（从易到难）

已有：Naked/Hidden Single，Naked/Hidden Pair/Triple，Pointing，Box/Line，X-Wing，Swordfish，Jellyfish，XY/XYZ/W-Wing，Skyscraper，Simple Coloring，UR Type 1。

补齐：Naked/Hidden Quad；Finned/Sashimi X-Wing/Swordfish/Jellyfish；Franken/Mutant Fish（至 Jellyfish）；2-String Kite；Empty Rectangle；UR Type 2–4；BUG+1；WXYZ-Wing；ALS-XZ；ALS-XY-Wing；Sue de Coq；Death Blossom；XY-Chain；AIC 开链；Nice Loop/AIC 环；Grouped AIC；Kraken Fish（基础鱼+AIC）；Nishio；Digit/Cell/Unit Forcing Chain；Forcing Net。

Unique Rectangle / BUG+1 弹窗须写明「题目保证唯一解」。

## 标记画板（对局可开关，不影响得分）

点选，不手绘：

- 候选上色、格子上色
- 两点候选建强/弱/共轭箭头（共轭须合法：同数字且所在行或列或宫恰有两个该数字候选）
- 数字滤镜、共轭提示（可一键画上）、候选划掉（与引擎消除分层）、图层开关、清空本层/全部

教学例盘与提示高亮使用同一套标记数据模型。

## 题集

- 技巧单测：每项至少一盘，更浅技巧不得抢答，该技巧必须给出正确消除或填数。来源可含 SudokuWiki 例题 81 串（标注 URL）与最小构造盘。
- 全盘回归：HoDoKu 分级盘，须在浅层或深搜内解完，零无说明填数。
- 运行时不爬网；盘面检入仓库。

## 非目标

- 着色的 Multi-Coloring 独立报名
- Squirmbag/Whale/模板/嵌套动态链/Exocet 等目录外变体
- 手绘涂鸦
- 技巧说明页动态演示
