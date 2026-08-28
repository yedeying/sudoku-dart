import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/services/current_game_store.dart';

const _classic =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('自定义盘只缓存当前这一题，不进题库', () async {
    final game = GameState()..loadCustomGame(_classic);
    game.selectCell(0, 2);
    game.placeNumber(4);
    await game.persistForTest();

    expect(game.puzzleId, 'custom');
    expect(game.hasResumableGame, isTrue);

    final data = await CurrentGameStore.read();
    expect(data, isNotNull);
    expect(data!['id'], 'custom');
    expect(data['difficulty'], 'custom');
    expect((data['board'] as String)[2], '4');

    final restored = GameState();
    await restored.restoreCurrent();
    expect(restored.hasResumableGame, isTrue);
    expect(restored.board!.get(0, 2), 4);
    expect(restored.puzzleId, 'custom');
  });

  test('做完后清掉当前缓存', () async {
    final game = GameState()..loadCustomGame(_classic);
    await game.persistForTest();
    expect(await CurrentGameStore.read(), isNotNull);

    game.consumeCompletionFlag();
    await CurrentGameStore.clear();
    final empty = GameState();
    await empty.restoreCurrent();
    expect(empty.hasResumableGame, isFalse);
  });
}
