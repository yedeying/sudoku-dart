import 'dart:math';

import 'package:flutter/services.dart';

import '../models/puzzle_grade.dart';
import '../models/sudoku_board.dart';

class PuzzleRecord {
  final String id;
  final String grid;

  const PuzzleRecord({required this.id, required this.grid});
}

/// 随包内置题库。按最高技巧分六级，每行 `id 81位`。
///
/// 抽题不记历史：同一档每次随机。自定义盘不进这里。
class PuzzleBank {
  static final Random _random = Random();
  static Map<String, List<PuzzleRecord>>? _cache;

  static const difficulties = PuzzleGrades.ids;

  /// 解析题库文本：`id 81位`，或单独 81 位（缺 id 时用盘面本身当 id）。
  static List<String> parse(String raw) =>
      parseRecords(raw).map((p) => p.grid).toList();

  static List<PuzzleRecord> parseRecords(String raw) {
    final out = <PuzzleRecord>[];
    final seen = <String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      if (parts.first.startsWith('#')) continue;
      String? grid;
      String? id;
      for (final part in parts) {
        if (part.length == 81 && RegExp(r'^[0-9]+$').hasMatch(part)) {
          grid = part;
        } else if (id == null && part.isNotEmpty) {
          id = part;
        }
      }
      if (grid == null || !seen.add(grid)) continue;
      out.add(PuzzleRecord(id: id ?? grid, grid: grid));
    }
    return out;
  }

  static PuzzleRecord pickRecord(
    String difficulty, {
    Map<String, List<PuzzleRecord>>? bank,
    Random? random,
  }) {
    final puzzles = (bank ?? _cache)?[difficulty];
    if (puzzles == null || puzzles.isEmpty) {
      throw StateError('no puzzles for $difficulty');
    }
    final r = random ?? _random;
    return puzzles[r.nextInt(puzzles.length)];
  }

  static SudokuBoard pick(
    String difficulty, {
    Map<String, List<String>>? bank,
    Map<String, List<PuzzleRecord>>? records,
    Random? random,
  }) {
    if (records != null) {
      return SudokuBoard.fromString(
        pickRecord(difficulty, bank: records, random: random).grid,
      );
    }
    if (bank != null) {
      final puzzles = bank[difficulty];
      if (puzzles == null || puzzles.isEmpty) {
        throw StateError('no puzzles for $difficulty');
      }
      final r = random ?? _random;
      return SudokuBoard.fromString(puzzles[r.nextInt(puzzles.length)]);
    }
    return SudokuBoard.fromString(
      pickRecord(difficulty, random: random).grid,
    );
  }

  static Future<PuzzleRecord> loadRecord(
    String difficulty, {
    Random? random,
  }) async {
    await ensureLoaded();
    return pickRecord(difficulty, random: random);
  }

  static Future<SudokuBoard> load(
    String difficulty, {
    Random? random,
  }) async {
    final record = await loadRecord(difficulty, random: random);
    return SudokuBoard.fromString(record.grid);
  }

  static Future<void> ensureLoaded() async {
    if (_cache != null) return;
    final loaded = <String, List<PuzzleRecord>>{};
    for (final difficulty in difficulties) {
      final raw = await rootBundle.loadString('assets/puzzles/$difficulty.txt');
      loaded[difficulty] = parseRecords(raw);
    }
    _cache = loaded;
  }

  static void useForTest(Map<String, List<String>> bank) {
    _cache = {
      for (final e in bank.entries)
        e.key: [
          for (var i = 0; i < e.value.length; i++)
            PuzzleRecord(id: '${e.key}-${i + 1}', grid: e.value[i]),
        ],
    };
  }

  static void resetForTest() {
    _cache = null;
  }
}
