import 'board_markup.dart';

/// 教学条目讲的是哪一类结构。测试按家族挑对应的几何条件去核对。
enum TeachingFamily {
  /// 两行两列四角、落在两个宫里的唯一矩形family。
  uniqueRect,

  /// 两条线各三格、落在两个宫里的扩展矩形。
  extendedRect,

  /// 偶数格环，每行每列每宫都恰好占环上两格。
  uniqueLoop,

  /// 可规避矩形：几何同唯一矩形，但要求角上已填的数字是玩家推出来的，不是已知数。
  avoidableRect,

  /// 双值死盘：拿掉 [TeachingStructure.extras] 之后每个空格恰好两个候选，
  /// 且每个房屋里每个未填数字恰好出现两次。
  bivalueGrave,

  /// 探长致命结构（BDP，三数）：一个宫里两行两列取三格的直角，
  /// 加上直角两行伸到宫外同一列的两格、两列伸到宫外同一行的两格，一共七格三个数。
  ///
  /// 几何取自 kazusa《三数探长致命结构的基本推理》：挖掉直角顶点后剩下的六格
  /// 正好是一个唯一环，第七格把它撑成三数结构。
  borescoper,

  /// 淑芬致命结构（QDP）：两条同一大行（大列）里的整线上的全部空格，
  /// 加上线外同一宫里横放（竖放）的两格。
  ///
  /// 几何取自 kazusa《淑芬致命结构的基本推理》里列出的结构特征。
  qiu,

  /// 鱼：一个数字、若干基线、若干覆盖线，鳍必须和基线同宫。
  /// 普通鱼、带鳍鱼、刺身鱼、Franken 鱼、Mutant 鱼共用这一族。
  fish,

  /// 双生鱼：两条共用鱼身的鱼叠在一张图上，各自算出一套删除。
  siameseFish,

  /// 多宝鱼：同数字的强-弱-强短链。
  turbot,

  /// 锁定集/待定数组：[TeachingStructure.cells] 上的候选并集大小
  /// 由 [TeachingStructure.lockedDigitCount] 说明。
  lockedSet,

  /// 同数字奇数圈加守卫。
  guardedOddCycle,

  /// 飞鱼导弹：基格并集锁住若干数字，目标格受同一组数字约束。
  exocet,

  /// 毛刺数组：一个房屋里 N 格锁 N+1 个数字，多出来的那一个候选只在一格上，
  /// 于是「数组成立」与「毛刺为真」构成一对互斥出路，整体当一个推理节点用。
  burredSubset,

  /// 分布式互斥数组（DDS）：N 格锁 N 个数字，每个数字各被一条房屋盖住，
  /// 而且这些房屋至少三条、谁也换不成两条。
  distributedDisjointSubset,

  /// 多区域锁定集（MSLS）：rank 0 的一般形，一个数字可以占用两条房屋，
  /// 所以格数等于「链接条数」而不是「数字个数」。
  multiSectorLockedSet,

  /// 弱待定数组（AHS，隐性一侧的待定数组）：一个房屋里 N 个数字的落点合起来
  /// 恰好 N+1 格，于是「多出来那一格属于这批数字」与「这批数字锁进其余格」
  /// 构成一对互斥出路。
  almostHiddenSet,

  /// 动态 AIC：先假设一个候选，把后果推进去，再用「推进去之后才出现」的强链接着走。
  dynamicChain,
}

/// 教学页在这个结构上下的是哪一档结论。测试按档位挑对应的推理条件去核对。
enum TeachingClaim {
  /// 只讲到致命结构本身：结构格不可能只填底数，所以多余候选里至少有一个为真。
  deadlyOnly,

  /// 只有一个多余候选，它必须为真。
  type1,

  /// 多余候选是同一个数字，删同时看得见它们的位置。
  type2,

  /// 多余候选合成虚拟格，和同房屋的格子配数组再删。
  type3,

  /// 某个底数被锁在结构的一个房屋里，删带多余候选那两格上的其它底数。
  type4,

  /// 隐性唯一矩形：靠两条底数强链把对角格逼回底数，从对角格删另一个底数。
  hiddenRect,

  /// 淑芬致命结构 Type 1：线外两格只有一格带额外候选，那一格必须跳出底数，
  /// 于是它上面的全部底数都能删掉。
  qiuType1,

  /// 双值死盘 Type 2：恰好两个例外格多出同一个数字，
  /// 删同时看得见这两格的位置上的那个数字。
  ///
  /// 死盘家族的档位单独列，是因为它的「底数」不是全盘公用的一组数字，
  /// 而是各例外格自己那两个候选，重算删除的算法和矩形族的同名类型不一样。
  graveType2,

