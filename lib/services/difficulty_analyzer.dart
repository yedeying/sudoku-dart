import '../models/sudoku_board.dart';
import 'sudoku_solver.dart';

/// 数独难度分析器
/// 根据解题所需的技巧来评估题目难度
class DifficultyAnalyzer {
  /// 技巧难度分数
  static const Map<String, int> techniqueScores = {
    '唯余法': 1,
    '摒除法（行/列/宫）': 2,
    '显性数对': 5,
    '隐性数对': 15,
    '显性三数组': 10,
    '隐性三数组': 20,
    '显性四数组': 25,
    '隐性四数组': 30,
    '宫区块': 15,
    '行/列区块': 15,
    'X-Wing': 25,
    'Swordfish': 40,
    '多宝鱼': 40,
    'Jellyfish': 50,
    '带鳍 X-Wing': 45,
    '刺身鱼': 46,
    '带鳍 Swordfish': 55,
    '带鳍 Jellyfish': 62,
    'Franken 鱼': 68,
    'XY-Wing': 50,
    'XYZ-Wing': 60,
    '唯一矩形 1': 50,
    '不完整唯一矩形': 52,
    '唯一矩形 2': 54,
    '唯一矩形 3': 62,
    '唯一矩形 4': 56,
    '隐性唯一矩形': 58,
    'Simple Coloring': 70,
    'W-Wing': 90,
    'WXYZ-Wing': 92,
    'BUG+1': 54,
    'BUG 类型 2': 60,
    'BUG 类型 3': 66,
    'BUG 类型 4': 62,
    '扩展矩形 1': 60,
    '扩展矩形 2': 62,
    '扩展矩形 4': 63,
    '扩展矩形 3': 65,
    '唯一环 1': 66,
    '唯一环 2': 68,
    '唯一环 4': 70,
    '唯一环 3': 72,
    '探长': 74,
    '淑芬': 82,
    '可规避矩形': 55,
    '摩天楼': 32,
    '双线风筝': 36,
    '空矩形': 48,
    'XY-Chain': 91,
    'AIC 开链': 92,
    'Nice Loop / AIC 环': 93,
    'Sue de Coq': 92,
    'Grouped AIC': 94,
    '死环': 94,
    'ALS-XZ': 95,
    'ALS-XY-Wing': 98,
    'Death Blossom': 96,
    'Kraken Fish': 97,
    // 「毛刺为真」那一支推到推不动为止，读起来是强制链的力度，不是数组的
    // 认形，所以和 Kraken 同档而排在它后面，不占 9.4。
    '毛刺数组': 97,
    'Nishio': 99,
    'Forcing Chain': 98,
    'Forcing Net': 99,
    '高级技巧': 100,
  };

  /// 难度等级定义
  static const Map<String, DifficultyLevel> difficultyLevels = {
    'easy': DifficultyLevel(
      name: '简单',
      minScore: 0,
      maxScore: 80,
      requiredTechniques: ['唯余法'],
      forbiddenTechniques: [
        'X-Wing',
        'Swordfish',
        'XY-Wing',
        'XYZ-Wing',
        '高级技巧'
      ],
    ),
    'medium': DifficultyLevel(
      name: '中等',
      minScore: 60,
      maxScore: 200,
      requiredTechniques: [], // 中等难度可以只用基础技巧但较多步骤
      forbiddenTechniques: [
        'X-Wing',
        'Swordfish',
        'XY-Wing',
        'XYZ-Wing',
        '高级技巧'
      ],
    ),
    'hard': DifficultyLevel(
      name: '困难',
      minScore: 150,
      maxScore: 400,
      requiredTechniques: [], // 允许使用各种技巧
      forbiddenTechniques: ['高级技巧'], // 但不能用回溯
    ),
    'expert': DifficultyLevel(
      name: '专家',
      minScore: 300,
      maxScore: 10000,
      requiredTechniques: [], // 专家级可以用任何技巧
      forbiddenTechniques: [],
    ),
  };

  /// 分析题目难度
  static DifficultyResult analyzeDifficulty(SudokuBoard board) {
    final trace = SudokuSolver.getLogicalSolveTrace(board);
    final steps = trace.steps;

    if (steps.isEmpty) {
      return DifficultyResult(
        score: 0,
        level: trace.completed ? 'invalid' : 'unsupported',
        usedTechniques: {},
        stepCount: 0,
        maxTechniqueScore: 0,
      );
    }

    // 统计使用的技巧
    Map<String, int> usedTechniques = {};
    int totalScore = 0;
    int maxTechniqueScore = 0;

    for (var step in steps) {
      String technique = step.technique;
      usedTechniques[technique] = (usedTechniques[technique] ?? 0) + 1;

      int score = techniqueScores[technique] ?? 1;
      totalScore += score;

      if (score > maxTechniqueScore) {
        maxTechniqueScore = score;
      }
    }

    // 根据分数判断难度等级
    String level = trace.completed
        ? _determineLevel(totalScore, usedTechniques)
        : 'unsupported';

    return DifficultyResult(
      score: totalScore,
      level: level,
      usedTechniques: usedTechniques,
      stepCount: steps.length,
      maxTechniqueScore: maxTechniqueScore,
    );
  }

