/// 按解题路径里出现过的最高难度技巧分六级。
enum PuzzleGrade {
  beginner,
  normal,
  advanced,
  professional,
  master,
  hell,
}

class PuzzleGradeInfo {
  final PuzzleGrade grade;
  final String id;
  final String title;
  final int scoreBonus;

  const PuzzleGradeInfo({
    required this.grade,
    required this.id,
    required this.title,
    required this.scoreBonus,
  });
}

class PuzzleGrades {
  static const all = [
    PuzzleGradeInfo(
      grade: PuzzleGrade.beginner,
      id: 'beginner',
      title: '入门',
      scoreBonus: 100,
    ),
    PuzzleGradeInfo(
      grade: PuzzleGrade.normal,
      id: 'normal',
      title: '普通',
      scoreBonus: 250,
    ),
    PuzzleGradeInfo(
      grade: PuzzleGrade.advanced,
      id: 'advanced',
      title: '进阶',
      scoreBonus: 400,
    ),
    PuzzleGradeInfo(
      grade: PuzzleGrade.professional,
      id: 'professional',
      title: '专业',
      scoreBonus: 550,
    ),
    PuzzleGradeInfo(
      grade: PuzzleGrade.master,
      id: 'master',
      title: '大师',
      scoreBonus: 700,
    ),
    PuzzleGradeInfo(
      grade: PuzzleGrade.hell,
      id: 'hell',
      title: '地狱',
      scoreBonus: 900,
    ),
  ];

  static const ids = [
    'beginner',
    'normal',
    'advanced',
    'professional',
    'master',
    'hell',
  ];

  /// 专业 / 大师 / 地狱 / 自定义 的快速填充额外会走这些删除。
  static const quickFillExtraTechniques = {
    '显性数对',
    '隐性数对',
    '显性三数组',
    '隐性三数组',
    '显性四数组',
    '隐性四数组',
    '宫区块',
    '行/列区块',
  };

  static bool extendsQuickFill(String difficulty) =>
      difficulty == 'custom' ||
      difficulty == 'professional' ||
      difficulty == 'master' ||
      difficulty == 'hell';

  static PuzzleGradeInfo info(PuzzleGrade grade) =>
      all.firstWhere((g) => g.grade == grade);

  static PuzzleGradeInfo? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  static String titleOf(String id) => byId(id)?.title ?? '自定义';

  /// 单个技巧所属的最低等级。题目取路径上最高的那一档。
  static PuzzleGrade gradeForTechnique(String technique) {
    final name = _canonical(technique);
    final mapped = _techniqueGrade[name];
    if (mapped != null) return mapped;
    for (final entry in _techniqueGrade.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }
    return PuzzleGrade.hell;
  }

  static PuzzleGrade gradeForTechniques(Iterable<String> techniques) {
    var max = PuzzleGrade.beginner;
    for (final t in techniques) {
      final g = gradeForTechnique(t);
      if (g.index > max.index) max = g;
    }
    return max;
  }

  static String _canonical(String name) {
    if (name == 'Nice Loop / AIC 环') return 'Nice Loop';
    if (name == '摒除法（行/列/宫）') return '摒除法';
    return name;
  }

  static const _techniqueGrade = <String, PuzzleGrade>{
    '唯余法': PuzzleGrade.beginner,
    '摒除法': PuzzleGrade.beginner,
    '显性数对': PuzzleGrade.normal,
    '显性三数组': PuzzleGrade.normal,
    '隐性数对': PuzzleGrade.normal,
    '宫区块': PuzzleGrade.normal,
    '行/列区块': PuzzleGrade.normal,
    '隐性三数组': PuzzleGrade.normal,
    '显性四数组': PuzzleGrade.normal,
    '隐性四数组': PuzzleGrade.normal,
    'X-Wing': PuzzleGrade.advanced,
    '摩天楼': PuzzleGrade.advanced,
    '双线风筝': PuzzleGrade.advanced,
    'Swordfish': PuzzleGrade.advanced,
    '多宝鱼': PuzzleGrade.advanced,
    '带鳍 X-Wing': PuzzleGrade.advanced,
    '刺身鱼': PuzzleGrade.advanced,
    '空矩形': PuzzleGrade.advanced,
    'Jellyfish': PuzzleGrade.advanced,
    'XY-Wing': PuzzleGrade.advanced,
    '唯一矩形 Type 1': PuzzleGrade.advanced,
    '不完整唯一矩形': PuzzleGrade.advanced,
    '唯一矩形 Type 2': PuzzleGrade.advanced,
    '全双值坟墓+1': PuzzleGrade.advanced,
    '可规避矩形': PuzzleGrade.advanced,
    '带鳍 Swordfish': PuzzleGrade.advanced,
    '唯一矩形 Type 4': PuzzleGrade.advanced,
    '隐性唯一矩形': PuzzleGrade.advanced,
    '全双值坟墓 Type 2': PuzzleGrade.advanced,
    '扩展矩形 Type 1': PuzzleGrade.advanced,
    'XYZ-Wing': PuzzleGrade.advanced,
    '带鳍 Jellyfish': PuzzleGrade.advanced,
    '扩展矩形 Type 2': PuzzleGrade.advanced,
    '唯一矩形 Type 3': PuzzleGrade.advanced,
    '全双值坟墓 Type 4': PuzzleGrade.advanced,
    '扩展矩形 Type 4': PuzzleGrade.advanced,
    '扩展矩形 Type 3': PuzzleGrade.advanced,
    '唯一环 Type 1': PuzzleGrade.advanced,
    '全双值坟墓 Type 3': PuzzleGrade.advanced,
    '唯一环 Type 2': PuzzleGrade.advanced,
    '宫内鱼': PuzzleGrade.advanced,
    '唯一环 Type 4': PuzzleGrade.advanced,
    '染色法': PuzzleGrade.advanced,
    '唯一环 Type 3': PuzzleGrade.advanced,
    '探长致命结构': PuzzleGrade.advanced,
    '淑芬致命结构': PuzzleGrade.advanced,
    'W-Wing': PuzzleGrade.advanced,
    'WXYZ-Wing': PuzzleGrade.advanced,
    'XY-Chain': PuzzleGrade.professional,
    '强弱交替链': PuzzleGrade.professional,
    '融合式待定数组': PuzzleGrade.professional,
    'Nice Loop': PuzzleGrade.professional,
    '区块链': PuzzleGrade.professional,
    '死环': PuzzleGrade.professional,
    '待定唯一矩形': PuzzleGrade.professional,
    'ALS-XZ': PuzzleGrade.professional,
    'DDS': PuzzleGrade.professional,
    '待定扩展矩形': PuzzleGrade.professional,
    '待定唯一环': PuzzleGrade.professional,
    '待定全双值坟墓': PuzzleGrade.professional,
    '死亡绽放': PuzzleGrade.master,
    '弱待定数组': PuzzleGrade.master,
    'Kraken Fish': PuzzleGrade.master,
    '毛刺数组': PuzzleGrade.master,
    '飞鱼导弹': PuzzleGrade.master,
    '分类强制链': PuzzleGrade.master,
    '强制唯一矩形': PuzzleGrade.master,
    '强制扩展矩形': PuzzleGrade.master,
    '强制唯一环': PuzzleGrade.master,
    'ALS-XY-Wing': PuzzleGrade.master,
    'Nishio': PuzzleGrade.hell,
    '分类强制网': PuzzleGrade.hell,
    '高级技巧': PuzzleGrade.hell,
  };
}
