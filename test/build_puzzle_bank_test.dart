import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/puzzle_grade.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 一次性构建分档题库。平时 skip，需要扩库时去掉 skip。
void main() {
  test('build graded puzzle bank', () {
    final sources = <String>[];
    for (final name in ['easy', 'medium', 'hard', 'expert']) {
      final file = File('assets/puzzles/$name.txt');
      if (file.existsSync()) {
        sources.addAll(PuzzleBank.parse(file.readAsStringSync()));
      }
    }
    for (final name in ['easy', 'medium', 'hard', 'diabolical']) {
      final file = File('tool/sepb/$name.txt');
      if (file.existsSync()) {
        sources.addAll(PuzzleBank.parse(file.readAsStringSync()));
      }
    }
    for (final t in TechniqueCatalog.all) {
      sources.add(t.examplePuzzle);
      sources.add(t.copyPuzzle);
    }

    final unique = <String>{
      for (final g in sources)
        if (g.length == 81 && RegExp(r'^[0-9]+$').hasMatch(g)) g,
    };

    final buckets = <PuzzleGrade, List<({String grid, String maxTech})>>{
      for (final g in PuzzleGrade.values) g: [],
    };

    var classified = 0;
    for (final grid in unique) {
      final board = SudokuBoard.fromString(grid);
      if (SudokuSolver.countSolutions(board, limit: 2) != 1) continue;
      final result = DifficultyAnalyzer.analyzeDifficulty(board);
      if (result.level == 'unsupported' || result.level == 'invalid') continue;
      final grade = PuzzleGrades.byId(result.level)?.grade;
      if (grade == null) continue;
      var maxTech = '唯余法';
      var maxScore = -1;
      for (final e in result.usedTechniques.entries) {
        final score = DifficultyAnalyzer.techniqueScores[e.key] ?? 0;
        if (score >= maxScore) {
          maxScore = score;
          maxTech = e.key;
        }
      }
      buckets[grade]!.add((grid: grid, maxTech: maxTech));
      classified++;
    }

    const cap = 120;
    final outDir = Directory('assets/puzzles');
    for (final info in PuzzleGrades.all) {
      final items = buckets[info.grade]!;
      items.shuffle();
      final picked = <({String grid, String maxTech})>[];
      final byTech = <String, List<({String grid, String maxTech})>>{};
      for (final item in items) {
        byTech.putIfAbsent(item.maxTech, () => []).add(item);
      }
      while (picked.length < cap && byTech.values.any((l) => l.isNotEmpty)) {
        for (final list in byTech.values) {
          if (list.isEmpty) continue;
          picked.add(list.removeLast());
          if (picked.length >= cap) break;
        }
      }

      final buf = StringBuffer();
      buf.writeln('# ${info.title}  按最高技巧分档，公有领域 / 教学盘');
      for (var i = 0; i < picked.length; i++) {
        final id = '${info.id}-${(i + 1).toString().padLeft(4, '0')}';
        buf.writeln('$id ${picked[i].grid}');
      }
      File('${outDir.path}/${info.id}.txt').writeAsStringSync(buf.toString());
      // ignore: avoid_print
      print(
        '${info.id}: ${picked.length} (pool=${items.length}) '
        'techs=${{for (final p in picked) p.maxTech}.length}',
      );
    }
    // ignore: avoid_print
    print('classified=$classified unique=${unique.length}');
    expect(classified, greaterThan(0));
  }, skip: 'run manually to rebuild assets/puzzles', timeout: const Timeout(Duration(minutes: 20)));
}
