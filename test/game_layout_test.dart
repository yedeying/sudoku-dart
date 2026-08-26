import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/widgets/hint_panel.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

const _classic = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

Future<void> _pumpGame(WidgetTester tester, GameState state) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GameState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const GameScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('提示出现前后棋盘高度不变', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);
    final before = tester.getSize(find.byType(SudokuGrid));
    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();
    final after = tester.getSize(find.byType(SudokuGrid));
    expect(after, before);
    expect(
        find.text('应用删除').evaluate().isNotEmpty ||
            find.text('应用本步').evaluate().isNotEmpty ||
            find.text('应用').evaluate().isNotEmpty,
        isTrue);
  });

  testWidgets('矮宽视口（横屏手机）下棋盘不溢出', (tester) async {
    // 典型横屏手机：宽远大于高，高度只够勉强放下信息条 + 方形棋盘。
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    // 出现 RenderFlex 溢出等布局异常时 takeException 会捕获到 FlutterError。
    expect(tester.takeException(), isNull);

    final boardSize = tester.getSize(find.byType(SudokuGrid));
    // 棋盘应保持正方形，且没有把自己撑到超出物理视口高度。
    expect(boardSize.width, closeTo(boardSize.height, 0.5));
    expect(boardSize.height, lessThanOrEqualTo(390));
  });

  testWidgets('提示抽屉顶边不低于棋盘下沿', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);
    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();

    final boardBottom = tester.getBottomLeft(find.byType(SudokuGrid)).dy;
    final panelTop = tester.getTopLeft(find.byType(HintPanel)).dy;
    expect(panelTop + 0.5, greaterThanOrEqualTo(boardBottom));
  });

  testWidgets('工具栏先功能后撤销，标记中收起撤销行', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    expect(
      tester.getTopLeft(find.text('标记')).dy,
      lessThan(tester.getTopLeft(find.text('撤销')).dy),
    );
    expect(find.text('关闭'), findsNothing);

    await tester.tap(find.text('标记'));
    await tester.pump();

    expect(find.text('标记中'), findsOneWidget);
    expect(find.text('撤销'), findsNothing);
    expect(find.text('关闭'), findsNothing);
    expect(find.text('格色'), findsOneWidget);
    expect(find.text('清除标记'), findsOneWidget);
  });
}
