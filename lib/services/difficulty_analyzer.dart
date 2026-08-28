import '../models/puzzle_grade.dart';
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
    '宫内鱼': 68,
    'XY-Wing': 50,
    'XYZ-Wing': 60,
    '唯一矩形 Type 1': 50,
    '不完整唯一矩形': 52,
    '唯一矩形 Type 2': 54,
    '唯一矩形 Type 3': 62,
    '唯一矩形 Type 4': 56,
    '隐性唯一矩形': 58,
    '染色法': 70,
    'W-Wing': 90,
    'WXYZ-Wing': 92,
    '全双值坟墓+1': 54,
    '全双值坟墓 Type 2': 60,
    '全双值坟墓 Type 3': 66,
    '全双值坟墓 Type 4': 62,
    '扩展矩形 Type 1': 60,
    '扩展矩形 Type 2': 62,
    '扩展矩形 Type 4': 63,
    '扩展矩形 Type 3': 65,
    '唯一环 Type 1': 66,
    '唯一环 Type 2': 68,
    '唯一环 Type 4': 70,
    '唯一环 Type 3': 72,
    '探长致命结构': 74,
    '淑芬致命结构': 82,
    '可规避矩形': 55,
    '摩天楼': 32,
    '双线风筝': 36,
    '空矩形': 48,
    'XY-Chain': 91,
    '强弱交替链': 92,
    'Nice Loop / AIC 环': 93,
    '融合式待定数组': 92,
    '区块链': 94,
    '死环': 94,
    '待定唯一矩形': 94,
    'ALS-XZ': 95,
    'DDS': 95,
    '待定扩展矩形': 95,
    '待定唯一环': 95,
    '待定全双值坟墓': 95,
    'ALS-XY-Wing': 98,
    '死亡绽放': 96,
    '弱待定数组': 96,
    'Kraken Fish': 97,
    // 「毛刺为真」那一种情况推到推不动为止，读起来是强制链的力度，不是数组的
    // 认形，所以和 Kraken 同档而排在它后面，不占 9.4。
    '毛刺数组': 97,
    '飞鱼导弹': 97,
    'Nishio': 99,
    '分类强制链': 98,
    '强制唯一矩形': 98,
    '强制扩展矩形': 98,
    '强制唯一环': 98,
    '分类强制网': 99,
    '高级技巧': 100,
  };

  /// 难度等级定义。分级只看路径上最高的那条技巧，不再用总分。
  static final Map<String, DifficultyLevel> difficultyLevels = {
    for (final g in PuzzleGrades.all)
      g.id: DifficultyLevel(
        name: g.title,
        minScore: 0,
        maxScore: 10000,
        requiredTechniques: const [],
        forbiddenTechniques: const [],
      ),
  };

  /// 分析题目难度
  static DifficultyResult analyzeDifficulty(SudokuBoard board) {
    if (SudokuSolver.countSolutions(board, limit: 2) != 1) {
      return DifficultyResult(
        score: 0,
        level: 'invalid',
        usedTechniques: {},
        stepCount: 0,
        maxTechniqueScore: 0,
      );
    }
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

    String level = trace.completed
        ? PuzzleGrades.gradeForTechniques(usedTechniques.keys).name
        : 'unsupported';

    return DifficultyResult(
      score: totalScore,
      level: level,
      usedTechniques: usedTechniques,
      stepCount: steps.length,
      maxTechniqueScore: maxTechniqueScore,
    );
  }

  /// 题目是否正好落在这一档：最高技巧属于该档，且逻辑技巧能解完。
  static bool matchesGrade(DifficultyResult result, String targetDifficulty) {
    if (targetDifficulty == 'custom') return true;
    if (result.level == 'unsupported' || result.level == 'invalid') {
      return false;
    }
    return result.level == targetDifficulty;
  }

  /// 验证题目是否符合指定难度
  static bool validateDifficulty(SudokuBoard board, String targetDifficulty) {
    var result = analyzeDifficulty(board);

    if (targetDifficulty == 'custom') return true;
    if (result.level == 'unsupported' || result.level == 'invalid') {
      return false;
    }

    return matchesGrade(result, targetDifficulty);
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
    if (level == 'unsupported') return '超出当前逻辑技巧';
    if (level == 'invalid') return '无效';
    return PuzzleGrades.titleOf(level);
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
