import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/board_markup.dart';
import '../models/notation.dart';
import '../models/technique_catalog.dart';
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
          IconButton(
            tooltip: '强调色',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => AccentPicker.open(context),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Text('一键复制'),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Text('重新开始'),
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
                _buildInfoBar(gameState),
                // 用 Expanded 把「信息条已经占掉的高度」让 LayoutBuilder
                // 直接量出来，棋盘按剩余宽高算尺寸，不再只看宽度——
                // 矮宽的横屏视口下才不会把控制区挤到溢出。
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, boardArea) {
                      const topPadding = 8.0;
                      final side = math
                          .min(
                            math.min(boardArea.maxWidth - 32, 560.0),
                            boardArea.maxHeight - topPadding,
                          )
                          .clamp(0.0, double.infinity);
                      // 提示抽屉最高只能到棋盘下沿，避免盖住盘面。
                      final belowBoard =
                          (boardArea.maxHeight - topPadding - side)
                              .clamp(0.0, double.infinity);
                      return Stack(
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, topPadding, 16, 0),
                                child: SizedBox(
                                  width: side,
                                  height: side,
                                  child: SudokuGrid(
                                    board: gameState.board!,
                                    selectedRow: gameState.displaySelectedRow,
                                    selectedCol: gameState.displaySelectedCol,
                                    showCandidates: gameState.showCandidates,
                                    conflictCells: gameState.getConflictCells(),
                                    markup: gameState.displayMarkup,
                                    sameDigitCells:
                                        gameState.sameDigitHighlightCells(),
                                    sameDigitCandidates: gameState
                                        .sameDigitHighlightCandidates(),
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
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _buildControlButtons(gameState),
                                      const SizedBox(height: 8),
                                      _buildNumberPad(gameState),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_hintPanelVisible(gameState))
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Material(
                                elevation: 8,
                                child: _buildHintPanel(
                                  gameState,
                                  maxHeight: belowBoard,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
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
            icon: Icons.timer_outlined,
            label: '用时',
            value: gameState.getFormattedTime(),
          ),
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
              _buildControlButton(
                icon: Icons.flash_on_outlined,
                label: '快速填充',
                onPressed: () => _applySimpleFills(context),
              ),
            ],
          ),
          if (gameState.markupEnabled) ...[
            const SizedBox(height: 8),
            _buildMarkupBar(gameState),
          ] else ...[
            const SizedBox(height: 8),
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
          ],
        ],
      ),
    );
  }

  Widget _buildMarkupBar(GameState gameState) {
    final scheme = Theme.of(context).colorScheme;

    Widget modeChip(String label, MarkupMode mode) {
      final selected = gameState.markupMode == mode;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: selected,
          showCheckmark: false,
          selectedColor: scheme.primary,
          onSelected: (_) => gameState.setMarkupMode(mode),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          modeChip('格色', MarkupMode.cellColor),
          modeChip('候选色', MarkupMode.candidateColor),
          modeChip('强链', MarkupMode.strong),
          modeChip('弱链', MarkupMode.weak),
          modeChip('自动强链', MarkupMode.autoStrong),
          for (final color in MarkupPalette.colors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
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
          ActionChip(
            label: const Text('清除标记', style: TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: () => gameState.clearUserMarkup(),
          ),
        ],
      ),
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

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: active
                  ? BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(icon, size: 28, color: iconColor),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? scheme.onSurface : disabled,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildHintPanel(GameState gameState, {double? maxHeight}) {
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
          maxHeight: maxHeight,
        );
      case HintPhase.failed:
        return HintPanel(
          title: '未能找到下一步',
          body: '在限定深度内没有推出新的填数或删除。可以检查已填数字是否有误，或换一题继续练习。',
          cancelLabel: '知道了',
          onCancel: () => gameState.clearHintMarkup(),
          maxHeight: maxHeight,
        );
      case HintPhase.ready:
        final hint = session.hint!;
        final isElim = hint.isElimination;
        final title =
            session.fromDeepSearch ? '${hint.technique}（深度搜索）' : hint.technique;
        final chain = hint.links.isEmpty ? '' : '\n${chainExpr(hint.links)}';
        final detail = isElim
            ? elimLine(hint.eliminations
                .map((e) => (row: e.row, col: e.col, digit: e.num)))
            : fillLine(hint.row, hint.col, hint.value);
        return HintPanel(
          title: title,
          body: '${hint.explanation}$chain\n\n$detail',
          definition: TechniqueCatalog.byName(hint.technique)?.definition,
          actionLabel: isElim ? '应用删除' : '应用本步',
          onCancel: () => gameState.clearHintMarkup(),
          onApply: () => gameState.applyHintAndAdvance(hint),
          maxHeight: maxHeight,
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
      case 'copy':
        _copyPuzzle(context);
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
    }
  }

  Future<void> _copyPuzzle(BuildContext context) async {
    final text = context.read<GameState>().exportPuzzle();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制残局'), duration: Duration(seconds: 2)),
    );
  }

  void _applySimpleFills(BuildContext context) {
    final gameState = context.read<GameState>();
    final n = gameState.applySimpleFills(includeHiddenSingle: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n == 0 ? '没有可填的唯余或摒除' : '已用唯余/摒除填写 $n 格'),
        duration: const Duration(seconds: 2),
      ),
    );
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
}
