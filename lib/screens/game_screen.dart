import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/board_markup.dart';
import '../widgets/sudoku_grid.dart';
import '../services/sudoku_solver.dart';

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
                        selectedRow: gameState.selectedRow,
                        selectedCol: gameState.selectedCol,
                        showCandidates: gameState.showCandidates ||
                            gameState.markupEnabled,
                        conflictCells: gameState.getConflictCells(),
                        markup: gameState.displayMarkup,
                        onCellTap: (row, col) {
                          gameState.selectCell(row, col);
                          if (gameState.markupEnabled) {
                            gameState.paintSelectedCell();
                          }
                        },
                        onCandidateTap: gameState.markupEnabled
                            ? gameState.onCandidateMarkupTap
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
                icon: Icons.lightbulb,
                label: '提示',
                onPressed: () => _showHint(context, gameState),
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
                color: gameState.showCandidates ? Colors.green : null,
              ),
              _buildControlButton(
                icon: Icons.edit_note,
                label: gameState.candidateMode ? '填数模式' : '笔记模式',
                onPressed: () => gameState.toggleCandidateMode(),
                color: gameState.candidateMode ? Colors.orange : null,
              ),
              _buildControlButton(
                icon: gameState.markupEnabled
                    ? Icons.palette
                    : Icons.palette_outlined,
                label: gameState.markupEnabled ? '标记中' : '标记',
                onPressed: () => gameState.toggleMarkupEnabled(),
                color: gameState.markupEnabled ? Colors.purple : null,
              ),
            ],
          ),
          if (gameState.markupEnabled) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  label: const Text('强箭头'),
                  onPressed: () => gameState.setPendingArrow(
                    gameState.pendingArrowKind == ArrowKind.strong
                        ? null
                        : ArrowKind.strong,
                  ),
                ),
                ActionChip(
                  label: const Text('弱箭头'),
                  onPressed: () => gameState.setPendingArrow(
                    gameState.pendingArrowKind == ArrowKind.weak
                        ? null
                        : ArrowKind.weak,
                  ),
                ),
                ActionChip(
                  label: const Text('共轭'),
                  onPressed: () => gameState.setPendingArrow(
                    gameState.pendingArrowKind == ArrowKind.conjugate
                        ? null
                        : ArrowKind.conjugate,
                  ),
                ),
                ActionChip(
                  label: const Text('画共轭'),
                  onPressed: () {
                    final cands = gameState.board?.getCandidates(
                          gameState.selectedRow ?? 0,
                          gameState.selectedCol ?? 0,
                        ) ??
                        {};
                    gameState.paintConjugates(cands.isEmpty ? 1 : cands.first);
                  },
                ),
                ActionChip(
                  label: const Text('清除标记'),
                  onPressed: () => gameState.clearUserMarkup(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: color ?? (onPressed != null ? Colors.blue : Colors.grey),
          iconSize: 28,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? Colors.black : Colors.grey,
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
    bool isEnabled = gameState.selectedRow != null &&
        gameState.selectedCol != null &&
        !gameState.board!
            .isInitial(gameState.selectedRow!, gameState.selectedCol!);

    return InkWell(
      onTap: isEnabled ? () => gameState.placeNumber(number) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.blue : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isEnabled ? Colors.white : Colors.grey.shade500,
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

  void _showHint(BuildContext context, GameState gameState) {
    var hint = gameState.getHint();
    if (hint == null) {
      _offerDeepSearch(context, gameState);
      return;
    }
    _showHintDialog(context, gameState, hint, fromDeepSearch: false);
  }

  void _offerDeepSearch(BuildContext context, GameState gameState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('这一步需要更深的推理'),
        content: const Text(
          '用到目前的全部技巧后，还找不到可以填数或删除的候选。'
          '可以进行一次更深的搜索（更长的链、更大的假设网），可能会稍慢。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('先自己想'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final deep = gameState.getHint(deep: true);
              if (deep == null) {
                _showHintFailed(context);
              } else {
                _showHintDialog(context, gameState, deep, fromDeepSearch: true);
              }
            },
            child: const Text('深度搜索'),
          ),
        ],
      ),
    );
  }

  void _showHintFailed(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未能找到下一步'),
        content: const Text(
          '在限定深度内没有推出新的填数或删除。可以检查已填数字是否有误，或换一题继续练习。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showHintDialog(
    BuildContext context,
    GameState gameState,
    SudokuHint hint, {
    required bool fromDeepSearch,
  }) {
    final isElim = hint.isElimination;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          fromDeepSearch ? '${hint.technique}（深度搜索）' : hint.technique,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint.explanation),
            const SizedBox(height: 16),
            Text(
              isElim
                  ? '将删除 ${hint.eliminations.length} 个候选数'
                  : '位置：第 ${hint.row + 1} 行，第 ${hint.col + 1} 列',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!isElim)
              Text(
                '数字：${hint.value}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontSize: 18,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameState.clearHintMarkup();
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              gameState.applyHint(hint);
              Navigator.pop(context);
            },
            child: Text(isElim ? '应用删除' : '应用本步'),
          ),
        ],
      ),
    );
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
