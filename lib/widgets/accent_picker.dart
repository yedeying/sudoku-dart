import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_controller.dart';

const _labels = <AccentId, String>{
  AccentId.blue: '蓝',
  AccentId.teal: '青绿',
  AccentId.amber: '琥珀',
  AccentId.rose: '玫红',
};

class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key});

  static Future<void> open(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AccentPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return AlertDialog(
      title: const Text('强调色'),
      content: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final id in AccentId.values)
            _AccentSwatch(
              id: id,
              label: _labels[id]!,
              selected: controller.accentId == id,
              onTap: () async {
                await controller.setAccent(id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AccentId id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ThemeController.colorFor(id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
