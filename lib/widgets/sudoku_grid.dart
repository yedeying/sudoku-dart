import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import '../models/board_markup.dart';
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
    final showCands = showCandidates ||
        (markup != null &&
            (markup!.candidateColors.isNotEmpty ||
                markup!.filterDigit != null ||
                markup!.arrows.isNotEmpty));

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: 81,
              itemBuilder: (context, index) {
                int row = index ~/ 9;
                int col = index % 9;
                return _buildCell(context, row, col, showCands);
              },
            ),
            if (markup != null && markup!.arrows.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: BoardArrowsPainter(markup: markup!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, int row, int col, bool showCands) {
    bool isInitial = board.isInitial(row, col);
    bool isSelected = selectedRow == row && selectedCol == col;
    bool isRelated = _isRelatedCell(row, col);
    int value = board.get(row, col);
    bool hasConflict = conflictCells.contains(row * 9 + col);
    final markColor = markup?.cellColors[BoardMarkup.cellKey(row, col)];

    Color bgColor;
    if (markColor != null) {
      bgColor = markColor;
    } else if (hasConflict) {
      bgColor = Colors.red.shade100;
    } else if (isSelected) {
      bgColor = Colors.blue.shade200;
    } else if (isRelated) {
      bgColor = Colors.blue.shade50;
    } else if ((row ~/ 3 + col ~/ 3) % 2 == 0) {
      bgColor = Colors.grey.shade50;
    } else {
      bgColor = Colors.white;
    }

    return GestureDetector(
      onTap: readOnly ? null : () => onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: _getBorder(row, col),
        ),
        child: Center(
          child: value == 0
              ? _buildCandidates(context, row, col, showCands)
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: isInitial ? FontWeight.bold : FontWeight.normal,
                    color: isInitial
                        ? Colors.black
                        : hasConflict
                            ? Colors.red
                            : Colors.blue.shade700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCandidates(
      BuildContext context, int row, int col, bool showCands) {
    if (!showCands && (selectedRow != row || selectedCol != col)) {
      return const SizedBox.shrink();
    }

    final userCands = board.getUserCandidates(row, col);
    final candidates = board.visibleCandidates(row, col);

    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final filter = markup?.filterDigit;

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (index) {
          int num = index + 1;
          bool isCandidate = candidates.contains(num);
          final ref = CandidateRef(row, col, num);
          final struck = markup?.struck.contains(ref) ?? false;
          final cColor = markup?.candidateColors[ref];
          final dimmed = filter != null && num != filter;
          return GestureDetector(
            onTap: !isCandidate || onCandidateTap == null
                ? null
                : () => onCandidateTap!(row, col, num),
            child: Center(
              child: Text(
                isCandidate ? num.toString() : '',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: cColor != null || userCands.contains(num)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: struck
                      ? Colors.red.shade300
                      : cColor ??
                          (dimmed
                              ? Colors.grey.shade300
                              : (userCands.contains(num)
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600)),
                  decoration: struck ? TextDecoration.lineThrough : null,
                ),
              ),
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

  Border _getBorder(int row, int col) {
    return Border(
      top: BorderSide(
        color: row % 3 == 0 ? Colors.black : Colors.grey.shade300,
        width: row % 3 == 0 ? 2 : 1,
      ),
      left: BorderSide(
        color: col % 3 == 0 ? Colors.black : Colors.grey.shade300,
        width: col % 3 == 0 ? 2 : 1,
      ),
      right: BorderSide(
        color: col == 8 ? Colors.black : Colors.transparent,
        width: col == 8 ? 2 : 0,
      ),
      bottom: BorderSide(
        color: row == 8 ? Colors.black : Colors.transparent,
        width: row == 8 ? 2 : 0,
      ),
    );
  }
}
