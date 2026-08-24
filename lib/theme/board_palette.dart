import 'package:flutter/material.dart';

/// 棋盘专用配色。
///
/// 棋盘的语义（题目数字 / 用户填数 / 冲突 / 同数弱高亮 / 宫线）比通用的
/// [ColorScheme] 角色更细，直接借用 surface 系列会在深色模式下出现
/// 白纸上盖深灰块之类的错配，所以单独成一套并跟随亮暗切换。
@immutable
class BoardPalette extends ThemeExtension<BoardPalette> {
  /// 棋盘底板与普通格子背景。
  final Color paper;

  /// 交替宫格的浅底，用来区分 3x3 宫。
  final Color paperAlt;

  /// 选中格所在的行、列、宫。
  final Color related;

  /// 当前选中格。
  final Color selected;

  /// 同数字弱高亮。
  final Color sameDigit;

  /// 冲突格背景。
  final Color conflict;

  /// 题目给定的数字。
  final Color givenDigit;

  /// 用户填入的数字。
  final Color userDigit;

  /// 冲突数字。
  final Color conflictDigit;

  /// 自动计算出的候选数。
  final Color candidate;

  /// 用户手写的候选数（笔记）。
  final Color candidateNote;

  /// 被数字过滤器压暗的候选数。
  final Color candidateDim;

  /// 已被技巧删除、带删除线的候选数。
  final Color candidateStruck;

  /// 宫线（粗）。
  final Color gridStrong;

  /// 格线（细）。
  final Color gridThin;

  /// 链起点标记圆点。
  final Color anchor;

  /// 链起点圆点上的数字。
  final Color onAnchor;

  /// 强链箭头。
  final Color strongArrow;

  /// 弱链箭头。
  final Color weakArrow;

  const BoardPalette({
    required this.paper,
    required this.paperAlt,
    required this.related,
    required this.selected,
    required this.sameDigit,
    required this.conflict,
    required this.givenDigit,
    required this.userDigit,
    required this.conflictDigit,
    required this.candidate,
    required this.candidateNote,
    required this.candidateDim,
    required this.candidateStruck,
    required this.gridStrong,
    required this.gridThin,
    required this.anchor,
    required this.onAnchor,
    required this.strongArrow,
    required this.weakArrow,
  });

  /// 底色一律走中性灰；选中、同数字浅底、用户填入、强链带强调色色相。
  static const BoardPalette lightPalette = BoardPalette(
    paper: Color(0xFFFFFFFF),
    paperAlt: Color(0xFFF6F6F6),
    related: Color(0xFFE9EDF3),
    selected: Color(0xFFC3D0E6),
    sameDigit: Color(0xFFD6E3F5),
    conflict: Color(0xFFF7D9D6),
    givenDigit: Color(0xFF1A1A1A),
    userDigit: Color(0xFF35507A),
    conflictDigit: Color(0xFFB3261E),
    candidate: Color(0xFF6E6E6E),
    candidateNote: Color(0xFF35507A),
    candidateDim: Color(0xFFC6C6C6),
    candidateStruck: Color(0xFFC96A63),
    gridStrong: Color(0xFF2A2A2A),
    gridThin: Color(0xFFD6D6D6),
    anchor: Color(0xFF1A1A1A),
    onAnchor: Color(0xFFFFFFFF),
    strongArrow: Color(0xFF35507A),
    weakArrow: Color(0xFF6E6E6E),
  );

  static const BoardPalette darkPalette = BoardPalette(
    paper: Color(0xFF1F1F1F),
    paperAlt: Color(0xFF272727),
    related: Color(0xFF333A45),
    selected: Color(0xFF44546F),
    sameDigit: Color(0xFF3D3D3D),
    conflict: Color(0xFF5A2E2A),
    givenDigit: Color(0xFFF2F2F2),
    userDigit: Color(0xFFA8BEDE),
    conflictDigit: Color(0xFFF2B8B5),
    candidate: Color(0xFFA0A0A0),
    candidateNote: Color(0xFFA8BEDE),
    candidateDim: Color(0xFF5C5C5C),
    candidateStruck: Color(0xFFD4837D),
    gridStrong: Color(0xFFD8D8D8),
    gridThin: Color(0xFF424242),
    anchor: Color(0xFFF2F2F2),
    onAnchor: Color(0xFF1F1F1F),
    strongArrow: Color(0xFFA8BEDE),
    weakArrow: Color(0xFFA0A0A0),
  );

