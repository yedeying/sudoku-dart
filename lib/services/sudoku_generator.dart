import '../models/sudoku_board.dart';
import 'sudoku_generator_v2.dart';

/// 数独题目生成器
/// 已升级为使用基于技巧的难度评估系统
class SudokuGenerator {
  /// 生成指定难度的数独题目
  /// difficulty: 'easy' (简单), 'medium' (中等), 'hard' (困难), 'expert' (专家)
  static SudokuBoard generate(String difficulty) {
    // 使用新的V2生成器，支持基于技巧的难度评估
    return SudokuGeneratorV2.generate(difficulty, maxAttempts: 20);
  }

  /// 生成预设的示例题目（用于快速测试）
  static SudokuBoard generateExample(String difficulty) {
    // 使用预设的高质量题库，随机选择一个
    return SudokuGeneratorV2.getRandomFromPreset(difficulty);
  }

  /// 生成指定数量的空格的题目（用于自定义难度）
  static SudokuBoard generateWithEmptyCells(int emptyCells) {
    if (emptyCells < 20 || emptyCells > 64) {
      throw ArgumentError('空格数量应在 20-64 之间');
    }

    // 根据空格数量粗略判断难度
    String difficulty;
    if (emptyCells <= 40) {
      difficulty = 'easy';
    } else if (emptyCells <= 50) {
      difficulty = 'medium';
    } else if (emptyCells <= 55) {
      difficulty = 'hard';
    } else {
      difficulty = 'expert';
    }

    return generate(difficulty);
  }
}
