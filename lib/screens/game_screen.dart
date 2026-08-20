import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/board_markup.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/hint_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _timer;
  GameState? _gameState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gameState = context.read<GameState>();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _gameState?.updateTimer();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数独游戏'),
        actions: [
          // 计时器
          Consumer<GameState>(
            builder: (context, gameState, child) {
              final scheme = Theme.of(context).colorScheme;
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        gameState.getFormattedTime(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 更多选项
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'validate',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 8),
                    Text('验证答案'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'autofill',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high),
                    SizedBox(width: 8),
                    Text('自动填充候选'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('重新开始'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            if (gameState.board == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_off_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '请先开始游戏',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              );
            }

            if (gameState.justCompleted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                gameState.consumeCompletionFlag();
                _showVictoryDialog(context, gameState);
              });
            }

            if (gameState.conjugateNotice != null) {
              final notice = gameState.conjugateNotice!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                gameState.clearConjugateNotice();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(notice),
                    duration: const Duration(seconds: 2),
                  ),
                );
              });
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    // 信息栏
                    _buildInfoBar(gameState),

                    const SizedBox(height: 12),

                    // 数独棋盘
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Center(
                          child: SudokuGrid(
                            board: gameState.board!,
                            selectedRow: gameState.selectedRow,
                            selectedCol: gameState.selectedCol,
                            showCandidates: gameState.showCandidates ||
                                gameState.markupEnabled,
                            conflictCells: gameState.getConflictCells(),
                            markup: gameState.displayMarkup,
                            sameDigitCells:
                                gameState.sameDigitHighlightCells(),
                            sameDigitCandidates:
                                gameState.sameDigitHighlightCandidates(),
                            arrowAnchor: gameState.arrowAnchor,
                            onCellTap: (row, col) {
                              gameState.onCellTap(row, col);
                            },
                            onCandidateTap: gameState.markupEnabled
                                ? gameState.onCandidateMarkupTap
                                : null,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_hintPanelVisible(gameState)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildHintPanel(gameState),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 控制按钮
                    _buildControlButtons(gameState),

                    const SizedBox(height: 12),

                    // 数字键盘
                    _buildNumberPad(gameState),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoBar(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.signal_cellular_alt,
                  label: '难度',
                  value: _getDifficultyName(gameState.difficulty),
                ),
              ),
              _infoDivider(),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.lightbulb_outline,
                  label: '提示',
                  value: '${gameState.hintsUsed}',
                ),
              ),
              _infoDivider(),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.emoji_events_outlined,
                  label: '得分',
                  value: gameState.board!.isComplete()
                      ? '${gameState.getScore()}'
                      : '--',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }

  Widget _buildControlButtons(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // 第一行：基础控制按钮
          Row(
            children: [
              _buildControlButton(
                icon: Icons.undo,
                label: '撤销',
                onPressed: gameState.canUndo ? () => gameState.undo() : null,
              ),
              _buildControlButton(
                icon: Icons.redo,
                label: '重做',
                onPressed: gameState.canRedo ? () => gameState.redo() : null,
              ),
              _buildControlButton(
                icon: Icons.lightbulb_outline,
                label: '提示',
                onPressed: () => _showHint(context, gameState),
              ),
              _buildControlButton(
                icon: Icons.backspace_outlined,
                label: '清除',
                onPressed: gameState.selectedRow != null
                    ? () => gameState.clearSelected()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：候选数功能按钮
          Row(
            children: [
              _buildControlButton(
                icon: gameState.showCandidates
                    ? Icons.visibility
                    : Icons.visibility_off,
                label: gameState.showCandidates ? '隐藏候选' : '显示候选',
                onPressed: () => gameState.toggleShowCandidates(),
                active: gameState.showCandidates,
              ),
              _buildControlButton(
                icon: Icons.edit_note,
                label: gameState.candidateMode ? '填数模式' : '笔记模式',
                onPressed: () => gameState.toggleCandidateMode(),
                active: gameState.candidateMode,
              ),
              _buildControlButton(
                icon: gameState.markupEnabled
                    ? Icons.palette
                    : Icons.palette_outlined,
                label: gameState.markupEnabled ? '标记中' : '标记',
                onPressed: () => gameState.toggleMarkupEnabled(),
                active: gameState.markupEnabled,
              ),
            ],
          ),
          if (gameState.markupEnabled) ...[
            const SizedBox(height: 10),
            _buildMarkupBar(gameState),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkupBar(GameState gameState) {
    Widget modeChip(String label, MarkupMode mode) {
      final selected = gameState.markupMode == mode;
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: Colors.black,
        checkmarkColor: Colors.white,
        onSelected: (_) => gameState.setMarkupMode(mode),
      );
    }

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            modeChip('格色', MarkupMode.cellColor),
            modeChip('候选色', MarkupMode.candidateColor),
            modeChip('强链', MarkupMode.strong),
            modeChip('弱链', MarkupMode.weak),
            modeChip('自动共轭', MarkupMode.autoConjugate),
            modeChip('关闭', MarkupMode.off),
            ActionChip(
              avatar: const Icon(Icons.layers_clear_outlined, size: 16),
              label: const Text('清除标记'),
              onPressed: () => gameState.clearUserMarkup(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final color in MarkupPalette.colors)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => gameState.setMarkupColor(color),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: gameState.markupColor == color
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (gameState.arrowAnchor != null) ...[
          const SizedBox(height: 6),
          Text(
            '已选起点，再点终点',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ] else if (gameState.markupMode == MarkupMode.candidateColor) ...[
          const SizedBox(height: 6),
          Text(
            '选格后点数字上色',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final Color background;
    final Color foreground;
    if (!enabled) {
      background = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
      foreground = scheme.onSurfaceVariant.withValues(alpha: 0.38);
    } else if (active) {
      background = Colors.black;
      foreground = Colors.white;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: List.generate(9, (index) {
          return _buildNumberButton(index + 1, gameState);
        }),
      ),
    );
  }

  Widget _buildNumberButton(int number, GameState gameState) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = gameState.isNumberPadEnabled(number);
    final noteMode =
        gameState.markupMode == MarkupMode.off && gameState.candidateMode;

    final Color background;
    final Color foreground;
    if (!isEnabled) {
      background = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
      foreground = scheme.onSurfaceVariant.withValues(alpha: 0.38);
    } else if (noteMode) {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    } else {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? () => gameState.onNumberPad(number) : null,
            child: SizedBox(
              height: 50,
              child: Center(
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDifficultyName(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '简单';
      case 'medium':
        return '中等';
      case 'hard':
        return '困难';
      case 'expert':
        return '专家';
      default:
        return '自定义';
    }
  }

  bool _hintPanelVisible(GameState gameState) {
    final phase = gameState.hintSession?.phase ?? HintPhase.none;
    return phase != HintPhase.none;
  }

  Widget _buildHintPanel(GameState gameState) {
    final session = gameState.hintSession!;
    switch (session.phase) {
      case HintPhase.offerDeep:
        return HintPanel(
          title: '这一步需要更深的推理',
          body: '用到目前的全部技巧后，还找不到可以填数或删除的候选。'
              '可以进行一次更深的搜索（更长的链、更大的假设网），可能会稍慢。是否继续？',
          cancelLabel: '先自己想',
          actionLabel: '深度搜索',
          onCancel: () => gameState.clearHintMarkup(),
          onApply: () => gameState.requestDeepSearch(),
        );
      case HintPhase.failed:
        return HintPanel(
          title: '未能找到下一步',
          body: '在限定深度内没有推出新的填数或删除。可以检查已填数字是否有误，或换一题继续练习。',
          cancelLabel: '知道了',
          onCancel: () => gameState.clearHintMarkup(),
        );
      case HintPhase.ready:
        final hint = session.hint!;
        final isElim = hint.isElimination;
        final title = session.fromDeepSearch
            ? '${hint.technique}（深度搜索）'
            : hint.technique;
        final detail = isElim
            ? '将删除 ${hint.eliminations.length} 个候选数'
            : '位置：第 ${hint.row + 1} 行，第 ${hint.col + 1} 列'
                '${hint.value > 0 ? '\n数字：${hint.value}' : ''}';
        return HintPanel(
          title: title,
          body: '${hint.explanation}\n\n$detail',
          actionLabel: isElim ? '应用删除' : '应用本步',
          onCancel: () => gameState.clearHintMarkup(),
          onApply: () => gameState.applyHint(hint),
        );
      case HintPhase.none:
        return const SizedBox.shrink();
    }
  }

  void _showHint(BuildContext context, GameState gameState) {
    final phase = gameState.hintSession?.phase ?? HintPhase.none;
    if (phase != HintPhase.none) return;
    gameState.getHint();
  }

  void _handleMenuAction(BuildContext context, String action) {
    final gameState = context.read<GameState>();

    switch (action) {
      case 'validate':
        final hasConflicts = gameState.getConflictCells().isNotEmpty;
        final isCorrect = gameState.validate();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isCorrect ? '正确' : '有误'),
            content: Text(
              isCorrect
                  ? '目前已填数字均与唯一解一致，继续加油！'
                  : hasConflicts
                      ? '存在同行/列/宫冲突，请检查红色高亮格子。'
                      : '当前无冲突，但有数字与正确解不一致。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        break;

      case 'reset':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('重新开始'),
            content: const Text('确定要清除所有填写的数字吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  gameState.resetGame();
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
        break;

      case 'autofill':
        _showAutoFillDialog(context, gameState);
        break;
    }
  }

  void _showVictoryDialog(BuildContext context, GameState gameState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恭喜完成！'),
        content: Text(
          '用时 ${gameState.getFormattedTime()}\n'
          '提示 ${gameState.hintsUsed} 次\n'
          '得分 ${gameState.getScore()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showAutoFillDialog(BuildContext context, GameState gameState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动填充候选数'),
        content: const Text('自动为所有空格填充可能的候选数字。\n\n'
            '这将覆盖您手动设置的候选数，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              gameState.autoFillCandidates();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已自动填充所有候选数'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
