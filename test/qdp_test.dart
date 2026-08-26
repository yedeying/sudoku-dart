import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

Set<String> _candKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCandidates)
        if (c.role == role) '${c.ref.row},${c.ref.col},${c.ref.num}',
    };

SudokuBoard _shape({
  List<int> lines = const [0, 1],
  List<int> c1 = const [6, 3],
  List<int> c2 = const [6, 4],
  Set<int> c1Extras = const {},
  Set<int> c2Extras = const {5},
  List<int>? leak,
}) {
  const base = {1, 2, 3, 8};
  final allowed = <String, Set<int>>{};
  for (final line in lines) {
    for (final c in [c1, c2]) {
      allowed['$line,${c[1]}'] = base;
    }
  }
  allowed['${c1[0]},${c1[1]}'] = {...base, ...c1Extras};
  allowed['${c2[0]},${c2[1]}'] = {...base, ...c2Extras};
  if (leak != null) allowed['${leak[0]},${leak[1]}'] = {leak[2]};

  // 结构外全部填上数字，finder 就只会读到这一副几何。
  // 线上其它空格若留着又清掉候选，致命性核对会因空集直接放弃，
  // 否定用例就会空过。
  final board = SudokuBoard.empty();
  var fill = 1;
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      if (allowed.containsKey('$r,$c')) continue;
      board.set(r, c, fill);
      fill = fill == 9 ? 1 : fill + 1;
    }
  }
  for (final entry in allowed.entries) {
    final parts = entry.key.split(',');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);
    for (var d = 1; d <= 9; d++) {
      if (!entry.value.contains(d)) board.eliminateCandidate(r, c, d);
    }
  }
  return board;
}

void _expectNoQiu(SudokuBoard board) {
  expect(AdvancedTechniques.findQiu(board), isNull);
}

void main() {
  group('淑芬', () {
    test('教学盘：两条整行、线外两格与四个交点齐全，r7c5 删除全部四个底数', () {
      final puzzle = _tech('qdp').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findQiu(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '淑芬');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'6,4,1', '6,4,2', '6,4,3', '6,4,8'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);

      expect(_cellKeys(hint, HintRole.cover), {'0,3', '0,4', '1,3', '1,4'});
      expect(
        _cellKeys(hint, HintRole.pattern),
        {
          '0,0',
          '0,2',
          '0,6',
          '0,8',
          '1,0',
          '1,1',
          '1,2',
          '1,6',
          '1,7',
          '6,3',
          '6,4',
        },
      );
      expect(_cellKeys(hint, HintRole.target), {'6,4'});
      expect(
        _candKeys(hint, HintRole.pattern),
        {
          for (final r in [0, 1, 6])
            for (final c in r == 6 ? [3, 4] : [3, 4])
              for (final d in [1, 2, 3, 8]) '$r,$c,$d',
        },
      );
      expect(_candKeys(hint, HintRole.extra), {'6,4,5'});
      expect(_candKeys(hint, HintRole.target),
          {'6,4,1', '6,4,2', '6,4,3', '6,4,8'});
      expect(hint.highlightRows, containsAll([0, 1, 6]));
      expect(hint.highlightCols, containsAll([3, 4]));
      expect(hint.highlightBoxes, containsAll([1, 7]));
      expect(hint.links, isEmpty, reason: '这副淑芬不需要靠候选箭头证明');
    });

    test('两条整线不在同一个大行或大列时不报', () {
      _expectNoQiu(_shape(lines: const [0, 3]));
    });

    test('线外两格不同宫时不报', () {
      _expectNoQiu(_shape(c2: const [6, 6]));
    });

    test('线外两格不在同一条交叉线时不报', () {
      _expectNoQiu(_shape(c2: const [7, 4]));
    });

    test('线外两格仍在两条整线所在的带里时不报', () {
      _expectNoQiu(_shape(c1: const [2, 3], c2: const [2, 4]));
    });

    test('四个交点跨两个宫时不报', () {
      _expectNoQiu(_shape(c1: const [6, 2], c2: const [6, 3]));
    });

    test('底数在交点宫的其它格仍可落时不报', () {
      _expectNoQiu(_shape(leak: const [2, 5, 1]));
    });

    test('线外两格都带额外候选时不冒充类型 1', () {
      _expectNoQiu(_shape(c1Extras: const {5}, c2Extras: const {5}));
    });

    test('线外两格都不带额外候选时没有类型 1 结论', () {
      _expectNoQiu(_shape(c2Extras: const {}));
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('qdp').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findQiu(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      var emissions = 0;
      for (final name in ['easy', 'medium', 'hard', 'expert']) {
        final puzzles = PuzzleBank.parse(
          File('assets/puzzles/$name.txt').readAsStringSync(),
        );
        for (final puzzle in puzzles) {
          final solved = SudokuBoard.fromString(puzzle);
          expect(SudokuSolver.solve(solved), isTrue);
          final board = SudokuBoard.fromString(puzzle);
          for (var step = 0; step < 200; step++) {
            final found = AdvancedTechniques.findQiu(board);
            if (found != null) {
              emissions++;
              expectEliminationsSound(puzzle, found);
              for (final e in found.eliminations) {
                expect(solved.get(e.row, e.col), isNot(e.num));
              }
            }
            final hint = SudokuSolver.getHint(board);
            if (hint == null ||
                hint.technique == 'Nishio' ||
                hint.technique == 'Forcing Chain' ||
                hint.technique == 'Forcing Net') {
              break;
            }
            if (hint.isElimination) {
              for (final e in hint.eliminations) {
                board.eliminateCandidate(e.row, e.col, e.num);
              }
            } else {
              board.set(hint.row, hint.col, hint.value);
            }
          }
        }
      }
      // ignore: avoid_print
      print('淑芬题库触发次数：$emissions');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在探长之后、W-Wing 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('淑芬'));
      expect(order.indexOf('探长'), lessThan(order.indexOf('淑芬')));
      expect(order.indexOf('淑芬'), lessThan(order.indexOf('W-Wing')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('淑芬', 82));
      expect(_tech('qdp').teachingOnly, isFalse);
    });
  });
}
