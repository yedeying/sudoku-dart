import '../models/sudoku_board.dart';
import 'sudoku_solver.dart';

/// 数独难度分析器
/// 根据解题所需的技巧来评估题目难度
class DifficultyAnalyzer {
  /// 技巧难度分数
  static const Map<String, int> techniqueScores = {
    '唯余法': 1,
    '行摒除': 2,
    '列摒除': 2,
    '宫摒除': 2,
    '显性数对（行）': 5,
    '显性数对（列）': 5,
    '显性数对（宫）': 5,
    '隐性数对（行）': 15,
    '隐性数对（列）': 15,
    '隐性数对（宫）': 15,
    '显性三数组（行）': 10,
    '显性三数组（列）': 10,
    '显性三数组（宫）': 10,
    '隐性三数组（行）': 20,
    '隐性三数组（列）': 20,
    '隐性三数组（宫）': 20,
    '显性四数组（行）': 25,
    '显性四数组（列）': 25,
    '显性四数组（宫）': 25,
    '隐性四数组（行）': 30,
    '隐性四数组（列）': 30,
    '隐性四数组（宫）': 30,
    '宫区块（行）': 15,
    '宫区块（列）': 15,
    '行区块': 15,
    '列区块': 15,
    'X-Wing': 25,
    'Swordfish': 40,
    'Jellyfish': 50, // 新增
    'XY-Wing': 50,
    'XYZ-Wing': 60,
    'Unique Rectangle Type 1': 80, // 新增
    'Unique Rectangle Type 2': 82,
    'Unique Rectangle Type 3': 84,
    'Unique Rectangle Type 4': 86,
    'Simple Coloring': 70, // 新增
    'W-Wing': 90, // 新增
    'Skyscraper': 75, // 新增
    '2-String Kite': 75, // 新增
    'Empty Rectangle': 85, // 新增
    '高级技巧': 100, // 需要回溯的情况
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
