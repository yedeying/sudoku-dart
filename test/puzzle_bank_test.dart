import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';

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
      'easy': [
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        '020608000580009700000040000370000500600000004008000013000030000009800036000507010',
      ],
    };
    final board = PuzzleBank.pick('easy', bank: bank, random: Random(1));
    expect(board.board.expand((r) => r).length, 81);
    expect(board.board.any((r) => r.contains(0)), isTrue);
    expect(board.initial.any((r) => r.any((v) => v != 0)), isTrue);
  });

  testWidgets('随包 easy 题库可加载', (tester) async {
    PuzzleBank.resetForTest();
    final board = await PuzzleBank.load('easy', random: Random(0));
    expect(board.board.expand((r) => r).length, 81);
    expect(board.board.any((r) => r.contains(0)), isTrue);
  });
}
