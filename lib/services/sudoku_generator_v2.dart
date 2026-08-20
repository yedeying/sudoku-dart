import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sudoku_board.dart';
import 'sudoku_solver.dart';
import 'difficulty_analyzer.dart';

/// 改进的数独题目生成器
/// 使用基于技巧的难度评估系统
class SudokuGeneratorV2 {
  static final Random _random = Random();

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// 生成指定难度的数独题目
  /// difficulty: 'easy', 'medium', 'hard', 'expert'
  /// maxAttempts: 最大尝试次数
  static SudokuBoard generate(String difficulty, {int maxAttempts = 50}) {
    _log('开始生成 $difficulty 难度的题目...');
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      _log('尝试 $attempt/$maxAttempts...');
      
      // 1. 生成完整的已解决的数独
      var completed = _generateCompleted();
      
      // 2. 根据难度逐步移除数字
      var puzzle = _removeNumbersWithDifficulty(completed, difficulty);
      
      if (puzzle != null) {
        puzzle.refreshCandidates();
        // 3. 验证难度
        var result = DifficultyAnalyzer.analyzeDifficulty(puzzle);
        _log('生成的题目难度: ${result.level}, 分数: ${result.score}');
        _log(DifficultyAnalyzer.getDifficultyReport(result));
        
        if (DifficultyAnalyzer.validateDifficulty(puzzle, difficulty)) {
          _log('✓ 成功生成符合要求的题目！');
          return puzzle;
        } else {
          _log('✗ 难度不符合要求，重新生成...');
        }
      }
    }

