import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sudoku_board.dart';

/// 只缓存当前这一盘。自定义盘也不入库，换题或做完即覆盖/清掉。
class CurrentGameStore {
  static const prefKey = 'current_game';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> read() async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> write(Map<String, dynamic> data) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setString(prefKey, jsonEncode(data));
  }

  static Future<void> clear() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.remove(prefKey);
  }

  static Map<String, dynamic> snapshot({
    required String id,
    required String difficulty,
    required SudokuBoard board,
    required int elapsedSeconds,
    required int hintsUsed,
    required bool showCandidates,
    required bool candidateMode,
  }) {
    return {
      'id': id,
      'difficulty': difficulty,
      'initial': _grid(board.initial),
      'board': _grid(board.board),
      'eliminated': _sets(board.eliminated),
      'userHidden': _sets(board.userHidden),
      'userCandidates': _sets(board.userCandidates),
      'elapsedSeconds': elapsedSeconds,
      'hintsUsed': hintsUsed,
      'showCandidates': showCandidates,
      'candidateMode': candidateMode,
    };
  }

  static SudokuBoard restoreBoard(Map<String, dynamic> data) {
    final initial = data['initial'] as String? ?? '';
    final fills = data['board'] as String? ?? initial;
    if (initial.length != 81) {
      throw const FormatException('cached game missing initial');
    }
    final board = SudokuBoard.fromString(initial);
    if (fills.length == 81) {
      for (var i = 0; i < 81; i++) {
        final v = int.parse(fills[i]);
        if (v != 0 && board.initial[i ~/ 9][i % 9] == 0) {
          board.set(i ~/ 9, i % 9, v);
        }
      }
    }
    _applySets(board.eliminated, data['eliminated']);
    _applySets(board.userHidden, data['userHidden']);
    _applySets(board.userCandidates, data['userCandidates']);
    board.refreshCandidates();
    return board;
  }

  static String _grid(List<List<int>> cells) {
    final buf = StringBuffer();
    for (final row in cells) {
      for (final v in row) {
        buf.write(v);
      }
    }
    return buf.toString();
  }

  static String _sets(List<List<Set<int>>> cells) {
    final parts = <String>[];
    for (final row in cells) {
      for (final cell in row) {
        final digits = cell.toList()..sort();
        parts.add(digits.join());
      }
    }
    return parts.join(',');
  }

  static void _applySets(List<List<Set<int>>> target, Object? raw) {
    if (raw is! String || raw.isEmpty) return;
    final parts = raw.split(',');
    if (parts.length != 81) return;
    for (var i = 0; i < 81; i++) {
      target[i ~/ 9][i % 9]
        ..clear()
        ..addAll(parts[i].split('').map(int.parse));
    }
  }
}