  static BoardPalette of(BuildContext context) {
    return Theme.of(context).extension<BoardPalette>() ?? lightPalette;
  }

  /// Derive accent-tinted roles from [accent]; keep paper, grids, and
  /// given/candidate glyphs neutral so markup colors stay readable.
  static BoardPalette fromAccent(Brightness brightness, Color accent) {
    final light = brightness == Brightness.light;
    final base = light ? lightPalette : darkPalette;
    final glyph = light ? accent : _withLightness(accent, 0.76);
    return base.copyWith(
      related: _relatedWash(accent, light: light),
      selected: _selectedWash(accent, light: light),
      sameDigit: _sameDigitWash(accent, light: light),
      userDigit: glyph,
      candidateNote: glyph,
      strongArrow: glyph,
    );
  }

  static Color _withLightness(Color color, double lightness) {
    return HSLColor.fromColor(color)
        .withLightness(lightness.clamp(0.0, 1.0))
        .toColor();
  }

  static Color _sameDigitWash(Color accent, {required bool light}) {
    if (light) return _withLightness(accent, 0.90);
    // Dark wash must stay tinted (not grey) and dark enough for white glyphs.
    for (var lightness = 0.26; lightness >= 0.10; lightness -= 0.02) {
      final wash = _withLightness(accent, lightness);
      if (wash.computeLuminance() < 0.175) return wash;
    }
    return _withLightness(accent, 0.12);
  }

  static Color _selectedWash(Color accent, {required bool light}) {
    return _withLightness(accent, light ? 0.78 : 0.32);
  }

  static Color _relatedWash(Color accent, {required bool light}) {
    return _withLightness(accent, light ? 0.93 : 0.20);
  }

  @override
  BoardPalette copyWith({
    Color? paper,
    Color? paperAlt,
    Color? related,
    Color? selected,
    Color? sameDigit,
    Color? conflict,
    Color? givenDigit,
    Color? userDigit,
    Color? conflictDigit,
    Color? candidate,
    Color? candidateNote,
    Color? candidateDim,
    Color? candidateStruck,
    Color? gridStrong,
    Color? gridThin,
    Color? anchor,
    Color? onAnchor,
    Color? strongArrow,
    Color? weakArrow,
  }) {
    return BoardPalette(
      paper: paper ?? this.paper,
      paperAlt: paperAlt ?? this.paperAlt,
      related: related ?? this.related,
      selected: selected ?? this.selected,
      sameDigit: sameDigit ?? this.sameDigit,
      conflict: conflict ?? this.conflict,
      givenDigit: givenDigit ?? this.givenDigit,
      userDigit: userDigit ?? this.userDigit,
      conflictDigit: conflictDigit ?? this.conflictDigit,
      candidate: candidate ?? this.candidate,
      candidateNote: candidateNote ?? this.candidateNote,
      candidateDim: candidateDim ?? this.candidateDim,
      candidateStruck: candidateStruck ?? this.candidateStruck,
      gridStrong: gridStrong ?? this.gridStrong,
      gridThin: gridThin ?? this.gridThin,
      anchor: anchor ?? this.anchor,
      onAnchor: onAnchor ?? this.onAnchor,
      strongArrow: strongArrow ?? this.strongArrow,
      weakArrow: weakArrow ?? this.weakArrow,
    );
  }

  @override
  BoardPalette lerp(ThemeExtension<BoardPalette>? other, double t) {
    if (other is! BoardPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BoardPalette(
      paper: mix(paper, other.paper),
      paperAlt: mix(paperAlt, other.paperAlt),
      related: mix(related, other.related),
      selected: mix(selected, other.selected),
      sameDigit: mix(sameDigit, other.sameDigit),
      conflict: mix(conflict, other.conflict),
      givenDigit: mix(givenDigit, other.givenDigit),
      userDigit: mix(userDigit, other.userDigit),
      conflictDigit: mix(conflictDigit, other.conflictDigit),
      candidate: mix(candidate, other.candidate),
      candidateNote: mix(candidateNote, other.candidateNote),
      candidateDim: mix(candidateDim, other.candidateDim),
      candidateStruck: mix(candidateStruck, other.candidateStruck),
      gridStrong: mix(gridStrong, other.gridStrong),
      gridThin: mix(gridThin, other.gridThin),
      anchor: mix(anchor, other.anchor),
      onAnchor: mix(onAnchor, other.onAnchor),
      strongArrow: mix(strongArrow, other.strongArrow),
      weakArrow: mix(weakArrow, other.weakArrow),
    );
  }
}