  /// 双值死盘 +n：n（≥3）个例外格多出同一个数字，删法同 Type 2。
  gravePlusN,

  /// 双值死盘 Type 3：两个例外格同房屋、各多出一个不同数字，
  /// 并成虚拟格后与 [TeachingStructure.subsetCells] 配成数组再删。
  graveType3,

  /// 双值死盘 Type 4：两个例外格同房屋，共有底数 [TeachingStructure.lockDigit]
  /// 在那条房屋里只剩这两格，于是各删对面那一格的另一个底数。
  graveType4,

  /// 待定双值死盘：例外候选「不能同时为假」当成一个链节点，
  /// 靠一条链推出矛盾来落地删除。
  graveChainNode,

  /// 待定：多余候选整体当成一个链节点，本页不下删除结论。
  chainNode,

  /// 强制：每个多余候选各成一支假设，取各支共同的结论。
  forcing,

  /// 结构直接算出一组删除，删除集合由测试独立重算后逐条对齐。
  elimination,
}

/// 结构里一个格子的坐标（0 基）。
class CellRef {
  final int row;
  final int col;

  const CellRef(this.row, this.col);

  int get box => (row ~/ 3) * 3 + col ~/ 3;

  String get label => 'r${row + 1}c${col + 1}';

  @override
  bool operator ==(Object other) =>
      other is CellRef && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => label;
}

/// 鱼的基线/覆盖线可以是行、列或宫。
enum HouseKind { row, col, box }

/// 鱼的一条线：种类加 0 基编号。
///
/// 普通鱼（行基线 × 列覆盖）、Franken 鱼（一侧掺宫）、Mutant 鱼（同一侧混行与列）
/// 用的是同一套声明，所以判定也能共用同一段代码，不必按名字分岔。
class FishHouse {
  final HouseKind kind;
  final int index;

  const FishHouse(this.kind, this.index);

  const FishHouse.r(int index) : this(HouseKind.row, index);
  const FishHouse.c(int index) : this(HouseKind.col, index);
  const FishHouse.b(int index) : this(HouseKind.box, index);

  /// 统一的房屋编号：0-8 行，9-17 列，18-26 宫。
  int get house => switch (kind) {
        HouseKind.row => index,
        HouseKind.col => 9 + index,
        HouseKind.box => 18 + index,
      };

  String get label => switch (kind) {
        HouseKind.row => 'r${index + 1}',
        HouseKind.col => 'c${index + 1}',
        HouseKind.box => 'b${index + 1}',
      };

  bool contains(int row, int col) => switch (kind) {
        HouseKind.row => row == index,
        HouseKind.col => col == index,
        HouseKind.box => (row ~/ 3) * 3 + col ~/ 3 == index,
      };

  @override
  bool operator ==(Object other) =>
      other is FishHouse && other.kind == kind && other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);

  @override
  String toString() => label;
}

/// 一条完整的鱼。
///
/// 鱼的道理只有一条：[baseHouses] 两两不共格，所以 [digit] 在这些房屋里的落点
/// 恰好有「基线条数」个；这些落点全在 [coverHouses] 里，而覆盖线条数相同，
/// 于是每条覆盖线正好分到一个落点。由此得到两类删除——覆盖线上鱼身之外的同名候选，
/// 以及落在两条覆盖线交叉处的鱼身候选（那就是自噬）。
///
/// 声明里的 [fins]、[coverDeficits]、[eliminations] 都要求穷尽：
/// 测试会拿盘面把这三组重算一遍，多一个少一个都算教学文字说错了。
class FishSpec {
  final int digit;
  final List<FishHouse> baseHouses;
  final List<FishHouse> coverHouses;

  /// 基线上没被任何覆盖线盖住的候选，一个不漏。空表示这是条完整的鱼。
  final List<CandidateRef> fins;

  /// 缺掉的覆盖顶点：刺身那条基线和覆盖线交出的、没有 [digit] 候选的格子。
  /// 只在存在「去鳍后覆盖里只剩一个顶点」的基线时才有内容。
  final List<CellRef> coverDeficits;

  /// 这条鱼算出来的删除，一个不漏。
  final List<CandidateRef> eliminations;

  /// 声明这是刺身：去鳍以后有基线在覆盖线上只剩一个候选。
  final bool sashimi;

  /// 声明这是 Mutant：基线或覆盖的同一侧混了行与列，且两侧合起来还用到了宫。
  final bool mutant;

  /// 声明这条鱼有自噬删除：被删的候选落在鱼身上。
  final bool cannibal;

  /// 声明这套删除凑不出任何一条同数字多宝鱼的删除超集，
  /// 也就是「这一页的收获真的比摩天楼/双线风筝那一档多」。
  final bool beyondTurbot;

