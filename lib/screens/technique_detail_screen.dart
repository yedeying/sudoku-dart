import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import '../models/technique_catalog.dart';
import '../widgets/sudoku_grid.dart';

class TechniqueDetailScreen extends StatelessWidget {
  final TechniqueInfo info;

  const TechniqueDetailScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final board = SudokuBoard.fromString(info.examplePuzzle);
    return Scaffold(
      appBar: AppBar(title: Text(info.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(info.summary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SudokuGrid(
            board: board,
            selectedRow: null,
            selectedCol: null,
            onCellTap: (_, __) {},
            showCandidates: true,
            markup: info.exampleMarkup,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          Text(
            '此页为固定示例，不对局、不自动推演。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}
