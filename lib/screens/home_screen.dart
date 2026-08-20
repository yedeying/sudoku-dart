import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import 'game_screen.dart';
import 'input_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo 和标题
                    Icon(
                      Icons.grid_4x4,
                      size: 100,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '数独游戏',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sudoku Master',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 48),

                    // 难度选择卡片
                    _buildDifficultyCard(
                      context,
                      title: '简单',
                      subtitle: '只需基础技巧，适合新手',
                      icon: Icons.sentiment_satisfied,
                      color: Colors.green,
                      difficulty: 'easy',
                    ),
                    const SizedBox(height: 16),
                    _buildDifficultyCard(
                      context,
                      title: '中等',
                      subtitle: '需要中级技巧，挑战思维',
                      icon: Icons.sentiment_neutral,
                      color: Colors.orange,
                      difficulty: 'medium',
                    ),
                    const SizedBox(height: 16),
                    _buildDifficultyCard(
                      context,
                      title: '困难',
                      subtitle: '需要 X-Wing 等高级技巧',
                      icon: Icons.sentiment_dissatisfied,
                      color: Colors.red,
                      difficulty: 'hard',
                    ),
                    const SizedBox(height: 16),
                    _buildDifficultyCard(
                      context,
                      title: '专家',
                      subtitle: '需要 XY-Wing 等专家技巧',
                      icon: Icons.psychology,
                      color: Colors.purple,
                      difficulty: 'expert',
                    ),
                    const SizedBox(height: 32),

                    // 自定义输入按钮
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InputScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('手动输入题目'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String difficulty,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final gameState = Provider.of<GameState>(context, listen: false);

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在生成题目...'),
                    ],
                  ),
                ),
              ),
            ),
          );

          // 让 loading 先绘制一帧，再在后台排队生成
          await Future<void>.delayed(Duration.zero);
          await Future<void>(() => gameState.startNewGame(difficulty));

          if (!context.mounted) return;
          Navigator.pop(context); // 关闭 loading

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GameScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