  /// 声明这套删除里没有一个是区块摒除（宫线锁定）顺手就能删掉的。
  /// 教学盘常常一不小心就举了个「换个说法的区块摒除」，所以这一条也写死。
  final bool beyondLocked;

  const FishSpec({
    required this.digit,
    required this.baseHouses,
    required this.coverHouses,
    this.fins = const [],
    this.coverDeficits = const [],
    this.eliminations = const [],
    this.sashimi = false,
    this.mutant = false,
    this.cannibal = false,
    this.beyondTurbot = false,
    this.beyondLocked = false,
  });
}

/// rank 0 集合里的一条链接：数字 [digit] 在结构格上的全部落点被 [houses] 盖住。
///
/// rank 0 的道理就是数链接：每个结构格必须填一个数，每条链接最多消化一个格子，
/// 所以「链接条数 = 格数」时，这些房屋里结构外的同名候选统统没地方待。
/// 一个数字允许占两条房屋（那时它算两条链接），这正是 MSLS 比 DDS 一般的地方。
class SectorLink {
  final int digit;

  /// 0-8 行，9-17 列，18-26 宫。
  final List<int> houses;

  const SectorLink(this.digit, this.houses);

  @override
  String toString() => '$digit@$houses';
}

/// 一枚飞鱼导弹（Junior Exocet）的全部部件。
///
/// 几何按 David P. Bird《Exocet Compendium》与 SudokuWiki 的图：
/// 两个基格同宫同线，落在一条带里；同带另外两宫各取一对「对象格」——
/// 同一列（横带时）上的两个非基线格，其中一格带基格数字（目标格），
/// 另一格一个基格数字都不带（伴随格，已知数也算）。
/// 三条交叉线是两个目标格所在的列，加上基格宫里基格没占的那一列。
/// 镜像格是「贴着对面那个目标格」的两格：目标格 T1 的镜像在 T2 所在的宫里、
/// 在另一条非基线行上、避开 T2 自己的那一列。
class ExocetSpec {
  final List<CellRef> baseCells;
  final List<CellRef> targets;
  final List<CellRef> companions;

  /// 与 [targets] 一一对应，每个目标格两枚镜像格。
  final List<List<CellRef>> mirrors;

  /// 三条交叉线（横带时是三列）：0-8 行，9-17 列。
  final List<int> crossLines;

  /// 每个基格数字在 S 格（交叉线伸出带外的那部分）上的落点，
  /// 被不超过两条覆盖线盖住。这一条是「两个目标格必须落到不同基格数字上」的依据。
  final List<SectorLink> coverLines;

  /// 目标格上不属于基格数字集的候选，一个不漏。
  final List<CandidateRef> eliminations;

  const ExocetSpec({
    required this.baseCells,
    required this.targets,
    required this.companions,
    required this.mirrors,
    required this.crossLines,
    required this.coverLines,
    required this.eliminations,
  });
}

/// 动态 AIC 的那一步假设，以及假设之后才长出来的那条强链。
class DynamicAssumption {
  /// 被假设为真的候选。
  final CandidateRef assume;

  /// 新长出来的强链盯的数字，和它所在的房屋（0-8 行，9-17 列，18-26 宫）。
  final int linkDigit;
  final int linkHouse;

  /// 假设之后这个数字在那个房屋里只剩的两格。
  final List<CellRef> linkCells;

  /// 假设之前（把唯余、摒除推到不能再推之后）这个数字在那个房屋里的落点个数。
  /// 必须大于 2，否则这条强链本来就在，谈不上「动态长出来」。
  final int staticSpots;

  const DynamicAssumption({
    required this.assume,
    required this.linkDigit,
    required this.linkHouse,
    required this.linkCells,
    required this.staticSpots,
  });
}

/// 链上的一段：两个候选、强弱、以及这一段所在的房屋（0-8 行，9-17 列，18-26 宫）。
class ChainSegment {
  final CandidateRef from;
  final CandidateRef to;
  final bool strong;
  final int house;

  const ChainSegment({
    required this.from,
    required this.to,
    required this.strong,
    required this.house,
  });
}

/// 教学条目对自己所讲结构的机器可核对声明。
///
/// 教学页上的散文很容易和盘面走偏——底数写错、额外候选漏掉一个、
/// 说「跨两个宫」其实跨了四个。所以每条把「我讲的是什么结构」也写成数据，
/// 让测试拿着盘面独立复核一遍，而不是去读那段中文。
///
/// [extras] 必须穷尽：结构格上除 [baseDigits] 以外的每一个候选都要列出来，
/// 少列一个就说明教学文字漏讲了一个会破坏结构的候选。
class TeachingStructure {
  final TeachingFamily family;

