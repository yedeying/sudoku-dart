import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/board_markup.dart';
import '../services/sudoku_solver.dart';
import '../widgets/accent_picker.dart';
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        gameState.getFormattedTime(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '强调色',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => AccentPicker.open(context),
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
              return const Center(child: Text('请先开始游戏'));
            }

            if (gameState.justCompleted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                gameState.consumeCompletionFlag();
                _showVictoryDialog(context, gameState);
              });
            }

            if (gameState.autoStrongNotice != null) {
              final notice = gameState.autoStrongNotice!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                gameState.clearAutoStrongNotice();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(notice),
                    duration: const Duration(seconds: 2),
                  ),
                );
              });
            }

            return Column(
              children: [
                // 信息栏
                _buildInfoBar(gameState),
                
                const SizedBox(height: 16),

                // 数独棋盘
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SudokuGrid(
                        board: gameState.board!,
                        selectedRow: gameState.displaySelectedRow,
                        selectedCol: gameState.displaySelectedCol,
                        // 候选显示只受这个视图开关控制；标记和提示不能偷偷打开。
                        showCandidates: gameState.showCandidates,
                        conflictCells: gameState.getConflictCells(),
                        markup: gameState.displayMarkup,
                        sameDigitCells: gameState.sameDigitHighlightCells(),
                        sameDigitCandidates:
                            gameState.sameDigitHighlightCandidates(),
                        arrowAnchor: gameState.arrowAnchor,
                        onCellTap: (row, col) {
                          gameState.onCellTap(row, col);
                        },
                        onCandidateTap: gameState.markupEnabled
                            ? gameState.onCandidateTap
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_hintPanelVisible(gameState)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildHintPanel(gameState),
                  ),
                  const SizedBox(height: 12),
                ],

                // 控制按钮
                _buildControlButtons(gameState),

                const SizedBox(height: 8),

                // 数字键盘
                _buildNumberPad(gameState),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoBar(GameState gameState) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(16),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Icons.signal_cellular_alt,
            label: '难度',
            value: _getDifficultyName(gameState.difficulty),
          ),
          _buildInfoItem(
            icon: Icons.help_outline,
            label: '提示',
            value: '${gameState.hintsUsed}',
          ),
          _buildInfoItem(
            icon: Icons.stars,
            label: '得分',
            value: gameState.board!.isComplete()
                ? '${gameState.getScore()}'
                : '--',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                icon: _readyHint(gameState) != null
                    ? Icons.check
                    : Icons.lightbulb,
                label: _readyHint(gameState) != null ? '应用' : '提示',
                active: _readyHint(gameState) != null,
                onPressed: () {
                  final ready = _readyHint(gameState);
                  if (ready != null) {
                    gameState.applyHintAndAdvance(ready);
                  } else {
                    _showHint(context, gameState);
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.clear,
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
            const SizedBox(height: 8),
            _buildMarkupBar(gameState),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkupBar(GameState gameState) {
    final scheme = Theme.of(context).colorScheme;

    Widget modeChip(String label, MarkupMode mode) {
      final selected = gameState.markupMode == mode;
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: scheme.primary,
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
            modeChip('自动强链', MarkupMode.autoStrong),
            modeChip('关闭', MarkupMode.off),
            ActionChip(
              label: const Text('清除标记'),
              onPressed: () => gameState.clearUserMarkup(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final color in MarkupPalette.colors)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                            ? scheme.onSurface
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
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ] else if (gameState.markupMode == MarkupMode.candidateColor) ...[
          const SizedBox(height: 6),
          Text(
            '直接点棋盘上的候选数字上色',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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
    final disabled = scheme.onSurface.withValues(alpha: 0.38);

    final Color iconColor;
    if (!enabled) {
      iconColor = disabled;
    } else if (active) {
      iconColor = scheme.onPrimary;
    } else {
      iconColor = scheme.onSurfaceVariant;
    }

    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: iconColor,
          style: active
              ? IconButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                )
              : null,
          iconSize: 28,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? scheme.onSurface : disabled,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberPad(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(9, (index) {
          int number = index + 1;
          return _buildNumberButton(number, gameState);
        }),
      ),
    );
  }

  Widget _buildNumberButton(int number, GameState gameState) {
    final isEnabled = gameState.isNumberPadEnabled(number);
    final noteMode =
        gameState.markupMode == MarkupMode.off && gameState.candidateMode;

    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (!isEnabled) {
      background = scheme.surfaceContainerHigh;
      foreground = scheme.onSurface.withValues(alpha: 0.38);
    } else if (noteMode) {
      // 笔记模式用容器色区分，避免和填数模式的实心强调色混淆。
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    } else {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    }

    return InkWell(
      onTap: isEnabled ? () => gameState.onNumberPad(number) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: foreground,
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

  /// 当前是否有可直接应用的提示（用于把「提示」键切成「应用」）。
  SudokuHint? _readyHint(GameState gameState) {
    final session = gameState.hintSession;
    if (session == null || session.phase != HintPhase.ready) return null;
    return session.hint;
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
          onApply: () => gameState.applyHintAndAdvance(hint),
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
              ElevatedButton(
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
        content: const Text(
          '自动为所有空格填充可能的候选数字。\n\n'
          '这将覆盖您手动设置的候选数，确定要继续吗？'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
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
