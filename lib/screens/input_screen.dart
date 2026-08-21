import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import 'game_screen.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final TextEditingController _controller = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动输入题目'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 说明
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '输入说明',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '请输入81个数字（从左到右，从上到下）：\n'
                            '• 1-9 表示已填入的数字\n'
                            '• 0 或 . 表示空格\n'
                            '• 可以包含空格和换行符（将被忽略）',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 示例
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text('查看示例'),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '530070000\n'
                          '600195000\n'
                          '098000060\n'
                          '800060003\n'
                          '400803001\n'
                          '700020006\n'
                          '060000280\n'
                          '000419005\n'
                          '000080079',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton.tonal(
                          onPressed: () {
                            _controller.text =
                                '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
                          },
                          child: const Text('使用此示例'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 输入框
                  TextField(
                    controller: _controller,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: '输入题目',
                      hintText: '请输入81个数字...',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      errorText: _errorMessage.isEmpty ? null : _errorMessage,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _errorMessage = '';
                            });
                          },
                          child: const Text('清除'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _loadPuzzle,
                          child: const Text('开始游戏'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 快速示例按钮
                  Text(
                    '快速加载示例：',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildExampleChip(
                        '简单示例',
                        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
                      ),
                      _buildExampleChip(
                        '中等示例',
                        '200080300060070084030500209000105408000000000402706000301007040720040060004010003',
                      ),
                      _buildExampleChip(
                        '困难示例',
                        '000000907000420180000705026100904000050000040000507009920108000034059000507000000',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExampleChip(String label, String puzzle) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _controller.text = puzzle;
        setState(() {
          _errorMessage = '';
        });
      },
    );
  }

  void _loadPuzzle() {
    // 清理输入（移除空格、换行符等）
    String input =
        _controller.text.replaceAll(RegExp(r'\s'), '').replaceAll('.', '0');

    // 验证长度
    if (input.length != 81) {
      setState(() {
        _errorMessage = '必须输入81个字符（当前：${input.length}）';
      });
      return;
    }

    // 验证字符
    if (!RegExp(r'^[0-9]{81}$').hasMatch(input)) {
      setState(() {
        _errorMessage = '只能包含数字 0-9';
      });
      return;
    }

    // 加载游戏
    try {
      final gameState = Provider.of<GameState>(context, listen: false);
      gameState.loadCustomGame(input);

      // 导航到游戏界面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const GameScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败：$e';
      });
    }
  }
}