  /// 本页下的结论档位，决定测试还要核对哪些推理条件。
  final TeachingClaim claim;

  /// 底数（矩形/环/死盘）或基格数字（飞鱼导弹）。鱼类留空。
  final Set<int> baseDigits;

  /// 结构本体的格子，值被限制在 [baseDigits] 里的那一批。
  final List<CellRef> cells;

  /// 结构里不受底数限制的格子：淑芬致命结构两条整线上的空格就是这一类。
  /// 它们参与「换一种填法」的核对，但不要求只含底数，也不统计额外候选。
  final List<CellRef> freeCells;

  /// [cells] 上除 [baseDigits] 以外的全部候选，必须一个不漏。
  final List<CandidateRef> extras;

  /// Type 4 / 隐性唯一矩形里被锁住的底数。
  final int? lockDigit;

  /// 锁住 [lockDigit] 的房屋：0-8 行，9-17 列，18-26 宫。
  /// Type 4 一个房屋，隐性唯一矩形两个房屋（对角格所在的行与列）。
  final List<int> lockHouses;

  /// Type 3：和虚拟格配成数组的其它格子，以及数组占住的数字。
  final List<CellRef> subsetCells;
  final Set<int> subsetDigits;

  /// 可规避矩形：唯一解里落在结构角上的那个底数。
  /// 教学盘存不下「这一格是玩家填的」，但解里这一格确实会由玩家自己推出来填。
  final CellRef? filledCorner;
  final int? filledDigit;

  /// 结构跨的宫数；null 表示这一家族不检查宫数。
  final int? boxSpan;

  /// 鱼或同数字链盯的数字。
  final int? fishDigit;

  /// 这一页画的鱼。普通/带鳍/刺身/Franken/Mutant 各一条，双生鱼两条。
  final List<FishSpec> fishes;

  /// 同数字短链的分段，依次强-弱-强。
  final List<ChainSegment> chain;

  /// 声明这条多宝鱼的几何超出摩天楼、双线风筝、空矩形这三个已命名特例。
  final bool generalizedTurbot;

  /// 声明这一页的删除结论没有一个是区块摒除顺手就能删掉的。
  final bool beyondLocked;

  /// 锁定集：[cells] 上候选并集应有的大小。
  /// 待定数组（ALS）是格数 + 1，分离子集（DDS）是格数。
  final int? lockedDigitCount;

  /// 奇数圈的守卫格上的候选。
  final List<CandidateRef> guards;

  /// 飞鱼导弹的目标格。
  final List<CellRef> targets;

  /// 教学页明确说「这一格一定填这个数」的结论。
  /// 测试会拿盘面的唯一解核对，说错了就是教出去一个错结论。
  final List<CandidateRef> conclusionTrue;

  /// 教学页明确说「这个候选可以删」的结论，同样要和唯一解对得上。
  final List<CandidateRef> conclusionFalse;

  /// rank 0 集合（DDS / MSLS）的全部链接，一条不漏。
  final List<SectorLink> sectorLinks;

  /// 毛刺数组多出来的那一枚候选。
  final CandidateRef? burr;

  /// 弱待定数组里「多出来」的那一格：讲解就从它分成两种情况。
  final CellRef? splitCell;

  /// 动态 AIC 的假设与那条动态强链。
  final DynamicAssumption? assumption;

  /// 飞鱼导弹的部件。
  final ExocetSpec? exocet;

  /// 复核一支假设时，只许唯余加摒除往下填几格。
  ///
  /// 教学页写得出的分支必须短：不设上限的话唯余摒除常常顺手把整盘解完，
  /// 那样「两种情况都删掉同一个候选」就退化成了「答案里本来就不是它」。
  final int? replayBudget;

  const TeachingStructure({
    required this.family,
    this.claim = TeachingClaim.deadlyOnly,
    this.baseDigits = const {},
    this.cells = const [],
    this.freeCells = const [],
    this.extras = const [],
    this.lockDigit,
    this.lockHouses = const [],
    this.subsetCells = const [],
    this.subsetDigits = const {},
    this.filledCorner,
    this.filledDigit,
    this.boxSpan,
    this.fishDigit,
    this.fishes = const [],
    this.chain = const [],
    this.generalizedTurbot = false,
    this.beyondLocked = false,
    this.lockedDigitCount,
    this.guards = const [],
    this.targets = const [],
    this.conclusionTrue = const [],
    this.conclusionFalse = const [],
    this.sectorLinks = const [],
    this.burr,
    this.splitCell,
    this.assumption,
    this.exocet,
    this.replayBudget,
  });

  Set<int> get boxes => {for (final c in cells) c.box};
}
