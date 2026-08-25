import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';

void main() {
  group('候选数功能测试', () {
    test('用户候选数基础操作', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      // 测试设置用户候选数
      board.setUserCandidates(0, 2, {1, 2, 4});
      expect(board.getUserCandidates(0, 2), {1, 2, 4});

      // 测试切换候选数
      board.toggleUserCandidate(0, 2, 5);
      expect(board.getUserCandidates(0, 2), {1, 2, 4, 5});

      board.toggleUserCandidate(0, 2, 2);
      expect(board.getUserCandidates(0, 2), {1, 4, 5});

      // 测试清除候选数
      board.clearUserCandidates(0, 2);
      expect(board.getUserCandidates(0, 2).isEmpty, true);

      print('✓ 用户候选数基础操作测试通过');
    });

    test('自动填充候选数', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      // 自动填充所有候选数
      board.fillAllCandidates();

      // 验证某个格子的候选数
      var cands = board.getUserCandidates(0, 2);
      print('格子 (0, 2) 的自动候选数: ${cands.toList()..sort()}');
      expect(cands.isNotEmpty, true);

      // 验证系统计算的候选数与用户候选数一致
      expect(cands, board.getCandidates(0, 2));

      print('✓ 自动填充候选数测试通过');
    });

    test('候选数在填入数字后清除', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      // 设置候选数
      board.setUserCandidates(0, 2, {1, 2, 4});
      expect(board.getUserCandidates(0, 2).length, 3);

      // 填入数字
      board.set(0, 2, 4);

      // 用户候选数应该不受影响（需要手动清除）
      // 但获取候选数应该返回空
      expect(board.getUserCandidates(0, 2).isEmpty, true);

      print('✓ 候选数清除测试通过');
    });

    test('笔记模式打开时自动显示候选', () {
      final gameState = GameState();
      expect(gameState.showCandidates, false);
      gameState.toggleCandidateMode();
      expect(gameState.candidateMode, true);
      expect(gameState.showCandidates, true);
    });

    test('候选色和链标记打开时自动显示候选', () {
      final gameState = GameState();
      expect(gameState.showCandidates, false);
      gameState.setMarkupMode(MarkupMode.candidateColor);
      expect(gameState.showCandidates, true);

      gameState.toggleShowCandidates();
      expect(gameState.showCandidates, false);
      gameState.setMarkupMode(MarkupMode.strong);
      expect(gameState.showCandidates, true);
    });

    test('格色标记不自动打开候选', () {
      final gameState = GameState();
      gameState.setMarkupMode(MarkupMode.cellColor);
      expect(gameState.showCandidates, false);
    });

    test('笔记模式下改候选会重新显示候选', () {
      final gameState = GameState()
        ..loadCustomGame(
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        )
        ..selectCell(0, 2)
        ..toggleCandidateMode();
      gameState.toggleShowCandidates();
      expect(gameState.showCandidates, false);
      gameState.placeNumber(2);
      expect(gameState.showCandidates, true);
    });

    test('用到候选的提示会自动显示候选', () {
      final gameState = GameState()
        ..loadCustomGame(
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        );
      expect(gameState.showCandidates, false);
      final hint = gameState.getHint();
      expect(hint, isNotNull);
      expect(hint!.patternCandidates, isNotEmpty);
      expect(gameState.showCandidates, true);
    });

    test('GameState 候选数模式切换', () {
      var gameState = GameState();

      // 初始状态
      expect(gameState.showCandidates, false);
      expect(gameState.candidateMode, false);

      // 切换显示候选数
      gameState.toggleShowCandidates();
      expect(gameState.showCandidates, true);

      // 切换候选数编辑模式
      gameState.toggleCandidateMode();
      expect(gameState.candidateMode, true);

      // 再次切换
      gameState.toggleCandidateMode();
      expect(gameState.candidateMode, false);

      print('✓ GameState 候选数模式切换测试通过');
    });

    test('候选数模式下填入数字', () {
      var gameState = GameState();
      gameState.loadCustomGame(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );

      // 选择一个空格
      gameState.selectCell(0, 2);

      // 进入候选数模式
      gameState.toggleCandidateMode();

      // 笔记直接改可见候选：点已有的自动候选是划掉它
      expect(gameState.board!.visibleCandidates(0, 2), {1, 2, 4});
      gameState.placeNumber(2);
      expect(gameState.board!.visibleCandidates(0, 2), {1, 4});

      // 点没有的数字是写上去
      gameState.placeNumber(3);
      var cands = gameState.board!.visibleCandidates(0, 2);
      print('候选数模式填入的数字: ${cands.toList()..sort()}');
      expect(cands, {1, 3, 4});

      // 再次点击应该移除
      gameState.placeNumber(3);
      expect(gameState.board!.visibleCandidates(0, 2).contains(3), false);
      expect(gameState.board!.visibleCandidates(0, 2).length, 2);

      print('✓ 候选数模式填入数字测试通过');
    });

    test('普通模式下填入数字', () {
      var gameState = GameState();
      gameState.loadCustomGame(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );

      // 选择一个空格
      gameState.selectCell(0, 2);

      // 先设置一些候选数
      gameState.board!.setUserCandidates(0, 2, {1, 2, 4});

      // 不进入候选数模式，直接填数
      expect(gameState.candidateMode, false);
      gameState.placeNumber(4);

      // 应该填入数字而不是候选数
      expect(gameState.board!.get(0, 2), 4);

      // 用户候选数应该被清除
      expect(gameState.board!.getUserCandidates(0, 2).isEmpty, true);

      print('✓ 普通模式填入数字测试通过');
    });

    test('自动填充候选数功能', () {
      var gameState = GameState();
      gameState.loadCustomGame(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );

      // 自动填充
      gameState.autoFillCandidates();

      // 检查是否自动开启了显示候选数
      expect(gameState.showCandidates, true);

      // 检查是否填充了候选数
      int cellsWithCandidates = 0;
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (gameState.board!.get(i, j) == 0) {
            var cands = gameState.board!.getUserCandidates(i, j);
            if (cands.isNotEmpty) {
              cellsWithCandidates++;
            }
          }
        }
      }

      print('有候选数的空格数量: $cellsWithCandidates');
      expect(cellsWithCandidates, greaterThan(0));

      print('✓ 自动填充候选数功能测试通过');
    });

    test('清除所有候选数', () {
      var gameState = GameState();
      gameState.loadCustomGame(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );

      // 先自动填充
      gameState.autoFillCandidates();

      // 验证有候选数
      var hasCandidates = false;
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (gameState.board!.getUserCandidates(i, j).isNotEmpty) {
            hasCandidates = true;
            break;
          }
        }
        if (hasCandidates) break;
      }
      expect(hasCandidates, true);

      // 清除所有候选数
      gameState.clearAllCandidates();

      // 验证候选数被清除
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          expect(gameState.board!.getUserCandidates(i, j).isEmpty, true);
        }
      }

      print('✓ 清除所有候选数测试通过');
    });

    test('Board 深拷贝包含用户候选数', () {
      var board = SudokuBoard.fromString('530070000'
          '600195000'
          '098000060'
          '800060003'
          '400803001'
          '700020006'
          '060000280'
          '000419005'
          '000080079');

      // 设置一些用户候选数
      board.setUserCandidates(0, 2, {1, 2, 4});
      board.setUserCandidates(1, 1, {2, 4, 7});

      // 深拷贝
      var copiedBoard = board.copy();

      // 验证用户候选数被复制
      expect(copiedBoard.getUserCandidates(0, 2), {1, 2, 4});
      expect(copiedBoard.getUserCandidates(1, 1), {2, 4, 7});

      // 修改原始board的候选数不应影响拷贝
      board.toggleUserCandidate(0, 2, 5);
      expect(board.getUserCandidates(0, 2), {1, 2, 4, 5});
      expect(copiedBoard.getUserCandidates(0, 2), {1, 2, 4});

      print('✓ Board 深拷贝测试通过');
    });
  });
}
