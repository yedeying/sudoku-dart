import 'package:flutter/material.dart';

/// 棋盘下方的提示卡片：技巧说明 + 取消 / 应用。
class HintPanel extends StatelessWidget {
  final String title;
  final String body;
  final String cancelLabel;
  final String? actionLabel;
  final VoidCallback onCancel;
  final VoidCallback? onApply;

  const HintPanel({
    super.key,
    required this.title,
    required this.body,
    this.cancelLabel = '取消',
    this.actionLabel,
    required this.onCancel,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
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
    );
  }
}
