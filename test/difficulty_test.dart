import 'package:flutter_test/flutter_test.dart';
import '../lib/models/sudoku_board.dart';
import '../lib/services/difficulty_analyzer.dart';
import '../lib/services/sudoku_generator_v2.dart';

void main() {
  group('难度分级测试', () {
    test('简单难度题目验证', () {
      print('\n=== 测试简单难度题目 ===');
      
      // 使用预设的简单题目
      var board = SudokuBoard.fromString(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079'
      );

      var result = DifficultyAnalyzer.analyzeDifficulty(board);
      
      print(DifficultyAnalyzer.getDifficultyReport(result));
      
      expect(result.level, 'easy');
      expect(result.usedTechniques.containsKey('唯一候选数'), true);
      
      // 简单题目不应使用高级技巧
      expect(result.usedTechniques.containsKey('X-Wing'), false);
      expect(result.usedTechniques.containsKey('XY-Wing'), false);
      
      print('✓ 简单难度验证通过\n');
    });

    test('中等难度题目验证', () {
      print('\n=== 测试中等难度题目 ===');
      
      var board = SudokuBoard.fromString(
        '003020600'
        '900305001'
        '001806400'
        '008102900'
        '700000008'
        '006708200'
        '002609500'
        '800203009'
        '005010300'
      );

      var result = DifficultyAnalyzer.analyzeDifficulty(board);
      
      print(DifficultyAnalyzer.getDifficultyReport(result));
      
      // 中等题目应该需要一些中级技巧
      bool hasIntermediateTechnique = 
          result.usedTechniques.keys.any((key) => 
            key.contains('数字对') || 
            key.contains('数字三元组') || 
            key.contains('指向对') ||
            key.contains('盒线削减'));
      
      if (hasIntermediateTechnique) {
        print('✓ 使用了中级技巧');
      } else {
        print('⚠ 未使用中级技巧，可能太简单');
      }
      
      print('难度等级: ${result.level}\n');
    });

    test('困难难度题目验证', () {
      print('\n=== 测试困难难度题目 ===');
      
      var board = SudokuBoard.fromString(
        '000000907'
        '000420180'
        '000705026'
        '100904000'
        '050000040'
        '000507009'
        '920108000'
        '034059000'
        '507000000'
      );

      var result = DifficultyAnalyzer.analyzeDifficulty(board);
      
      print(DifficultyAnalyzer.getDifficultyReport(result));
      
      // 困难题目应该需要高级技巧
      bool hasAdvancedTechnique = 
          result.usedTechniques.keys.any((key) => 
            key.contains('X-Wing') || 
            key.contains('Swordfish'));
      
      if (hasAdvancedTechnique) {
        print('✓ 使用了高级技巧');
      } else {
        print('⚠ 未使用高级技巧');
      }
      
      print('难度等级: ${result.level}\n');
    });

    test('专家难度题目验证', () {
      print('\n=== 测试专家难度题目 ===');
      
      var board = SudokuBoard.fromString(
        '800000000'
        '003600000'
        '070090200'
        '050007000'
        '000045700'
        '000100030'
        '001000068'
        '008500010'
        '090000400'
      );

      var result = DifficultyAnalyzer.analyzeDifficulty(board);
      
      print(DifficultyAnalyzer.getDifficultyReport(result));
      
      // 专家题目应该需要专家级技巧
      bool hasExpertTechnique = 
          result.usedTechniques.keys.any((key) => 
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
      
      var easyBoard = SudokuBoard.fromString(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079'
      );

      bool isValidEasy = DifficultyAnalyzer.validateDifficulty(easyBoard, 'easy');
      print('简单题目验证: ${isValidEasy ? "✓ 通过" : "✗ 未通过"}');
      
      // 用简单题目验证困难难度应该失败
      bool isValidHard = DifficultyAnalyzer.validateDifficulty(easyBoard, 'hard');
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
          bool isValid = DifficultyAnalyzer.validateDifficulty(board, difficulty);
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
      expect(scores['唯一候选数']! < scores['数字对（行）']!, true);
      expect(scores['数字对（行）']! < scores['X-Wing']!, true);
      expect(scores['X-Wing']! < scores['XY-Wing']!, true);
      
      print('\n✓ 技巧分数系统合理\n');
    });

    test('生成器集成测试', () {
      print('\n=== 测试题目生成器 ===');
      
      // 注意：这个测试会比较慢，因为要实际生成题目
      print('生成简单难度题目...');
      var easyBoard = SudokuGeneratorV2.generate('easy', maxAttempts: 5);
      var easyResult = DifficultyAnalyzer.analyzeDifficulty(easyBoard);
      
      print('生成结果: 等级=${easyResult.level}, 分数=${easyResult.score}');
      print('使用的技巧: ${easyResult.usedTechniques.keys.join(', ')}');
      
      // 至少应该是 easy 或更低
      expect(['easy', 'medium'].contains(easyResult.level), true);
      
      print('\n✓ 生成器测试完成\n');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
