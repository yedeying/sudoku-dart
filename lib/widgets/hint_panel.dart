import 'package:flutter/material.dart';

/// 棋盘下方的提示卡片：技巧说明 + 取消 / 应用。
class HintPanel extends StatelessWidget {
  final String title;
  final String body;
  final String cancelLabel;
  final String? actionLabel;
  final VoidCallback onCancel;
  final VoidCallback? onApply;

  /// 卡片整体高度上限；不传时退化为屏幕高度的一半。
  /// 超出这个高度的正文改为在卡片内部滚动，而不是把卡片撑高盖住棋盘。
  final double? maxHeight;

  const HintPanel({
    super.key,
    required this.title,
    required this.body,
    this.cancelLabel = '取消',
    this.actionLabel,
    required this.onCancel,
    this.onApply,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cap = maxHeight ?? MediaQuery.of(context).size.height * 0.5;
    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: cap),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(body, style: theme.textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: Text(cancelLabel),
                  ),
                  if (actionLabel != null && onApply != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onApply,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
