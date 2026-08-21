import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void main() {
  group('数独高级技巧测试', () {
    test('基础技巧：Naked Single', () {
      // 创建一个简单的数独，只有一个格子只有唯一候选
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      var hint = SudokuSolver.getHint(board);
      expect(hint, isNotNull);
      print('技巧: ${hint?.technique}');
      print('位置: (${hint?.row}, ${hint?.col}) = ${hint?.value}');
      print('说明: ${hint?.explanation}');
    });

    test('基础技巧：Hidden Single', () {
      var board = SudokuBoard.fromString('003020600'
          '900305001'
          '001806400'
          '008102900'
          '700000008'
          '006708200'
          '002609500'
          '800203009'
          '005010300');

      var hint = SudokuSolver.getHint(board);
      expect(hint, isNotNull);
      print('\n技巧: ${hint?.technique}');
      print('位置: (${hint?.row}, ${hint?.col}) = ${hint?.value}');
      print('说明: ${hint?.explanation}');
    });

    test('显性数对：Naked Pair', () {
      // 这个数独包含 Naked Pair 模式
      var board = SudokuBoard.fromString('000000000'
          '000000000'
          '000000000'
          '123456789'
          '456789123'
          '789123456'
          '234000000'
          '000000000'
          '000000000');

      var hint = SudokuSolver.getHint(board);
      print('\n技巧: ${hint?.technique}');
      if (hint != null) {
        print('位置: (${hint.row}, ${hint.col}) = ${hint.value}');
        print('说明: ${hint.explanation}');
      }
    });

    test('完整解题流程', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      print('\n开始数独:');
      print(board.toPrettyString());

      int stepCount = 0;
      while (!board.isComplete() && stepCount < 200) {
        var hint = SudokuSolver.getHint(board);
        if (hint == null) break;

        stepCount++;
        print('\n第 $stepCount 步:');
        print('技巧: ${hint.technique}');
        print('说明: ${hint.explanation}');

        if (hint.isElimination) {
          for (final e in hint.eliminations) {
            board.eliminateCandidate(e.row, e.col, e.num);
          }
        } else {
          board.set(hint.row, hint.col, hint.value);
        }
      }

      print('\n进行了 $stepCount 步');
      print('最终状态:');
      print(board.toPrettyString());
      expect(board.isComplete(), isTrue);
    });

    test('技巧难度分级', () {
      var techniques = [
        '唯余法',
        '摒除',
        '数对',
        '数字三元组',
        '宫区块',
        '区块',
        'X-Wing',
        'Swordfish',
        'XY-Wing',
        'XYZ-Wing',
      ];

      print('\n支持的技巧（按难度排序）:');
      for (int i = 0; i < techniques.length; i++) {
        print('${i + 1}. ${techniques[i]}');
      }
    });

    test('测试候选数字计算', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      // 测试第一个空格的候选数字
      var candidates = board.getCandidates(0, 2);
      print('\n格子 (1, 3) 的候选数字: ${candidates.toList()..sort()}');
      expect(candidates.isNotEmpty, true);

      // 打印前几行的候选数字
      print('\n前3行的候选数字:');
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 9; col++) {
          if (board.get(row, col) == 0) {
            var cands = board.getCandidates(row, col);
            print('($row, $col): ${cands.toList()..sort()}');
          }
        }
      }
    });

    test('验证所有技巧都被正确集成', () {
      // 创建一个测试棋盘，逐步应用提示直到完成或没有更多提示
      var board = SudokuBoard.fromString('003020600'
          '900305001'
          '001806400'
          '008102900'
          '700000008'
          '006708200'
          '002609500'
          '800203009'
          '005010300');

      Set<String> usedTechniques = {};
      int maxSteps = 100;
      int step = 0;

      while (!board.isComplete() && step < maxSteps) {
        var hint = SudokuSolver.getHint(board);
        if (hint == null) break;

        usedTechniques.add(hint.technique);
        board.set(hint.row, hint.col, hint.value);
        step++;
      }

      print('\n本次解题使用的技巧:');
      for (var technique in usedTechniques) {
        print('- $technique');
      }
      print('总步数: $step');
      print('是否完成: ${board.isComplete()}');

      expect(step, greaterThan(0));
    });
  });
}
