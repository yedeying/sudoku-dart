import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_generator_v2.dart';

void main() {
  group('难度分级测试', () {
    test('逻辑技巧未解完的题目不会被误判为可接受难度', () {
      final board = SudokuBoard.fromString(
        '020608000'
        '580009700'
        '000040000'
        '370000500'
        '600000004'
        '008000013'
        '000030000'
        '009800036'
        '000507010',
      );

      final result = DifficultyAnalyzer.analyzeDifficulty(board);

      expect(result.level, 'unsupported');
      expect(DifficultyAnalyzer.validateDifficulty(board, 'medium'), isFalse);
      expect(DifficultyAnalyzer.validateDifficulty(board, 'expert'), isFalse);
    });

    test('四数组使用独立难度分值', () {
      expect(DifficultyAnalyzer.techniqueScores['显性四数组'], 25);
      expect(DifficultyAnalyzer.techniqueScores['隐性四数组'], 30);
    });

    test('简单难度题目验证', () {
      print('\n=== 测试简单难度题目 ===');

      // 使用预设的简单题目
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      var result = DifficultyAnalyzer.analyzeDifficulty(board);

      print(DifficultyAnalyzer.getDifficultyReport(result));

      expect(result.level, 'easy');
      expect(result.usedTechniques.containsKey('唯余法'), true);

      // 简单题目不应使用高级技巧
      expect(result.usedTechniques.containsKey('X-Wing'), false);
      expect(result.usedTechniques.containsKey('XY-Wing'), false);

      print('✓ 简单难度验证通过\n');
    });

    test('中等难度题目验证', () {
      print('\n=== 测试中等难度题目 ===');

      var board = SudokuBoard.fromString('003020600'
          '900305001'
          '001806400'
          '008102900'
          '700000008'
          '006708200'
          '002609500'
          '800203009'
          '005010300');

      var result = DifficultyAnalyzer.analyzeDifficulty(board);

      print(DifficultyAnalyzer.getDifficultyReport(result));

      // 中等题目应该需要一些中级技巧
      bool hasIntermediateTechnique = result.usedTechniques.keys.any((key) =>
          key.contains('数对') || key.contains('数字三元组') || key.contains('区块'));

      if (hasIntermediateTechnique) {
        print('✓ 使用了中级技巧');
      } else {
        print('⚠ 未使用中级技巧，可能太简单');
      }

      print('难度等级: ${result.level}\n');
    });

    test('困难难度题目验证', () {
      print('\n=== 测试困难难度题目 ===');

      var board = SudokuBoard.fromString('000000907'
          '000420180'
          '000705026'
          '100904000'
          '050000040'
          '000507009'
          '920108000'
          '034059000'
          '507000000');

      var result = DifficultyAnalyzer.analyzeDifficulty(board);

      print(DifficultyAnalyzer.getDifficultyReport(result));

      // 困难题目应该需要高级技巧
      bool hasAdvancedTechnique = result.usedTechniques.keys
          .any((key) => key.contains('X-Wing') || key.contains('Swordfish'));

      if (hasAdvancedTechnique) {
        print('✓ 使用了高级技巧');
      } else {
        print('⚠ 未使用高级技巧');
      }

      print('难度等级: ${result.level}\n');
    });

    test('专家难度题目验证', () {
      print('\n=== 测试专家难度题目 ===');

      var board = SudokuBoard.fromString('800000000'
          '003600000'
          '070090200'
          '050007000'
          '000045700'
          '000100030'
          '001000068'
          '008500010'
          '090000400');

      var result = DifficultyAnalyzer.analyzeDifficulty(board);

      print(DifficultyAnalyzer.getDifficultyReport(result));

      // 专家题目应该需要专家级技巧
      bool hasExpertTechnique = result.usedTechniques.keys.any((key) =>
          key.contains('XY-Wing') ||
          key.contains('XYZ-Wing') ||
          key.contains('Swordfish'));

      if (hasExpertTechnique) {
        print('✓ 使用了专家级技巧');
      } else {
        print('⚠ 未使用专家级技巧');
      }

      print('难度等级: ${result.level}\n');
    });

    test('难度验证功能测试', () {
      print('\n=== 测试难度验证功能 ===');

      var easyBoard = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      bool isValidEasy =
          DifficultyAnalyzer.validateDifficulty(easyBoard, 'easy');
      print('简单题目验证: ${isValidEasy ? "✓ 通过" : "✗ 未通过"}');

      // 用简单题目验证困难难度应该失败
      bool isValidHard =
          DifficultyAnalyzer.validateDifficulty(easyBoard, 'hard');
      print('简单题目验证为困难: ${!isValidHard ? "✓ 正确拒绝" : "✗ 错误通过"}');

      expect(isValidEasy, true);
      expect(isValidHard, false);

      print('✓ 难度验证功能正常\n');
    });

    test('批量测试预设题库', () {
      print('\n=== 批量测试预设题库 ===');

      var difficulties = ['easy', 'medium', 'hard', 'expert'];

      for (var difficulty in difficulties) {
        print('\n--- 测试 $difficulty 难度 ---');

        // 获取3个预设题目
        for (int i = 0; i < 3; i++) {
          var board = SudokuGeneratorV2.getRandomFromPreset(difficulty);
          var result = DifficultyAnalyzer.analyzeDifficulty(board);

          print('题目 ${i + 1}: 等级=${result.level}, 分数=${result.score}');

          // 验证难度
          bool isValid =
              DifficultyAnalyzer.validateDifficulty(board, difficulty);
          if (!isValid) {
            print('  ⚠ 警告: 难度不匹配！实际等级=${result.level}');
          }
        }
      }

      print('\n✓ 批量测试完成\n');
    });

    test('技巧分数系统测试', () {
      print('\n=== 测试技巧分数系统 ===');

      var scores = DifficultyAnalyzer.techniqueScores;

      print('技巧难度分数表:');
      var sortedScores = scores.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (var entry in sortedScores) {
        print('  ${entry.key.padRight(20)}: ${entry.value}');
      }

      // 验证分数递增逻辑
      expect(scores['唯余法']! < scores['显性数对']!, true);
      expect(scores['显性数对']! < scores['X-Wing']!, true);
      expect(scores['X-Wing']! < scores['XY-Wing']!, true);

      print('\n✓ 技巧分数系统合理\n');
    });
  });
}
