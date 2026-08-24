import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/screens/technique_detail_screen.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

void main() {
  testWidgets('技巧详情展示棋盘、图例和四个说明分区', (tester) async {
    final info = TechniqueCatalog.all.first;
    await tester.pumpWidget(MaterialApp(home: TechniqueDetailScreen(info: info)));
    expect(find.byType(SudokuGrid), findsOneWidget);
    expect(find.text('本例怎么推'), findsOneWidget);
    expect(find.text('技巧定义'), findsOneWidget);
    expect(find.text('识别方法'), findsOneWidget);
    expect(find.text('注意事项'), findsOneWidget);
    expect(find.text(info.legend.first.label), findsOneWidget);
  });
}
