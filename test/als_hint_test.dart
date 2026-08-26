import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

const userPuzzles = [
  '024610007006070402003824560000200800301060024002001000069002100240130600130006240',
  '100605009000008000753219846000951000001062000002080600607100905315897462009506100',
  '070060010000741600600208079860000091300106007002000360000670000050804036906315702',
  '004060000015830026060001300100006000206100050050000167589072600400610800601000000',
];

void _apply(SudokuBoard board, SudokuHint hint) {
  if (hint.isElimination) {
    for (final e in hint.eliminations) {
      board.eliminateCandidate(e.row, e.col, e.num);
    }
  } else {
    board.set(hint.row, hint.col, hint.value);
  }
}

void _keep(SudokuBoard board, int row, int col, Iterable<int> digits) {
  final keep = digits.toSet();
  for (var digit = 1; digit <= 9; digit++) {
    if (!keep.contains(digit)) {
      board.eliminateCandidate(row, col, digit);
    }
  }
}

SudokuBoard _blank() => SudokuBoard.fromString(List.filled(81, '0').join());

bool _elimIsFalse(SudokuBoard solution, CandidateElim e) =>
    solution.get(e.row, e.col) != e.num;

void main() {
  test('ALS-XZ 删除同时看见两边 Z 的候选', () {
    final board = _blank();
    _keep(board, 0, 0, const [5, 8, 9]);
    _keep(board, 1, 0, const [8, 9]);
    _keep(board, 4, 0, const [3, 7, 8, 9]);
    _keep(board, 5, 0, const [3, 7, 8]);
    _keep(board, 7, 0, const [7, 8, 9]);
    _keep(board, 2, 0, const [9]);

    final hint = AdvancedTechniques.findAlsXz(board);

    expect(hint, isNotNull);
    expect(hint!.technique, 'ALS-XZ');
    expect(hint.isElimination, isTrue);
    expect(hint.eliminations, isNotEmpty);
    expect(hint.patternCells, isNotEmpty);
    expect(
      hint.patternCandidates.any((c) => c.role != HintRole.target),
      isTrue,
    );
  });

  test('ALS-XY-Wing 删除同时看见两翼 Z 的候选', () {
    final board = _blank();
    // 支点 r4c5,r4c6 = {1,4,7}；翼 A 同宫 {1,5,7}；翼 B 同列 {4,5,7}
    _keep(board, 3, 4, const [1, 4, 7]);
    _keep(board, 3, 5, const [4, 7]);
    _keep(board, 4, 4, const [1, 7]);
    _keep(board, 5, 3, const [1, 5]);
    _keep(board, 3, 8, const [4, 7]);
    _keep(board, 7, 8, const [5, 7]);
    _keep(board, 7, 3, const [5]);

    final hint = AdvancedTechniques.findAlsXyWing(board);

    expect(hint, isNotNull);
    expect(hint!.technique, 'ALS-XY-Wing');
    expect(hint.isElimination, isTrue);
    expect(hint.eliminations, isNotEmpty);
    expect(
      hint.patternCandidates.any((c) => c.role != HintRole.target),
      isTrue,
    );
  });

  test('现有浅层技巧卡住后，残局都能在短时间给出 ALS 提示', () {
    var deepHits = 0;
    for (final puzzle in userPuzzles) {
      expect(
        SudokuSolver.countSolutions(SudokuBoard.fromString(puzzle), limit: 2),
        1,
      );
      final solved = SudokuBoard.fromString(puzzle);
      expect(SudokuSolver.solve(solved), isTrue);

      final stalled = SudokuBoard.fromString(puzzle);
      for (var i = 0; i < 200; i++) {
        final hint = SudokuSolver.getHint(stalled);
        if (hint == null) break;
        if (hint.isElimination &&
            hint.eliminations.any((e) => !_elimIsFalse(solved, e))) {
          fail('${hint.technique} 删了正确数字 ${hint.eliminations}');
        }
        if (hint.technique == 'ALS-XZ' ||
            hint.technique == 'ALS-XY-Wing' ||
            hint.technique == 'Grouped AIC' ||
            hint.technique == 'Nishio' ||
            hint.technique == 'XY-Chain' ||
            hint.technique == 'AIC 开链' ||
            hint.technique == 'Nice Loop / AIC 环' ||
            hint.technique == 'Sue de Coq' ||
            hint.technique == 'Death Blossom' ||
            hint.technique == 'Kraken Fish' ||
            hint.technique == 'Forcing Chain' ||
            hint.technique == 'Forcing Net') {
          break;
        }
        _apply(stalled, hint);
        if (stalled.isComplete()) break;
      }
      // 引擎补上新的浅层技巧之后，这批题里有的已经不用走到深链就做得完；
      // 上面那一圈已经逐条核过每一步的删除，这里就只对真正卡住的残局继续追。
      if (stalled.isComplete()) continue;
      deepHits++;

      final sw = Stopwatch()..start();
      final hint = SudokuSolver.getHint(stalled);
      sw.stop();

      expect(hint, isNotNull, reason: '残局卡住后应给出 ALS 提示');
      expect(
        [
          'ALS-XZ',
          'ALS-XY-Wing',
          'Grouped AIC',
          'Nishio',
          'XY-Chain',
          'AIC 开链',
          'Nice Loop / AIC 环',
          'Sue de Coq',
          'Death Blossom',
          'Kraken Fish',
          'Forcing Chain',
          'Forcing Net',
        ].contains(hint!.technique),
        isTrue,
        reason: '应先报已接入的命名技巧',
      );
      expect(hint.isElimination || hint.value > 0, isTrue);
      if (hint.isElimination) {
        expect(hint.eliminations, isNotEmpty);
        expect(
          hint.eliminations.every((e) => _elimIsFalse(solved, e)),
          isTrue,
          reason: '${hint.technique} 删了正确数字',
        );
      }
      expect(sw.elapsedMilliseconds, lessThan(2000));
    }
    expect(deepHits, greaterThan(0), reason: '这批题里总得还有卡到深链的');
  });

  test('00406 残局连续提示不会在未完成时卡住', () {
    const puzzle =
        '004060000015830026060001300100006000206100050050000167589072600400610800601000000';
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);
    final board = SudokuBoard.fromString(puzzle);

    for (var step = 0; step < 80; step++) {
      if (board.isComplete()) break;
      final sw = Stopwatch()..start();
      final hint = SudokuSolver.getHint(board);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(hint, isNotNull, reason: '未完成却找不到下一步');
      if (hint!.isElimination) {
        expect(
          hint.eliminations.every((e) => _elimIsFalse(solved, e)),
          isTrue,
        );
        _apply(board, hint);
      } else {
        _apply(board, hint);
      }
    }
    expect(board.isComplete(), isTrue);
  });

  test('ALS 技巧名在难度表里', () {
    expect(DifficultyAnalyzer.techniqueScores.containsKey('ALS-XZ'), isTrue);
    expect(
      DifficultyAnalyzer.techniqueScores.containsKey('ALS-XY-Wing'),
      isTrue,
    );
  });
}
