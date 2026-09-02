import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/puzzle_grade.dart';
import '../models/board_markup.dart';
import '../models/notation.dart';
import '../models/technique_catalog.dart';
import '../services/sudoku_solver.dart';
import '../widgets/accent_picker.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/app_notice.dart';
import '../widgets/hint_panel.dart';
import '../widgets/markup_mode_icon.dart';
import '../widgets/phone_frame.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _timer;
  GameState? _gameState;
  final FocusNode _focus = FocusNode();

  static final _digitKeys = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  static final _moveKeys = <LogicalKeyboardKey, (int, int)>{
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
    LogicalKeyboardKey.keyK: (-1, 0),
    LogicalKeyboardKey.keyJ: (1, 0),
    LogicalKeyboardKey.keyH: (0, -1),
    LogicalKeyboardKey.keyL: (0, 1),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gameState = context.read<GameState>();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _gameState?.updateTimer();
      });
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  bool _shiftDown() => HardwareKeyboard.instance.logicalKeysPressed.any(
        (k) =>
            k == LogicalKeyboardKey.shiftLeft ||
            k == LogicalKeyboardKey.shiftRight,
      );

  bool _shortcutDown() => HardwareKeyboard.instance.logicalKeysPressed.any(
        (k) =>
            k == LogicalKeyboardKey.metaLeft ||
            k == LogicalKeyboardKey.metaRight ||
            k == LogicalKeyboardKey.controlLeft ||
            k == LogicalKeyboardKey.controlRight,
      );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final gameState =
        _gameState ?? (context.mounted ? context.read<GameState>() : null);
    if (gameState == null) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (_shortcutDown()) {
      if (key == LogicalKeyboardKey.keyZ) {
        return gameState.handleUndoShortcut(redo: _shiftDown())
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.keyY) {
        return gameState.handleUndoShortcut(redo: true)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
    }
    final digit = _digitKeys[key];
    if (digit != null) {
      return gameState.handleDigitKey(digit, shift: _shiftDown())
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      return gameState.handleBackspace()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (_shiftDown()) return KeyEventResult.ignored;
    final move = _moveKeys[key];
    if (move != null) {
      return gameState.moveSelection(move.$1, move.$2)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      onBackgroundTap: () => context.read<GameState>().clearSelection(),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (_) {
            if (!_focus.hasFocus) _focus.requestFocus();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => context.read<GameState>().clearSelection(),
            child: Scaffold(
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
                        showAppNotice(context, notice);
                      });
                    }

                    return LayoutBuilder(
                      builder: (context, area) =>
                          _buildPlayArea(gameState, area),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayArea(GameState gameState, BoxConstraints area) {
    const topPad = 8.0;
    const reserved = 280.0;
    final short = area.maxHeight < 420;
    final boardSide = (short
            ? math.min(area.maxWidth - 32, area.maxHeight - topPad)
            : math.min(
                math.min(area.maxWidth - 32, PhoneFrame.maxWidth),
                math.max(area.maxHeight - topPad - reserved, 0),
              ))
        .clamp(0.0, PhoneFrame.maxWidth)
        .toDouble();
    Widget strip(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: boardSide),
            child: child,
          ),
        );
    const gap = SizedBox(height: 12);
    final title = _buildInfoBar(gameState);
    final board = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: SizedBox(
          width: boardSide,
          height: boardSide,
          child: _buildGrid(gameState),
        ),
      ),
    );
    final toolbar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        strip(_buildActionRow1(gameState)),
        gap,
        if (gameState.markupEnabled) ...[
          strip(_buildMarkupModes(gameState)),
          gap,
          strip(_buildMarkupColors(gameState)),
        ] else
          strip(_buildActionRow2(gameState)),
        gap,
        strip(_buildNumberPad(gameState)),
      ],
    );
    final hint = _hintPanelVisible(gameState)
        ? LayoutBuilder(
            builder: (context, box) {
              final cap = box.maxHeight.isFinite ? box.maxHeight : 200.0;
              return Material(
                elevation: 8,
                child: _buildHintPanel(gameState, maxHeight: cap),
              );
            },
          )
        : null;
    if (short) {
      return Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [title, board, toolbar],
            ),
          ),
          if (hint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: area.maxHeight.isFinite
                      ? area.maxHeight * 0.45
                      : 160,
                ),
                child: hint,
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        title,
        Expanded(
          child: CustomMultiChildLayout(
            delegate: _EvenPlayDelegate(boardSide: boardSide),
            children: [
              LayoutId(id: _PlaySlot.board, child: board),
              LayoutId(id: _PlaySlot.toolbar, child: toolbar),
              if (hint != null) LayoutId(id: _PlaySlot.hint, child: hint),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(GameState gameState) {
    return SudokuGrid(
      board: gameState.board!,
      selectedRow: gameState.displaySelectedRow,
      selectedCol: gameState.displaySelectedCol,
      showCandidates: gameState.showCandidates,
      conflictCells: gameState.getConflictCells(),
      conflictCandidates: gameState.candidateColorConflictRefs(),
      markup: gameState.displayMarkup,
      sameDigitCells: gameState.sameDigitHighlightCells(),
      sameDigitCandidates: gameState.sameDigitHighlightCandidates(),
      arrowAnchor: gameState.arrowAnchor,
      onCellTap: (row, col) {
        gameState.onCellTap(row, col);
      },
      onCandidateTap: gameState.markupEnabled ? gameState.onCandidateTap : null,
    );
  }

  Widget _buildInfoBar(GameState gameState) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      key: const ValueKey('info-bar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PhoneFrame.maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
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
                  value: _getDifficultyName(gameState),
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
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow1(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
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
            icon: gameState.markupEnabled
                ? Icons.palette
                : Icons.palette_outlined,
            label: gameState.markupEnabled ? '标记中' : '标记',
            onPressed: () => gameState.toggleMarkupEnabled(),
            active: gameState.markupEnabled,
          ),
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
        ],
      ),
    );
  }

  Widget _buildActionRow2(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
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
            icon: Icons.flash_on_outlined,
            label: '快速填充',
            onPressed: () => _applySimpleFills(context),
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
    );
  }

  Widget _buildMarkupModes(GameState gameState) {
    final scheme = Theme.of(context).colorScheme;

    Widget modeButton(MarkupMode mode) {
      final selected = gameState.markupMode == mode;
      final color = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
      return _markupCircleButton(
        key: ValueKey(MarkupModeIcon.keyOf(mode)),
        selected: selected,
        tooltip: MarkupModeIcon.labelOf(mode),
        onPressed: () => gameState.setMarkupMode(mode),
        child: MarkupModeIcon(
          mode: mode,
          color: color,
          size: switch (mode) {
            MarkupMode.candidateColor || MarkupMode.autoStrong => 26,
            _ => 22,
          },
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('markup-mode-row'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          modeButton(MarkupMode.cellColor),
          modeButton(MarkupMode.candidateColor),
          modeButton(MarkupMode.strong),
          modeButton(MarkupMode.weak),
          modeButton(MarkupMode.autoStrong),
          _markupCircleButton(
            key: const ValueKey('toggle-markup-visibility'),
            tooltip: gameState.markupHidden ? '显示标记' : '隐藏标记',
            onPressed: gameState.toggleMarkupHidden,
            child: Icon(
              gameState.markupHidden
                  ? Icons.visibility_off
                  : Icons.visibility,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ),
          _markupCircleButton(
            key: const ValueKey('clear-markup'),
            tooltip: '清除标记',
            onPressed: gameState.clearUserMarkup,
            child: Icon(
              Icons.close,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _markupCircleButton({
    required Key key,
    required Widget child,
    required VoidCallback onPressed,
    String? tooltip,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: child),
        ),
      ),
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.only(right: 6),
      child: tooltip == null ? button : Tooltip(message: tooltip, child: button),
    );
  }

  Widget _buildMarkupColors(GameState gameState) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('markup-color-row'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in MarkupPalette.colors)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => gameState.setMarkupColor(color),
              child: Container(
                width: 20,
                height: 20,
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
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: active ? 44 : 48,
                  height: active ? 44 : 48,
                  alignment: Alignment.center,
                  decoration: active
                      ? BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Icon(icon, size: 28, color: iconColor),
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: enabled ? scheme.onSurface : disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(GameState gameState) {
    final pad = LayoutBuilder(
      builder: (context, c) {
        final size = ((c.maxWidth - 8) / 9).clamp(24.0, 36.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 1; i <= 9; i++)
              _buildNumberButton(i, gameState, size: size),
          ],
        );
      },
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: KeyedSubtree(
        key: const ValueKey('number-pad'),
        child: pad,
      ),
    );
  }

  Widget _buildNumberButton(
    int number,
    GameState gameState, {
    double size = 36,
  }) {
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

    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DigitRemainDots(
            digit: number,
            count: gameState.remainingOf(number),
            color: scheme.primary,
            width: size,
          ),
          const SizedBox(height: 6),
          InkWell(
            key: ValueKey('pad-$number'),
            onTap: isEnabled ? () => gameState.onNumberPad(number) : null,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              width: size,
              height: size,
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
          ),
        ],
      ),
    );
  }

  String _getDifficultyName(GameState gameState) {
    return PuzzleGrades.titleOf(gameState.difficulty);
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
    ScaffoldMessenger.of(context).clearSnackBars();
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
    showAppNotice(context, '已复制残局');
  }

  void _applySimpleFills(BuildContext context) {
    final gameState = context.read<GameState>();
    final result = gameState.applySimpleFills(includeHiddenSingle: true);
    final extended = PuzzleGrades.extendsQuickFill(gameState.difficulty);
    final message = result.filled == 0 && result.eliminated == 0
        ? (extended ? '没有可填或可删的基础技巧' : '没有可填的唯余或摒除')
        : extended
            ? '已填写 ${result.filled} 格'
                '${result.eliminated == 0 ? '' : '，删除 ${result.eliminated} 处'}'
            : '已用唯余/摒除填写 ${result.filled} 格';
    showAppNotice(context, message);
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

enum _PlaySlot { board, toolbar, hint }

/// 标题以下：棋盘、工具栏、底边三段空隙均分。提示抽屉只占棋盘下方。
class _EvenPlayDelegate extends MultiChildLayoutDelegate {
  _EvenPlayDelegate({required this.boardSide});

  final double boardSide;

  @override
  void performLayout(Size size) {
    final toolbarSize = layoutChild(
      _PlaySlot.toolbar,
      BoxConstraints(
        maxWidth: size.width,
        maxHeight: math.max(0.0, size.height - boardSide),
      ),
    );
    final boardSize = layoutChild(
      _PlaySlot.board,
      BoxConstraints(maxWidth: size.width, maxHeight: boardSide),
    );
    final leftover = size.height - boardSize.height - toolbarSize.height;
    final gap = leftover / 3;
    final boardY = math.max(0.0, gap);
    final toolbarY = (boardY + boardSize.height + math.max(0.0, gap))
        .clamp(0.0, math.max(0.0, size.height - toolbarSize.height))
        .toDouble();
    positionChild(
      _PlaySlot.board,
      Offset((size.width - boardSize.width) / 2, boardY),
    );
    positionChild(_PlaySlot.toolbar, Offset(0, toolbarY));
    if (hasChild(_PlaySlot.hint)) {
      final shelf =
          (size.height - boardY - boardSize.height).clamp(0.0, size.height);
      final hintSize = layoutChild(
        _PlaySlot.hint,
        BoxConstraints(maxWidth: size.width, maxHeight: shelf),
      );
      positionChild(
        _PlaySlot.hint,
        Offset(0, size.height - hintSize.height),
      );
    }
  }

  @override
  bool shouldRelayout(covariant _EvenPlayDelegate oldDelegate) =>
      oldDelegate.boardSide != boardSide;
}

class _DigitRemainDots extends StatelessWidget {
  final int digit;
  final int count;
  final Color color;
  final double width;

  const _DigitRemainDots({
    required this.digit,
    required this.count,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final slot = width / 5;
    final dot = ((slot * 0.62).clamp(3.0, 6.0) - 2).clamp(2.0, 6.0);
    final pitch = (slot - 1).clamp(dot + 0.5, slot);
    return SizedBox(
      key: ValueKey('pad-$digit-remain'),
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 5; col++)
                  SizedBox(
                    width: pitch,
                    height: pitch,
                    child: Center(
                      child: (row * 5 + col) < count
                          ? DecoratedBox(
                              key: ValueKey('pad-$digit-dot-${row * 5 + col}'),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(
                                key: const ValueKey('remain-dot'),
                                width: dot,
                                height: dot,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
