import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/theme/app_theme.dart';

const _classic = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('剩余待填 = 9 − 盘上已有该数字', () {
    final g = GameState()..loadCustomGame(_classic);
    expect(g.remainingOf(5), 6);
    expect(g.remainingOf(6), 4);
    expect(g.remainingOf(9), 5);
    g.selectCell(0, 2);
    g.placeNumber(1);
    expect(g.remainingOf(1), 5);
  });

  testWidgets('数字键头顶 2×5 点阵，6 个时上行 5、下行 1 且居左', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameState()..loadCustomGame(_classic),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pump();

    final remain = find.byKey(const ValueKey('pad-5-remain'));
    expect(remain, findsOneWidget);
    expect(find.descendant(of: remain, matching: find.byKey(const ValueKey('remain-dot'))),
        findsNWidgets(6));

    final d0 = tester.getCenter(find.byKey(const ValueKey('pad-5-dot-0')));
    final d4 = tester.getCenter(find.byKey(const ValueKey('pad-5-dot-4')));
    final d5 = tester.getCenter(find.byKey(const ValueKey('pad-5-dot-5')));
    expect(d0.dy, closeTo(d4.dy, 1));
    expect(d5.dy, greaterThan(d0.dy + 2));
    expect(d5.dx, closeTo(d0.dx, 1));
    expect(d4.dx, greaterThan(d0.dx));
    expect((d4.dx - d0.dx) / 4, closeTo(d5.dy - d0.dy, 1));

    final digit = tester.getCenter(
      find.descendant(of: find.byKey(const ValueKey('pad-5')), matching: find.text('5')),
    );
    final remainBottom = tester.getBottomLeft(remain).dy;
    expect(digit.dy, greaterThan(remainBottom));
    expect(
      tester.getTopLeft(find.descendant(of: find.byKey(const ValueKey('pad-5')), matching: find.text('5'))).dy - remainBottom,
      greaterThan(5),
    );

    final scheme = AppTheme.light().colorScheme;
    final dot = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('pad-5-dot-0')),
    );
    final deco = dot.decoration as BoxDecoration;
    expect(deco.color, scheme.primary);
    expect(deco.shape, BoxShape.circle);
  });

  testWidgets('数字键按下高亮只包数字方块，不包头顶小点', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameState()..loadCustomGame(_classic),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pump();

    final pad = tester.getRect(find.byKey(const ValueKey('pad-5')));
    final remain = tester.getRect(find.byKey(const ValueKey('pad-5-remain')));
    expect(pad.overlaps(remain), isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pad-5')),
        matching: find.byKey(const ValueKey('pad-5-remain')),
      ),
      findsNothing,
    );
  });
}
