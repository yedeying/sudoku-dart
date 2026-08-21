import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import '../models/technique_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/sudoku_grid.dart';

class TechniqueDetailScreen extends StatelessWidget {
  final TechniqueInfo info;

  const TechniqueDetailScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final board = SudokuBoard.fromString(info.examplePuzzle);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(info.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Text(
                  info.summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSecondaryContainer,
                    height: 1.5,
                  ),
                ),
              ),
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
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '此页为固定示例，不对局、不自动推演。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
