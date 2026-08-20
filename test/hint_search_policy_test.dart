import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/game_state.dart';

void main() {
  test('用户路径把回溯填数当成未找到', () {
    // 空盘几乎只会走到暴力或无解；自定义几乎完成的盘用 getHint
    final state = GameState();
    state.loadCustomGame(
      '530070000'
      '600195000'
      '098000060'
      '800060003'
      '400803001'
      '700020006'
      '060000280'
      '000419005'
      '000080079',
    );
    final hint = state.getHint();
    expect(hint, isNotNull);
    expect(hint!.technique, isNot(equals('高级技巧')));
  });

  test('getHint 不修改已填数字', () {
    final state = GameState();
    const puzzle =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    state.loadCustomGame(puzzle);
    final before = state.board!.toStringRepresentation();
    state.getHint();
    expect(state.board!.toStringRepresentation(), before);
  });
}
