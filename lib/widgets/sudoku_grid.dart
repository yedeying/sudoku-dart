import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import '../models/board_markup.dart';
import '../theme/board_palette.dart';
import 'board_arrows_painter.dart';

class SudokuGrid extends StatelessWidget {
  final SudokuBoard board;
  final int? selectedRow;
  final int? selectedCol;
  final Function(int row, int col) onCellTap;
  final void Function(int row, int col, int num)? onCandidateTap;
  final Set<int> conflictCells;
  final Set<CandidateRef> conflictCandidates;
  final bool showCandidates;
  final BoardMarkup? markup;
  final bool readOnly;
  final Set<int> sameDigitCells;
  final Set<CandidateRef> sameDigitCandidates;
  final CandidateRef? arrowAnchor;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
    this.onCandidateTap,
    this.conflictCells = const {},
    this.conflictCandidates = const {},
    this.showCandidates = false,
    this.markup,
    this.readOnly = false,
    this.sameDigitCells = const {},
    this.sameDigitCandidates = const {},
    this.arrowAnchor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BoardPalette.of(context);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 4px 内边距，格子紧挨着排。格线单独整板画，交叉处才连得上。
            const pad = 4.0;
            final cellSize = (constraints.maxWidth - pad * 2) / 9;
            return Stack(
              children: [
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(pad),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) {
                    int row = index ~/ 9;
                    int col = index % 9;
                    return _buildCell(
                      context,
                      row,
                      col,
                      showCandidates,
                      cellSize,
                    );
                  },
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GridLinesPainter(
                        thin: palette.gridThin,
                        strong: palette.gridStrong,
                        padding: pad,
                      ),
                    ),
                  ),
                ),
                if (markup != null && markup!.arrows.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: BoardArrowsPainter(
                          markup: markup!,
                          padding: pad,
                          strongColor: palette.strongArrow,
                          weakColor: palette.weakArrow,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    int row,
    int col,
    bool showCands,
    double cellSize,
  ) {
    final palette = BoardPalette.of(context);
    bool isInitial = board.isInitial(row, col);
    bool isSelected = selectedRow == row && selectedCol == col;
    bool isRelated = _isRelatedCell(row, col);
    int value = board.get(row, col);
    bool hasConflict = conflictCells.contains(row * 9 + col);
    final cellKey = BoardMarkup.cellKey(row, col);
    final markColor = markup?.cellColors[cellKey];
    final markWash = markColor == null ? null : MarkupPalette.wash(markColor);
    final sameDigit = sameDigitCells.contains(cellKey);

    Color bgColor;
    if (markWash != null) {
      bgColor = markWash;
    } else if (hasConflict) {
      bgColor = palette.conflict;
    } else if (isSelected) {
      bgColor = palette.selected;
    } else if (sameDigit) {
      bgColor = palette.sameDigit;
    } else if (isRelated) {
      bgColor = palette.related;
    } else if ((row ~/ 3 + col ~/ 3) % 2 == 0) {
      bgColor = palette.paperAlt;
    } else {
      bgColor = palette.paper;
    }

    return GestureDetector(
      onTap: readOnly ? null : () => onCellTap(row, col),
      child: Container(
        key: ValueKey('cell-$row-$col'),
        color: bgColor,
        child: Center(
          child: value == 0
              ? _buildCandidates(context, row, col, showCands, cellSize)
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: cellSize * 0.55,
                    height: 1,
                    fontWeight: isInitial ? FontWeight.bold : FontWeight.normal,
                    // 上了色的格子按底色取对照色，不然深底深字全看不见。
                    color: markWash != null
                        ? (markWash.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white)
                        : hasConflict
                            ? palette.conflictDigit
                            : isInitial
                                ? palette.givenDigit
                                : palette.userDigit,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCandidates(
    BuildContext context,
    int row,
    int col,
    bool showCands,
    double cellSize,
  ) {
    // “显示候选”是唯一的视图层开关。选中、同数字高亮、候选上色等
    // 只改变候选显示后的样式，不能绕过隐藏状态。
    if (!showCands) {
      return const SizedBox.shrink();
    }

    final candidates = board.visibleCandidates(row, col);

    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = BoardPalette.of(context);
    final filter = markup?.filterDigit;
    final rawCell = markup?.cellColors[BoardMarkup.cellKey(row, col)];
    final cellWash = rawCell == null ? null : MarkupPalette.wash(rawCell);
    final fontSize = cellSize * 0.25;
    final chipSize = cellSize * 0.30;

    // 用固定的 3x3 布局而不是 GridView：格子里的滚动视图会在
    // Web 上鼠标悬停时冒出滚动条。
    return Padding(
      padding: EdgeInsets.all(cellSize * 0.04),
      child: _miniGrid(
        List.generate(9, (index) {
          int num = index + 1;
          bool isCandidate = candidates.contains(num);
          final ref = CandidateRef(row, col, num);
          final struck = markup?.struck.contains(ref) ?? false;
          final cColor = markup?.candidateColors[ref];
          final dimmed = filter != null && num != filter;
          final sameDigit = sameDigitCandidates.contains(ref);
          final isAnchor = arrowAnchor == ref;
          final inConflict = conflictCandidates.contains(ref);
          // 高亮一律用圆圈底色，数字只负责在底色上保持可读。
          final Color? chipColor = struck
              ? palette.candidateStruck
              : isAnchor
                  ? palette.anchor
                  : cColor ??
                      (inConflict
                          ? null
                          : (sameDigit ? palette.sameDigit : null));
          final Color glyphColor;
          if (inConflict) {
            glyphColor = palette.conflictDigit;
          } else if (chipColor != null) {
            glyphColor = chipColor.computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white;
          } else if (dimmed) {
            glyphColor = palette.candidateDim;
          } else if (cellWash != null) {
            glyphColor = cellWash.computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white;
          } else {
            // 手写和自动候选同一个样子：用户不需要知道哪个是自己加的。
            glyphColor = palette.candidate;
          }
          final text = Text(
            isCandidate ? num.toString() : '',
            style: TextStyle(
              fontSize: fontSize,
              height: 1,
              fontWeight:
                  chipColor != null ? FontWeight.bold : FontWeight.normal,
              color: glyphColor,
            ),
          );
          Widget digit = text;
          if (isCandidate && chipColor != null) {
            digit = _chip(chipSize, chipColor, text);
          }
          return GestureDetector(
            key: ValueKey('cand-$row-$col-$num'),
            onTap: !isCandidate || onCandidateTap == null
                ? null
                : () => onCandidateTap!(row, col, num),
            behavior: HitTestBehavior.opaque,
            child: Center(child: digit),
          );
        }),
      ),
    );
  }

  Widget _miniGrid(List<Widget> cells) {
    return Column(
      children: [
        for (int r = 0; r < 3; r++)
          Expanded(
            child: Row(
              children: [
                for (int c = 0; c < 3; c++) Expanded(child: cells[r * 3 + c]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip(double size, Color color, Widget child) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: child,
    );
  }

  bool _isRelatedCell(int row, int col) {
    if (selectedRow == null || selectedCol == null) return false;
    if (row == selectedRow || col == selectedCol) return true;
    int boxRow = row ~/ 3;
    int boxCol = col ~/ 3;
    int selectedBoxRow = selectedRow! ~/ 3;
    int selectedBoxCol = selectedCol! ~/ 3;
    return boxRow == selectedBoxRow && boxCol == selectedBoxCol;
  }
}

/// 宫线和格线一次画完，交叉处不断开。
class _GridLinesPainter extends CustomPainter {
  final Color thin;
  final Color strong;
  final double padding;

  const _GridLinesPainter({
    required this.thin,
    required this.strong,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );
    final cell = inner.width / 9;
    final thinPaint = Paint()
      ..color = thin
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    final strongPaint = Paint()
      ..color = strong
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;

    for (var i = 0; i <= 9; i++) {
      final paint = i % 3 == 0 ? strongPaint : thinPaint;
      final x = inner.left + i * cell;
      final y = inner.top + i * cell;
      canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), paint);
      canvas.drawLine(Offset(inner.left, y), Offset(inner.right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter old) =>
      thin != old.thin || strong != old.strong || padding != old.padding;
}
