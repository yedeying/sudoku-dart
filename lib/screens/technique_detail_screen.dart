import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/sudoku_board.dart';
import '../models/technique_catalog.dart';
import '../widgets/sudoku_grid.dart';
import 'game_screen.dart';

class TechniqueDetailScreen extends StatelessWidget {
  final TechniqueInfo info;

  const TechniqueDetailScreen({super.key, required this.info});

  Future<void> _copyPuzzle(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: info.copyPuzzle));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          info.copiesPracticeBoard ? '已复制练习原题' : '已复制例题',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playBoard(BuildContext context) {
    context.read<GameState>().loadTeachingBoard(info.examplePuzzle);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = SudokuBoard.fromString(info.examplePuzzle);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(info.name),
        actions: [
          IconButton(
            tooltip: '用此盘对局',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _playBoard(context),
          ),
          IconButton(
            tooltip: '复制例题',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copyPuzzle(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final item in info.legend)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(item.label, style: theme.textTheme.bodySmall),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          info.copiesPracticeBoard
                              ? '上图是结构示意。右上角复制的是一张练习原题；对局图标载入的是本页这张盘。'
                              : '此页为固定示例。右上角可复制盘面，或用对局图标带着当前候选进入对局。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section('本例推导', info.walkthrough),
                  const SizedBox(height: 10),
                  _section('技巧定义', info.definition),
                  const SizedBox(height: 10),
                  _section('识别方法', info.howToSpot),
                  const SizedBox(height: 10),
                  _section('注意事项', info.caveats),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
