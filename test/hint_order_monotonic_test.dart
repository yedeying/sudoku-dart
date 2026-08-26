import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 提示顺序里允许「后一项分数反而更低」的位置。
///
/// 空的才对。`getHint` 从头往后试，先命中的就报出去，所以顺序本身就是
/// 「下手难度从浅到深」的承诺；某一项排在比自己分低的项前面，就等于
/// 用一个更难的技巧抢在更浅的技巧前面报，玩家看到的提示会莫名其妙地跳档。
/// 真要破例，必须在这里连理由一起写下来，让破例是显式的。
const Map<String, String> _allowedInversions = {};

void main() {
  test('提示顺序里的难度分单调不降', () {
    final order = SudokuSolver.hintSearchOrder;
    const scores = DifficultyAnalyzer.techniqueScores;

    final missing = [
      for (final name in order)
        if (!scores.containsKey(name)) name
    ];
    expect(
      missing,
      isEmpty,
      reason: '进了提示顺序就得有难度分，否则难度分析会把这一步当成没见过的技巧',
    );

    final inversions = <String>[];
    for (var i = 1; i < order.length; i++) {
      final prev = order[i - 1];
      final cur = order[i];
      if (scores[cur]! >= scores[prev]!) continue;
      if (_allowedInversions.containsKey(cur)) continue;
      inversions.add(
        '$cur(${scores[cur]}) 排在 $prev(${scores[prev]}) 之后',
      );
    }
    expect(inversions, isEmpty, reason: '顺序必须按难度分从浅到深，破例要写进 _allowedInversions');
  });

  test('没有过期的破例条目', () {
    final order = SudokuSolver.hintSearchOrder;
    const scores = DifficultyAnalyzer.techniqueScores;
    for (final entry in _allowedInversions.entries) {
      final i = order.indexOf(entry.key);
      expect(i, greaterThan(0), reason: '${entry.key} 已不在提示顺序里，破例条目该删了');
      expect(
        scores[entry.key]! < scores[order[i - 1]]!,
        isTrue,
        reason: '${entry.key} 已经不是逆序了，破例条目该删了',
      );
      expect(entry.value, isNotEmpty, reason: '破例必须写理由');
    }
  });
}
