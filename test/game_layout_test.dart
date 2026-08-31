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
    final panelBottom = tester.getBottomLeft(find.byType(HintPanel)).dy;
    final bodyBottom = tester.getBottomLeft(find.byType(SafeArea).first).dy;
    expect(panelTop + 0.5, greaterThanOrEqualTo(boardBottom));
    expect(panelBottom, closeTo(bodyBottom, 1));
    // 抽屉不得侵入棋盘；长文案在盘下区域内滚动，短文案由 HintPanel 自行收高。
    expect(
      tester.getSize(find.byType(HintPanel)).height,
      lessThanOrEqualTo(bodyBottom - boardBottom + 0.5),
    );
  });

  testWidgets('工具栏两行：候选标记撤销重做 / 笔记填充提示清除', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    final cand = tester.getCenter(find.text('显示候选'));
    final mark = tester.getCenter(find.text('标记'));
    final undo = tester.getCenter(find.text('撤销'));
    final redo = tester.getCenter(find.text('重做'));
    final note = tester.getCenter(find.text('笔记模式'));
    final fill = tester.getCenter(find.text('快速填充'));
    final hint = tester.getCenter(find.text('提示').last);
    final clear = tester.getCenter(find.text('清除'));
    expect(cand.dy, closeTo(mark.dy, 2));
    expect(mark.dy, closeTo(undo.dy, 2));
    expect(undo.dy, closeTo(redo.dy, 2));
    expect(note.dy, closeTo(fill.dy, 2));
    expect(fill.dy, closeTo(hint.dy, 2));
    expect(hint.dy, closeTo(clear.dy, 2));
    expect(cand.dx, lessThan(mark.dx));
    expect(mark.dx, lessThan(undo.dx));
    expect(undo.dx, lessThan(redo.dx));
    expect(note.dx, lessThan(fill.dx));
    expect(fill.dx, lessThan(hint.dx));
    expect(hint.dx, lessThan(clear.dx));
    expect(cand.dy, lessThan(note.dy));
    expect(find.text('关闭'), findsNothing);
    expect(
      tester.getTopLeft(find.byIcon(Icons.visibility_off)).dy -
          tester.getBottomLeft(find.byType(SudokuGrid)).dy,
      greaterThanOrEqualTo(12),
    );

    await tester.tap(find.text('标记'));
    await tester.pump();

    expect(find.text('标记中'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
    expect(find.text('笔记模式'), findsNothing);
    expect(find.text('快速填充'), findsNothing);
    expect(find.text('清除'), findsNothing);
    expect(find.text('关闭'), findsNothing);
    expect(find.text('格子'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-markup')), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('markup-color-row'))).dy,
      greaterThan(tester.getBottomLeft(find.text('格子')).dy),
    );

    final gapMode = tester.getTopLeft(find.text('格子')).dy -
        tester.getBottomLeft(find.text('标记中')).dy;
    final gapColor = tester
            .getTopLeft(find.byKey(const ValueKey('markup-color-row')))
            .dy -
        tester.getBottomLeft(find.text('格子')).dy;
    expect(gapMode, lessThan(32));
    expect(gapColor, lessThan(32));
    final chip = tester.getRect(find.byType(FilterChip).first);
    final label = tester.getRect(find.text('格子'));
    expect(label.left - chip.left, closeTo(10, 3));
    expect(chip.right - label.right, closeTo(10, 3));
  });

  testWidgets('矮屏标记工具栏一屏内显示数字区', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);
    await tester.tap(find.text('标记'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('格子'), findsOneWidget);
    final pad = tester.getRect(find.byKey(const ValueKey('number-pad')));
    final bodyBottom = tester.getBottomLeft(find.byType(SafeArea).first).dy;
    expect(pad.bottom, lessThanOrEqualTo(bodyBottom + 0.5));
    expect(pad.top, greaterThan(tester.getRect(find.byType(SudokuGrid)).bottom));
  });

  testWidgets('标题、棋盘、工具栏与底边均分空隙，工具栏内部固定边距', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    final info = tester.getRect(find.byKey(const ValueKey('info-bar')));
    final board = tester.getRect(find.byType(SudokuGrid));
    final pad = tester.getRect(find.byKey(const ValueKey('number-pad')));
    final tools = tester.getRect(find.byIcon(Icons.visibility_off));
    final bodyBottom = tester.getBottomLeft(find.byType(SafeArea).first).dy;
    final gapTitle = board.top - info.bottom;
    final gapBoard = tools.top - board.bottom;
    final gapBottom = bodyBottom - pad.bottom;
    expect(pad.width, lessThanOrEqualTo(board.width + 8));
    expect(gapTitle, closeTo(gapBoard, 20));
    expect(gapBottom, closeTo(gapTitle, 20));
    expect(gapBottom, greaterThan(24));
    expect(pad.top - tester.getRect(find.text('清除')).bottom, lessThan(32));
  });

  testWidgets('宽屏也走竖屏手机栏，数字区在棋盘下方且同行', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    final board = tester.getRect(find.byType(SudokuGrid));
    final pad = tester.getRect(find.byKey(const ValueKey('number-pad')));
    expect(board.width, lessThanOrEqualTo(430));
    expect(pad.width, lessThanOrEqualTo(board.width + 8));
    expect(pad.top, greaterThan(board.bottom));

    final n1 = tester.getCenter(find.byKey(const ValueKey('pad-1')));
    final n9 = tester.getCenter(find.byKey(const ValueKey('pad-9')));
    expect(n1.dy, closeTo(n9.dy, 1));
    expect(n9.dx, greaterThan(n1.dx + 8));
  });
}
