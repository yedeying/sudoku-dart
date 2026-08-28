import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/screens/technique_detail_screen.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

void main() {
  testWidgets('技巧详情展示棋盘、图例和四个说明分区', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final info = TechniqueCatalog.all.first;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameState(),
        child: MaterialApp(home: TechniqueDetailScreen(info: info)),
      ),
    );
    expect(find.byType(SudokuGrid), findsOneWidget);
    expect(find.text('本例推导'), findsOneWidget);
    expect(find.text('技巧定义'), findsOneWidget);
    expect(find.text('识别方法'), findsOneWidget);
    expect(find.text('注意事项'), findsOneWidget);
    expect(find.text(info.legend.first.label), findsOneWidget);
    expect(find.byTooltip('复制例题'), findsOneWidget);
    expect(find.byTooltip('用此盘对局'), findsOneWidget);
    expect(find.text('复制例题'), findsNothing);
  });

  testWidgets('播放按钮直接打开棋盘', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = GameState();
    final info = TechniqueCatalog.all.first;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: game,
        child: MaterialApp(home: TechniqueDetailScreen(info: info)),
      ),
    );
    await tester.tap(find.byTooltip('用此盘对局'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(TechniqueDetailScreen), findsNothing);
    expect(game.board, isNotNull);
    expect(game.board!.toStringRepresentation(), info.examplePuzzle);
    expect(game.showCandidates, isTrue);
    expect(game.requestedShellIndex, 0);
  });

  test('Nice Loop 复制的是练习原题而不是示意图', () {
    final info = TechniqueCatalog.all.firstWhere((t) => t.id == 'nice_loop');
    expect(info.copiesPracticeBoard, isTrue);
    expect(info.copyPuzzle, TechniqueCatalog.practicePuzzles['nice_loop']);
    expect(info.copyPuzzle, isNot(info.examplePuzzle));
  });
}
