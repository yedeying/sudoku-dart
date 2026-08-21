import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'input_screen.dart';

class _Difficulty {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _Difficulty(this.id, this.title, this.subtitle, this.icon);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_Difficulty> _levels = [
    _Difficulty('easy', '简单', '只需基础技巧，适合新手', Icons.spa_outlined),
    _Difficulty('medium', '中等', '需要中级技巧，挑战思维', Icons.timeline_outlined),
    _Difficulty('hard', '困难', '需要 X-Wing 等高级技巧', Icons.bolt_outlined),
    _Difficulty(
        'expert', '专家', '需要 XY-Wing 等专家技巧', Icons.workspace_premium_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      level.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
