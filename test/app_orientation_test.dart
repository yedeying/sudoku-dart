import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/app_orientation.dart';

void main() {
  test('移动端只锁定竖屏', () {
    expect(AppOrientation.portraits, [DeviceOrientation.portraitUp]);
  });
}