    // 如果生成失败，返回预设题目
    _log('生成失败，使用预设题目');
    return _getFallbackPuzzle(difficulty);
  }

  /// 生成一个完整的已解决的数独
  static SudokuBoard _generateCompleted() {
    List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));

    // 先填充对角线的三个3x3宫格
    for (int box = 0; box < 9; box += 3) {
      _fillBox(board, box, box);
    }

    // 使用回溯法填充剩余格子
    _fillRemaining(board, 0, 3);

    return SudokuBoard(
      board: board,
      initial: board.map((row) => List<int>.from(row)).toList(),
    );
  }

  /// 填充一个 3x3 宫格
  static void _fillBox(List<List<int>> board, int row, int col) {
    List<int> nums = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    nums.shuffle(_random);

    int index = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        board[row + i][col + j] = nums[index++];
      }
    }
  }

  /// 使用回溯法填充剩余格子
  static bool _fillRemaining(List<List<int>> board, int row, int col) {
    if (col >= 9) {
      row++;
      col = 0;
    }
    if (row >= 9) return true;

    if (board[row][col] != 0) {
      return _fillRemaining(board, row, col + 1);
    }

    List<int> nums = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    nums.shuffle(_random);

    for (int num in nums) {
      if (_isSafe(board, row, col, num)) {
        board[row][col] = num;
        if (_fillRemaining(board, row, col + 1)) {
          return true;
        }
        board[row][col] = 0;
      }
    }

    return false;
  }

  /// 检查在指定位置放置数字是否安全
  static bool _isSafe(List<List<int>> board, int row, int col, int num) {
    // 检查行
    for (int j = 0; j < 9; j++) {
      if (board[row][j] == num) return false;
    }

    // 检查列
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return false;
    }

    // 检查宫格
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (board[i][j] == num) return false;
      }
    }

    return true;
  }

  /// 根据难度智能移除数字
  static SudokuBoard? _removeNumbersWithDifficulty(
      SudokuBoard completed, String difficulty) {
    var puzzle = completed.copy();
    
    // 根据难度设置初始移除数量和策略
    int minRemove, maxRemove;
    switch (difficulty) {
      case 'easy':
        minRemove = 35;
        maxRemove = 45;
        break;
      case 'medium':
        minRemove = 45;
        maxRemove = 52;
        break;
      case 'hard':
        minRemove = 50;
        maxRemove = 58;
        break;
      case 'expert':
        minRemove = 52;
        maxRemove = 60;
        break;
      default:
        minRemove = 40;
        maxRemove = 50;
    }

    int targetRemove = minRemove + _random.nextInt(maxRemove - minRemove + 1);
    
    // 收集所有位置
    List<List<int>> positions = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        positions.add([i, j]);
      }
    }

    // 随机打乱
    positions.shuffle(_random);

    int removed = 0;
    List<List<int>> removedPositions = [];

    // 第一阶段：快速移除到目标数量
    for (var pos in positions) {
      if (removed >= targetRemove) break;

      int row = pos[0];
      int col = pos[1];
      int backup = puzzle.board[row][col];

      puzzle.board[row][col] = 0;
      puzzle.initial[row][col] = 0;

      // 检查是否仍有唯一解
      if (SudokuSolver.hasUniqueSolution(puzzle)) {
        removed++;
        removedPositions.add([row, col, backup]);
      } else {
        // 恢复
        puzzle.board[row][col] = backup;
        puzzle.initial[row][col] = backup;
      }
    }

    // 第二阶段：微调难度（对于困难和专家级）
    if (difficulty == 'hard' || difficulty == 'expert') {
      // 尝试额外移除一些关键位置的数字
      puzzle = _refineForDifficulty(puzzle, removedPositions, difficulty);
    }

    puzzle.refreshCandidates();
    return puzzle;
  }

  /// 针对困难和专家级题目进行微调
  static SudokuBoard _refineForDifficulty(
      SudokuBoard puzzle, List<List<int>> removedPositions, String difficulty) {
    // 尝试移除更多数字，使题目需要使用高级技巧
    var testPuzzle = puzzle.copy();
    
    // 优先移除对称位置的数字（通常会增加难度）
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (testPuzzle.board[i][j] != 0) {
          int symRow = 8 - i;
          int symCol = 8 - j;
          
          if (testPuzzle.board[symRow][symCol] != 0) {
            int backup1 = testPuzzle.board[i][j];
            int backup2 = testPuzzle.board[symRow][symCol];
            
            testPuzzle.board[i][j] = 0;
            testPuzzle.initial[i][j] = 0;
            testPuzzle.board[symRow][symCol] = 0;
            testPuzzle.initial[symRow][symCol] = 0;
            
            // 检查唯一解和难度
            if (SudokuSolver.hasUniqueSolution(testPuzzle)) {
              testPuzzle.refreshCandidates();
              var result = DifficultyAnalyzer.analyzeDifficulty(testPuzzle);
              if (result.level == difficulty) {
                // 找到合适的配置
                return testPuzzle;
              }
            }
            
            // 恢复
            testPuzzle.board[i][j] = backup1;
            testPuzzle.initial[i][j] = backup1;
            testPuzzle.board[symRow][symCol] = backup2;
            testPuzzle.initial[symRow][symCol] = backup2;
          }
        }
      }
    }
    
    return puzzle;
  }

  /// 获取后备题目（预设的高质量题目）
  static SudokuBoard _getFallbackPuzzle(String difficulty) {
    String puzzle;
    switch (difficulty) {
      case 'easy':
        // 只需要 Naked Single 和 Hidden Single
        puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
        break;
      case 'medium':
        // 需要 Naked Pair 和 Pointing Pair
        puzzle = '003020600900305001001806400008102900700000008006708200002609500800203009005010300';
        break;
      case 'hard':
        // 需要 X-Wing
        puzzle = '000000907000420180000705026100904000050000040000507009920108000034059000507000000';
        break;
      case 'expert':
        // 需要 XY-Wing 或更高级技巧
        puzzle = '800000000003600000070090200050007000000045700000100030001000068008500010090000400';
        break;
      default:
        puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    }
    return SudokuBoard.fromString(puzzle);
  }

  /// 批量生成题目（用于构建题库）
  static List<SudokuBoard> generateBatch(String difficulty, int count) {
    List<SudokuBoard> puzzles = [];
    
    _log('开始批量生成 $count 个 $difficulty 难度的题目...');
    
    for (int i = 0; i < count; i++) {
      _log('\n生成第 ${i + 1}/$count 个题目');
      var puzzle = generate(difficulty, maxAttempts: 30);
      puzzles.add(puzzle);
    }
    
    _log('\n✓ 批量生成完成！');
    return puzzles;
  }

  /// 从字符串列表中选择一个随机题目
  static SudokuBoard getRandomFromPreset(String difficulty) {
    var presets = _getPresetPuzzles(difficulty);
    return SudokuBoard.fromString(presets[_random.nextInt(presets.length)]);
  }

  /// 预设的高质量题库
  static List<String> _getPresetPuzzles(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return [
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
          '020608000580009700000040000370000500600000004008000013000030000009800036000507010',
          '100489006730000040000001295007120600500703008006095700914600000020000037800512004',
        ];
      case 'medium':
        return [
          '003020600900305001001806400008102900700000008006708200002609500800203009005010300',
          '200080300060070084030500209000105408000000000402706000301007040720040060004010003',
          '000075400000000008080190000300001060000000034000068170204000603900000020530200000',
        ];
      case 'hard':
        return [
          '000000907000420180000705026100904000050000040000507009920108000034059000507000000',
          '030000000000195000008000060800060003400803001700020006060000280000419005000080079',
          '000000000904607000076804100309701080008000300050308702007503600000000000200000003',
        ];
      case 'expert':
        return [
          '800000000003600000070090200050007000000045700000100030001000068008500010090000400',
          '000000000000003085001020000000507000004000100090000000500000073002010000000040009',
          '020000000000600003074080000000003002080040010600500000000010780500009000000000040',
        ];
      default:
        return [
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        ];
    }
  }
}
