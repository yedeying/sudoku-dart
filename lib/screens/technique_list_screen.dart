import 'package:flutter/material.dart';
import '../models/technique_catalog.dart';
import 'technique_detail_screen.dart';

class TechniqueListScreen extends StatelessWidget {
  const TechniqueListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = TechniqueCatalog.all;
    return Scaffold(
      appBar: AppBar(title: const Text('技巧说明')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final t = items[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(t.name),
            subtitle: Text(
              t.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TechniqueDetailScreen(info: t),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
