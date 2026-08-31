import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/puzzle_grade.dart';
import '../theme/app_theme.dart';
import '../widgets/accent_picker.dart';
import '../widgets/phone_frame.dart';
import 'game_screen.dart';
import 'input_screen.dart';

class _Difficulty {
  final String id;
  final String title;
  final IconData icon;

  const _Difficulty(this.id, this.title, this.icon);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_Difficulty> _levels = [
    _Difficulty('beginner', '入门', Icons.spa_outlined),
    _Difficulty('normal', '普通', Icons.timeline_outlined),
    _Difficulty('advanced', '进阶', Icons.bolt_outlined),
    _Difficulty('professional', '专业', Icons.workspace_premium_outlined),
    _Difficulty('master', '大师', Icons.military_tech_outlined),
    _Difficulty('hell', '地狱', Icons.local_fire_department_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = context.watch<GameState>();

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHighest,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PhoneFrame.maxWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  if (game.hasResumableGame) ...[
                    _ContinueTile(game: game),
                    const SizedBox(height: 12),
                  ],
                  for (final level in _levels) ...[
                    _DifficultyTile(level: level),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InputScreen()),
                    ),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('手动输入题目'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Icon(
                Icons.grid_4x4,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '强调色',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => AccentPicker.open(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('数独游戏', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '选择难度开始，或到「技巧说明」学习解题手法',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ContinueTile extends StatelessWidget {
  final GameState game;

  const _ContinueTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = PuzzleGrades.titleOf(game.difficulty);
    final id = game.puzzleId;
    final subtitle = id == null || id == 'custom' ? '自定义' : '$title · $id';

    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GameScreen()),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 26,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('继续题目', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  final _Difficulty level;

  const _DifficultyTile({required this.level});

  Future<void> _start(BuildContext context) async {
    final gameState = context.read<GameState>();
    final navigator = Navigator.of(context);

    await gameState.startNewGame(level.id);

    if (!context.mounted) return;
    navigator.push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: () => _start(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  level.icon,
                  size: 26,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(level.title, style: theme.textTheme.titleMedium),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
