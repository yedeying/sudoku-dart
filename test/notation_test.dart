import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/notation.dart';

void main() {
  test('格子和候选用 Hodoku 记号', () {
    expect(cellRef(2, 4), 'r3c5');
    expect(candRef(2, 4, 6), '6r3c5');
    expect(rowRef(2), 'r3');
    expect(colRef(4), 'c5');
    expect(boxRef(0, 0), 'b1');
    expect(boxRef(2, 2), 'b9');
  });

  test('填数和删除结论行', () {
    expect(fillLine(2, 4, 8), '填 r3c5=8');
    expect(
      elimLine(const [
        (row: 0, col: 1, digit: 6),
        (row: 0, col: 4, digit: 6),
      ]),
      '删 6r1c2, 6r1c5',
    );
  });

  test('链表达式用 = 强链和 - 弱链', () {
    const arrows = [
      MarkupArrow(
        from: CandidateRef(2, 4, 6),
        to: CandidateRef(2, 7, 6),
        kind: ArrowKind.strong,
      ),
      MarkupArrow(
        from: CandidateRef(2, 7, 6),
        to: CandidateRef(6, 7, 6),
        kind: ArrowKind.weak,
      ),
      MarkupArrow(
        from: CandidateRef(6, 7, 6),
        to: CandidateRef(6, 4, 6),
        kind: ArrowKind.strong,
      ),
    ];
    expect(chainExpr(arrows), '6r3c5 = 6r3c8 - 6r7c8 = 6r7c5');
  });
}