  /// 根据分数和使用的技巧判断难度等级
  static String _determineLevel(int score, Map<String, int> usedTechniques) {
    // 如果使用了回溯（高级技巧），至少是专家级
    if (_hasAnyTechnique(usedTechniques, ['高级技巧'])) {
      return 'expert';
    }

    // 检查是否使用了专家级技巧
    if (_hasAnyTechnique(
        usedTechniques, ['XY-Wing', 'XYZ-Wing', 'Swordfish'])) {
      return 'expert';
    }

    // 检查是否使用了 X-Wing（困难级标志）
    if (_hasAnyTechnique(usedTechniques, ['X-Wing'])) {
      return 'hard';
    }

    // 检查是否使用了中级技巧
    if (_hasAnyTechnique(
      usedTechniques,
      ['数对', '三数组', '四数组', '区块'],
    )) {
      return 'medium';
    }

    // 根据分数和步骤数判断
    if (score >= 300) return 'expert';
    if (score >= 150) return 'hard';
    if (score >= 80) return 'medium';
    return 'easy';
  }

  /// 检查是否使用了任何指定的技巧
  static bool _hasAnyTechnique(
      Map<String, int> usedTechniques, List<String> techniques) {
    for (var technique in techniques) {
      if (usedTechniques.containsKey(technique) &&
          usedTechniques[technique]! > 0) {
        return true;
      }
      // 也检查包含关键字的技巧
      for (var key in usedTechniques.keys) {
        if (key.contains(technique)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 验证题目是否符合指定难度
  static bool validateDifficulty(SudokuBoard board, String targetDifficulty) {
    var result = analyzeDifficulty(board);

    if (targetDifficulty == 'custom') return true;
    if (result.level == 'unsupported' || result.level == 'invalid') {
      return false;
    }

    var level = difficultyLevels[targetDifficulty];
    if (level == null) return false;

    // 检查分数范围
    if (result.score < level.minScore || result.score > level.maxScore) {
      return false;
    }

    // 检查是否使用了要求的技巧
    for (var requiredTech in level.requiredTechniques) {
      if (!_hasAnyTechnique(result.usedTechniques, [requiredTech])) {
        return false;
      }
    }

    // 检查是否使用了禁止的技巧
    for (var forbiddenTech in level.forbiddenTechniques) {
      if (_hasAnyTechnique(result.usedTechniques, [forbiddenTech])) {
        return false;
      }
    }

    return true;
  }

  /// 获取题目的详细报告
  static String getDifficultyReport(DifficultyResult result) {
    StringBuffer sb = StringBuffer();
    sb.writeln('难度评分: ${result.score}');
    sb.writeln('难度等级: ${_getLevelName(result.level)}');
    sb.writeln('总步数: ${result.stepCount}');
    sb.writeln('最高技巧难度: ${result.maxTechniqueScore}');
    sb.writeln('\n使用的技巧:');

    var sortedTechniques = result.usedTechniques.entries.toList()
      ..sort((a, b) =>
          (techniqueScores[b.key] ?? 0).compareTo(techniqueScores[a.key] ?? 0));

    for (var entry in sortedTechniques) {
      int score = techniqueScores[entry.key] ?? 0;
      sb.writeln('  ${entry.key}: ${entry.value} 次 (难度: $score)');
    }

    return sb.toString();
  }

  static String _getLevelName(String level) {
    switch (level) {
      case 'easy':
        return '简单';
      case 'medium':
        return '中等';
      case 'hard':
        return '困难';
      case 'expert':
        return '专家';
      case 'unsupported':
        return '超出当前逻辑技巧';
      default:
        return '未知';
    }
  }
}

/// 难度等级定义
class DifficultyLevel {
  final String name;
  final int minScore;
  final int maxScore;
  final List<String> requiredTechniques;
  final List<String> forbiddenTechniques;

  const DifficultyLevel({
    required this.name,
    required this.minScore,
    required this.maxScore,
    required this.requiredTechniques,
    required this.forbiddenTechniques,
  });
}

/// 难度分析结果
class DifficultyResult {
  final int score;
  final String level;
  final Map<String, int> usedTechniques;
  final int stepCount;
  final int maxTechniqueScore;

  DifficultyResult({
    required this.score,
    required this.level,
    required this.usedTechniques,
    required this.stepCount,
    required this.maxTechniqueScore,
  });
}
