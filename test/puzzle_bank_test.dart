import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void main() {
  test('解析公开题库行，得到 81 位数字串', () {
    const raw = '''
abc123def456 530070000600195000098000060800060003400803001700020006060000280000419005000080079 1.2
003020600900305001001806400008102900700000008006708200002609500800203009005010300
''';
    final puzzles = PuzzleBank.parse(raw);
    expect(puzzles, hasLength(2));
    expect(puzzles.every((p) => p.length == 81), isTrue);
    expect(puzzles.first.startsWith('53007'), isTrue);
  });

  test('按难度随机抽一题，结果是合法空格棋盘', () {
    final bank = {
      'beginner': [
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        '020608000580009700000040000370000500600000004008000013000030000009800036000507010',
      ],
    };
    final board = PuzzleBank.pick('beginner', bank: bank, random: Random(1));
    expect(board.board.expand((r) => r).length, 81);
    expect(board.board.any((r) => r.contains(0)), isTrue);
    expect(board.initial.any((r) => r.any((v) => v != 0)), isTrue);
  });

  test('解析带 id 的题库行', () {
    const raw = '''
# comment
beginner-0001 530070000600195000098000060800060003400803001700020006060000280000419005000080079
''';
    final records = PuzzleBank.parseRecords(raw);
    expect(records, hasLength(1));
    expect(records.first.id, 'beginner-0001');
    expect(records.first.grid.startsWith('53007'), isTrue);
  });

  test('六档题库都有带 id 的题目', () {
    for (final name in PuzzleBank.difficulties) {
      final records = PuzzleBank.parseRecords(
        File('assets/puzzles/$name.txt').readAsStringSync(),
      );
      expect(records, isNotEmpty, reason: name);
      expect(records.first.id, startsWith('$name-'));
      expect(records.map((r) => r.id).toSet().length, records.length);
    }
  });

  test('随包每一题都是唯一解', () {
    for (final name in PuzzleBank.difficulties) {
      final records = PuzzleBank.parseRecords(
        File('assets/puzzles/$name.txt').readAsStringSync(),
      );
      for (final record in records) {
        expect(
          SudokuSolver.countSolutions(
            SudokuBoard.fromString(record.grid),
            limit: 2,
          ),
          1,
          reason: '${record.id} 必须唯一解',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('随包入门题库可加载', (tester) async {
    PuzzleBank.resetForTest();
    final board = await PuzzleBank.load('beginner', random: Random(0));
    expect(board.board.expand((r) => r).length, 81);
    expect(board.board.any((r) => r.contains(0)), isTrue);
  });
}
