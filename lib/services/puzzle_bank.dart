import 'dart:math';

import 'package:flutter/services.dart';

import '../models/sudoku_board.dart';

/// 随包内置的公开题库（Sudoku Exchange Puzzle Bank，公有领域）。
class PuzzleBank {
  static final Random _random = Random();
  static Map<String, List<String>>? _cache;

  static const difficulties = ['easy', 'medium', 'hard', 'expert'];

  /// 解析题库文本：每行可以是单独 81 位，或「hash 81位 评分」。
  static List<String> parse(String raw) {
    final out = <String>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) {
        continue;
      }
      String? candidate;
      for (final part in parts) {
        if (part.length == 81 && RegExp(r'^[0-9]+$').hasMatch(part)) {
          candidate = part;
          break;
        }
      }
      if (candidate != null) {
        out.add(candidate);
      }
    }
    return out;
  }

  static SudokuBoard pick(
    String difficulty, {
    Map<String, List<String>>? bank,
    Random? random,
  }) {
    final puzzles = (bank ?? _cache)?[difficulty];
    if (puzzles == null || puzzles.isEmpty) {
      throw StateError('no puzzles for $difficulty');
    }
    final r = random ?? _random;
    return SudokuBoard.fromString(puzzles[r.nextInt(puzzles.length)]);
  }

  static Future<SudokuBoard> load(
    String difficulty, {
    Random? random,
  }) async {
    await ensureLoaded();
    return pick(difficulty, random: random);
  }

  static Future<void> ensureLoaded() async {
    if (_cache != null) {
      return;
    }
    final loaded = <String, List<String>>{};
    for (final difficulty in difficulties) {
      final raw =
          await rootBundle.loadString('assets/puzzles/$difficulty.txt');
      loaded[difficulty] = parse(raw);
    }
    _cache = loaded;
  }

  /// 测试用：直接注入题库，跳过资源加载。
  static void useForTest(Map<String, List<String>> bank) {
    _cache = bank;
  }

  /// 测试用：重置缓存。
  static void resetForTest() {
    _cache = null;
  }
}
