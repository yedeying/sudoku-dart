import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_catalog.dart';

/// 评审总表的路径。表里那一列「状态」讲的就是引擎有没有独立报法，
/// 也就是 [TechniqueInfo.teachingOnly] 的反面；两边对不上就是文档过期了。
const _reviewDoc = 'docs/techniques.md';

/// 解析总表：`| 档 | 名称 | 状态 | 难度 | 实现 | 可行 | 说明 |`。
Map<String, String> _statusByName(String markdown) {
  final rows = <String, String>{};
  for (final line in markdown.split('\n')) {
    if (!line.startsWith('|')) continue;
    final cells = [
      for (final cell in line.split('|').sublist(1)) cell.trim(),
    ];
    if (cells.length < 7) continue;
    final name = cells[1];
    final status = cells[2];
    if (status != '有' && status != '无') continue;
    rows[name] = status;
  }
  return rows;
}

void main() {
  test('评审总表的「状态」和技巧目录的 teachingOnly 一一对上', () {
    final markdown = File(_reviewDoc).readAsStringSync();
    final status = _statusByName(markdown);

    // 解析真的读到了东西，格式一变就会在这里先炸，而不是悄悄放空。
    expect(
      status.length,
      greaterThan(60),
      reason: '总表应当解析出几十行；行数太少多半是表格格式变了',
    );

    final catalogNames = {for (final t in TechniqueCatalog.all) t.name};
    expect(
      status.keys.toSet().difference(catalogNames),
      isEmpty,
      reason: '总表里的名称都应当能在技巧目录里找到同名条目',
    );
    expect(
      catalogNames.difference(status.keys.toSet()),
      isEmpty,
      reason: '技巧目录里的每一条都应当在总表里有一行',
    );

    final mismatched = <String>[
      for (final tech in TechniqueCatalog.all)
        if ((status[tech.name] == '有') == tech.teachingOnly)
          '${tech.name}: 总表写 ${status[tech.name]}，'
              'teachingOnly=${tech.teachingOnly}'
    ];
    expect(
      mismatched,
      isEmpty,
      reason: '状态「有」必须正好等于引擎有独立报法（teachingOnly 为假）',
    );
  });
}
