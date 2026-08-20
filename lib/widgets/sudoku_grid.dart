import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import '../models/board_markup.dart';
import '../theme/app_theme.dart';
import 'board_arrows_painter.dart';

class SudokuGrid extends StatelessWidget {
  final SudokuBoard board;
  final int? selectedRow;
  final int? selectedCol;
  final Function(int row, int col) onCellTap;
  final void Function(int row, int col, int num)? onCandidateTap;
  final Set<int> conflictCells;
  final bool showCandidates;
  final BoardMarkup? markup;
  final bool readOnly;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
    this.onCandidateTap,
    this.conflictCells = const {},
    this.showCandidates = false,
    this.markup,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showCands = showCandidates ||
        (markup != null &&
            (markup!.candidateColors.isNotEmpty ||
                markup!.filterDigit != null ||
                markup!.arrows.isNotEmpty));

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = (constraints.maxWidth - 12) / 9;
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius - 8),
              child: Stack(
                children: [
                  Column(
                    children: List.generate(9, (row) {
                      return Expanded(
                        child: Row(
                          children: List.generate(9, (col) {
                            return Expanded(
                              child: _buildCell(
                                context,
                                row,
                                col,
                                showCands,
                                cellSize,
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                  if (markup != null && markup!.arrows.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: BoardArrowsPainter(
                            markup: markup!,
                            padding: 0,
                            strongColor: scheme.primary,
                            weakColor: scheme.onSurfaceVariant,
                            conjugateColor: scheme.tertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
    final scheme = Theme.of(context).colorScheme;
    final isInitial = board.isInitial(row, col);
    final isSelected = selectedRow == row && selectedCol == col;
    final isRelated = _isRelatedCell(row, col);
    final value = board.get(row, col);
    final hasConflict = conflictCells.contains(row * 9 + col);
    final markColor = markup?.cellColors[BoardMarkup.cellKey(row, col)];
    final samePeerValue = value != 0 &&
        selectedRow != null &&
        selectedCol != null &&
        board.get(selectedRow!, selectedCol!) == value;

    Color bgColor;
    if (markColor != null) {
      bgColor = markColor;
    } else if (hasConflict) {
      bgColor = scheme.errorContainer;
    } else if (isSelected) {
      bgColor = scheme.primaryContainer;
    } else if (samePeerValue) {
      bgColor = scheme.tertiaryContainer.withValues(alpha: 0.55);
    } else if (isRelated) {
      bgColor = scheme.primaryContainer.withValues(alpha: 0.28);
    } else if ((row ~/ 3 + col ~/ 3) % 2 == 0) {
      bgColor = scheme.surfaceContainerLow;
    } else {
      bgColor = scheme.surfaceContainerLowest;
    }

    final Color valueColor;
    if (markColor != null) {
      valueColor =
          ThemeData.estimateBrightnessForColor(markColor) == Brightness.dark
              ? Colors.white
              : Colors.black87;
    } else if (hasConflict) {
      valueColor = scheme.error;
    } else if (isInitial) {
      valueColor = scheme.onSurface;
    } else {
      valueColor = scheme.primary;
    }

    return GestureDetector(
      onTap: readOnly ? null : () => onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: _getBorder(context, row, col),
        ),
        child: Center(
          child: value == 0
              ? _buildCandidates(context, row, col, showCands, cellSize)
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: cellSize * 0.52,
                    height: 1,
                    fontWeight: isInitial ? FontWeight.w700 : FontWeight.w500,
                    color: valueColor,
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
    if (!showCands && (selectedRow != row || selectedCol != col)) {
      return const SizedBox.shrink();
    }

    // ignore: unused_local_variable
    final autoCands = board.getCandidates(row, col);
    final userCands = board.getUserCandidates(row, col);
    final candidates = board.visibleCandidates(row, col);

    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final filter = markup?.filterDigit;
    final fontSize = (cellSize * 0.26).clamp(7.0, 14.0);

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: List.generate(3, (bandRow) {
          return Expanded(
            child: Row(
              children: List.generate(3, (bandCol) {
                final num = bandRow * 3 + bandCol + 1;
                final isCandidate = candidates.contains(num);
                final isUserNote = userCands.contains(num);
                final ref = CandidateRef(row, col, num);
                final struck = markup?.struck.contains(ref) ?? false;
                final cColor = markup?.candidateColors[ref];
                final dimmed = filter != null && num != filter;

                return Expanded(
                  child: GestureDetector(
                    onTap: !isCandidate || onCandidateTap == null
                        ? null
                        : () => onCandidateTap!(row, col, num),
                    child: Center(
                      child: Text(
                        isCandidate ? num.toString() : '',
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1,
                          fontWeight: cColor != null || isUserNote
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: struck
                              ? scheme.error.withValues(alpha: 0.7)
                              : cColor ??
                                  (dimmed
                                      ? scheme.onSurfaceVariant
                                          .withValues(alpha: 0.28)
                                      : (isUserNote
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant)),
                          decoration:
                              struck ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
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

  Border _getBorder(BuildContext context, int row, int col) {
    final scheme = Theme.of(context).colorScheme;
    final thin = scheme.outlineVariant.withValues(alpha: 0.7);
    final thick = scheme.outline;

    return Border(
      top: BorderSide(
        color: row % 3 == 0 ? thick : thin,
        width: row % 3 == 0 ? 1.6 : 0.6,
      ),
      left: BorderSide(
        color: col % 3 == 0 ? thick : thin,
        width: col % 3 == 0 ? 1.6 : 0.6,
      ),
      right: BorderSide(
        color: col == 8 ? thick : Colors.transparent,
        width: col == 8 ? 1.6 : 0,
      ),
      bottom: BorderSide(
        color: row == 8 ? thick : Colors.transparent,
        width: row == 8 ? 1.6 : 0,
      ),
    );
  }
}
