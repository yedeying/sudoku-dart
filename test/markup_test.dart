import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';

void main() {
  List<List<Set<int>>> emptyCands() =>
      List.generate(9, (_) => List.generate(9, (_) => <int>{}));

  test('双值强链：同行恰两个该数字候选时合法', () {
    final cands = emptyCands();
    cands[0][1].add(5);
    cands[0][7].add(5);
    expect(
      BoardMarkup.isLegalConjugate(
        const CandidateRef(0, 1, 5),
        const CandidateRef(0, 7, 5),
        cands,
      ),
      isTrue,
    );
  });

  test('双值强链：同行超过两个候选时不合法', () {
    final cands = emptyCands();
    cands[0][1].add(5);
    cands[0][4].add(5);
    cands[0][7].add(5);
    expect(
      BoardMarkup.isLegalConjugate(
        const CandidateRef(0, 1, 5),
        const CandidateRef(0, 7, 5),
        cands,
      ),
      isFalse,
    );
  });

  test('双值强链：不同数字不合法', () {
    final cands = emptyCands();
    cands[0][1].add(5);
    cands[0][7].add(6);
    expect(
      BoardMarkup.isLegalConjugate(
        const CandidateRef(0, 1, 5),
        const CandidateRef(0, 7, 6),
        cands,
      ),
      isFalse,
    );
  });

  test('弱箭头不检查双值约束', () {
    final markup = BoardMarkup();
    final cands = emptyCands();
    cands[0][0].add(1);
    cands[8][8].add(2);
    expect(
      markup.addArrow(
        const CandidateRef(0, 0, 1),
        const CandidateRef(8, 8, 2),
        ArrowKind.weak,
        cands,
      ),
      isTrue,
    );
  });
}
