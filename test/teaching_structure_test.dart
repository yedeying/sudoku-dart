import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/models/technique_structure.dart';

import 'support/teaching_verifier.dart';

void main() {
  final byId = {for (final t in TechniqueCatalog.all) t.id: t};

  // 要复核哪些条目，一律从production的 [TechniqueInfo.teachingOnly] 现算，
  // 这里不留任何人手维护的名单。以前那份 `verifiedTeachingIds` 是个圈：
  // 「要查的条目」由「写了结构声明的条目」定义，于是新加一条不写声明的教学页，
  // 它既不在名单里、也不算漏，什么都不会红。现在的判据来自引擎报不报得出这条
  // （见 technique_catalog_test 的「教学标记和引擎的报法对得上」），躲不过去。
  final teachingOnly = [
    for (final t in TechniqueCatalog.all)
      if (t.teachingOnly) t
  ];

  test('教学专属条目都写了结构声明', () {
    expect(teachingOnly, isNotEmpty, reason: '一条教学专属条目都没有，判据取错了');
    final missing = [
      for (final t in teachingOnly)
        if (t.structure == null) '${t.id}（${t.name}）'
    ]..sort();
    expect(
      missing,
      isEmpty,
      reason: '这些条目没有 finder 兜底，又没写机器可核对的结构声明，'
          '教学页说错了没人会发现：$missing',
    );
  });

  test('每条教学结构都能在自己的盘面上被独立验证', () {
    final failures = <String>[];
    // 遍历整个目录而不是教学专属那一批：已实现技巧要是也写了结构声明，
    // 同样得查得过，不能因为「有 finder 兜底」就免检。
    for (final t in TechniqueCatalog.all) {
      final s = t.structure;
      if (s == null) continue;
      final bad = structureViolations(t.examplePuzzle, s);
      if (bad.isNotEmpty) {
        failures.add('${t.id} (${t.name}):\n    ${bad.join("\n    ")}');
      }
    }
    expect(
      failures,
      isEmpty,
      reason: '教学结构和盘面对不上：\n${failures.join("\n")}',
    );
  });

  test('所有条目的标记候选都真实存在', () {
    final failures = <String>[];
    for (final t in TechniqueCatalog.all) {
      final bad = markupCandidateViolations(t.examplePuzzle, t.exampleMarkup);
      if (bad.isNotEmpty) {
        failures.add('${t.id}:\n    ${bad.join("\n    ")}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('致命结构与鱼类/短链页的连线都是成立的单候选链节', () {
    final failures = <String>[];
    for (final t in TechniqueCatalog.all) {
      final family = t.structure?.family;
      if (family == null || !linkCheckedFamilies.contains(family)) continue;
      final bad = linkHouseViolations(t.examplePuzzle, t.exampleMarkup);
      if (bad.isNotEmpty) {
        failures.add('${t.id}:\n    ${bad.join("\n    ")}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('教学页给出的结论都和盘面的唯一解一致', () {
    final failures = <String>[];
    for (final t in TechniqueCatalog.all) {
      final s = t.structure;
      if (s == null) continue;
      // 结构声明里的 extras 是「多出来的候选」。Type 1 那种「多出来的必须为真」
      // 只在恰好一个 extra 时成立，这时它必须就是唯一解里的那个数字。
      if (s.conclusionTrue.isEmpty && s.conclusionFalse.isEmpty) continue;
      final bad = conclusionViolations(
        t.examplePuzzle,
        s.conclusionTrue,
        s.conclusionFalse,
      );
      if (bad.isNotEmpty) {
        failures.add('${t.id}:\n    ${bad.join("\n    ")}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // 上面几条测试全绿只说明「现在的声明查得过」，不说明这些检查真的会咬人。
  // 下面拿一条已经过关的条目动手改坏，逐项确认每个检查抓得住对应的错法。
  group('复核手段本身咬得住常见错法', () {
    final ur = byId['incomplete_ur']!;
    final s = ur.structure!;

    test('结构格上漏列一个额外候选会被抓住', () {
      final crippled = TeachingStructure(
        family: s.family,
        claim: s.claim,
        baseDigits: s.baseDigits,
        cells: s.cells,
        extras: [s.extras.first],
        boxSpan: s.boxSpan,
      );
      expect(
        structureViolations(ur.examplePuzzle, crippled).join('\n'),
        contains('没有在结构声明里列出'),
      );
    });

    test('宫数说错会被抓住', () {
      final crippled = TeachingStructure(
        family: s.family,
        claim: s.claim,
        baseDigits: s.baseDigits,
        cells: s.cells,
        extras: s.extras,
        boxSpan: 1,
      );
      expect(
        structureViolations(ur.examplePuzzle, crippled).join('\n'),
        contains('宫'),
      );
    });

    test('连不成链的连线会被抓住', () {
      final markup = BoardMarkup(
        arrows: [
          const MarkupArrow(
            from: CandidateRef(4, 1, 5),
            to: CandidateRef(5, 4, 5),
            kind: ArrowKind.weak,
          ),
        ],
      );
      expect(
        linkHouseViolations(ur.examplePuzzle, markup).join('\n'),
        contains('连不成链'),
      );
    });

    test('底数在房屋里不止两个位置时画成强链会被抓住', () {
      final markup = BoardMarkup(
        arrows: [
          const MarkupArrow(
            from: CandidateRef(4, 1, 5),
            to: CandidateRef(4, 4, 5),
            kind: ArrowKind.strong,
          ),
        ],
      );
      expect(
        linkHouseViolations(ur.examplePuzzle, markup).join('\n'),
        contains('候选位置不止两个'),
      );
    });

    // 强制那三条最容易写出「看着绿其实空转」的复核，所以这里的对照组要盯死
    // 两件事：假设得真的是个假设，结论得真的是假设推出来的。
    group('强制类的分支不许空转', () {
      final page = byId['forcing_ur']!;
      final real = page.structure!;

      TeachingStructure tweak({
        List<CandidateRef>? extras,
        List<CandidateRef>? conclusionFalse,
        List<CandidateRef>? conclusionTrue,
        int? replayBudget,
      }) =>
          TeachingStructure(
            family: real.family,
            claim: real.claim,
            baseDigits: real.baseDigits,
            cells: real.cells,
            extras: extras ?? real.extras,
            boxSpan: real.boxSpan,
            replayBudget: replayBudget ?? real.replayBudget,
            conclusionTrue: conclusionTrue ?? real.conclusionTrue,
            conclusionFalse: conclusionFalse ?? real.conclusionFalse,
          );

      test('不声明推理长度会被抓住', () {
        expect(
          forcingViolations(page.examplePuzzle, tweak(replayBudget: -1))
              .join('\n'),
          contains('replayBudget'),
        );
      });

      test('假设一个已经填好的格子会被抓住（空转分支）', () {
        // 拿页面上一个已知数当假设：这一种情况填不进任何东西，什么都推不出来，
        // 老实现正是在这里空转——闭包先把格子填好，assign 直接返回。
        final board = SudokuBoard.fromString(page.examplePuzzle);
        CandidateRef? filled;
        for (int r = 0; r < 9 && filled == null; r++) {
          for (int c = 0; c < 9; c++) {
            if (board.get(r, c) != 0) {
              filled = CandidateRef(r, c, board.get(r, c));
              break;
            }
          }
        }
        expect(
          forcingViolations(
            page.examplePuzzle,
            tweak(extras: [...real.extras, filled!]),
          ).join('\n'),
          contains('已经填好了，这一种情况是空的'),
        );
      });

      test('光靠唯余摒除就能拿到的结论会被抓住', () {
        // 页面这张盘面上盲推 budget×支数 格能填出来的格子，
        // 拿它上面被顺手删掉的候选当「强制结论」，就该被顶回来。
        final blind = LogicGrid.fromBoard(page.examplePuzzle);
        blind.budget = real.replayBudget! * real.extras.length;
        blind.propagate();
        final board = SudokuBoard.fromString(page.examplePuzzle);
        CandidateRef? freebie;
        for (int i = 0; i < 81 && freebie == null; i++) {
          final r = i ~/ 9, c = i % 9;
          if (board.get(r, c) != 0) continue;
          for (final d in board.getCandidates(r, c)) {
            if (!blind.cand[i].contains(d)) {
              freebie = CandidateRef(r, c, d);
              break;
            }
          }
        }
        expect(freebie, isNotNull, reason: '这张盘面盲推一步都走不动，换个例子再写这条对照');
        expect(
          forcingViolations(
            page.examplePuzzle,
            tweak(conclusionFalse: [freebie!]),
          ).join('\n'),
          contains('不是强制推出来的'),
        );
      });

      test('某一支当场矛盾会被抓住', () {
        // 一填就死的分支说明那个候选可以直接删，不该拿来凑交集。
        // 在页面这张盘面上找一个「填进去就撞墙」的候选来充当这种坏分支。
        final board = SudokuBoard.fromString(page.examplePuzzle);
        CandidateRef? dead;
        for (int i = 0; i < 81 && dead == null; i++) {
          final r = i ~/ 9, c = i % 9;
          if (board.get(r, c) != 0) continue;
          for (final d in board.getCandidates(r, c)) {
            final probe = LogicGrid.fromBoard(page.examplePuzzle);
            probe.budget = real.replayBudget!;
            probe.assign(i, d, '假设');
            if (probe.broken) {
              dead = CandidateRef(r, c, d);
              break;
            }
          }
        }
        expect(dead, isNotNull,
            reason: '这张盘面上没有 $real.replayBudget 格之内就撞墙的候选，'
                '换个例子再写这条对照');
        expect(
          forcingViolations(
            page.examplePuzzle,
            tweak(extras: [...real.extras, dead!]),
          ).join('\n'),
          contains('可以直接删掉'),
        );
      });
    });

    // 死盘家族的删除全是从「多余候选不能同时为假」重算出来的，不是拿唯一解对答案。
    // 所以这一组对照要盯的就是「重算真的按各型的规则走」：把共同可见处、虚拟格、
    // 强链数字、那条链分别改错一处，每一处都得报出来。
    group('双值死盘各型的重算咬得住错法', () {
      TeachingStructure graveLike(
        TeachingStructure s, {
        TeachingClaim? claim,
        List<CandidateRef>? extras,
        int? lockDigit,
        List<int>? lockHouses,
        List<CellRef>? subsetCells,
        Set<int>? subsetDigits,
        List<CandidateRef>? conclusionFalse,
        List<CandidateRef>? conclusionTrue,
        int? replayBudget,
      }) =>
          TeachingStructure(
            family: s.family,
            claim: claim ?? s.claim,
            extras: extras ?? s.extras,
            lockDigit: lockDigit ?? s.lockDigit,
            lockHouses: lockHouses ?? s.lockHouses,
            subsetCells: subsetCells ?? s.subsetCells,
            subsetDigits: subsetDigits ?? s.subsetDigits,
            conclusionTrue: conclusionTrue ?? s.conclusionTrue,
            conclusionFalse: conclusionFalse ?? s.conclusionFalse,
            replayBudget: replayBudget ?? s.replayBudget,
          );

      String checkGrave(TechniqueInfo t, TeachingStructure s) =>
          structureViolations(t.examplePuzzle, s).join('\n');

      /// 例外格所在的那些格子。
      List<CellRef> ownersOf(TeachingStructure s) =>
          [for (final e in s.extras) CellRef(e.row, e.col)];

      group('Type 2', () {
        final page = byId['bug_type2']!;
        final s = page.structure!;

        test('删到只看得见一个例外格的位置上会被抓住', () {
          // Type 2 的依据是「这个数字至少落在例外格之一」，
          // 所以只有同时看得见全部例外格的位置才删得动。
          final board = SudokuBoard.fromString(page.examplePuzzle);
          final owners = ownersOf(s);
          final digit = s.extras.first.num;
          CandidateRef? partial;
          for (int r = 0; r < 9 && partial == null; r++) {
            for (int c = 0; c < 9; c++) {
              if (board.get(r, c) != 0) continue;
              if (owners.any((o) => o.row == r && o.col == c)) continue;
              if (!board.getCandidates(r, c).contains(digit)) continue;
              final seen = owners.where((o) => sees(r, c, o.row, o.col)).length;
              if (seen > 0 && seen < owners.length) {
                partial = CandidateRef(r, c, digit);
                break;
              }
            }
          }
          expect(partial, isNotNull, reason: '这张盘面上找不到「只看得见一个例外格」的位置，换个例子');
          expect(
            checkGrave(
              page,
              graveLike(s, conclusionFalse: [...s.conclusionFalse, partial!]),
            ),
            contains('删不到它'),
          );
        });

        test('少报一条共同可见处的删除会被抓住', () {
          expect(
            checkGrave(
              page,
              graveLike(s, conclusionFalse: s.conclusionFalse.skip(1).toList()),
            ),
            contains('结论声明漏了'),
          );
        });

        test('例外候选不是同一个数字却按 Type 2 讲会被抓住', () {
          // Type 3 那张盘面的两个例外候选是 2 和 3，共同可见处根本无从谈起。
          final other = byId['bug_type3']!;
          expect(
            checkGrave(
              other,
              graveLike(other.structure!, claim: TeachingClaim.graveType2),
            ),
            contains('同一个数字'),
          );
        });
      });

      group('Type 3', () {
        final page = byId['bug_type3']!;
        final s = page.structure!;

        test('虚拟格配上候选越界的格子会被抓住', () {
          // 数组要锁得住，成员格的候选必须全落在数组数字里。
          final board = SudokuBoard.fromString(page.examplePuzzle);
          final owners = ownersOf(s);
          final house = s.lockHouses.single;
          CellRef? loose;
          for (final cell in houseCells(house)) {
            final r = cell[0], c = cell[1];
            if (board.get(r, c) != 0) continue;
            if (owners.any((o) => o.row == r && o.col == c)) continue;
            if (s.subsetCells.any((m) => m.row == r && m.col == c)) continue;
            if (!board.getCandidates(r, c).every(s.subsetDigits.contains)) {
              loose = CellRef(r, c);
              break;
            }
          }
          expect(loose, isNotNull, reason: '这条房屋上每一格都在数组数字里，换个例子');
          expect(
            checkGrave(page, graveLike(s, subsetCells: [loose!])),
            contains('越出了数组数字'),
          );
        });

        test('成员格个数和数组数字个数配不上会被抓住', () {
          expect(
            checkGrave(
              page,
              graveLike(s, subsetDigits: {...s.subsetDigits, 9}),
            ),
            contains('数组要求同样多的数字'),
          );
        });

        test('数组数字漏掉虚拟格自己的候选会被抓住', () {
          final ea = s.extras.first.num;
          expect(
            checkGrave(
              page,
              graveLike(
                s,
                subsetDigits: {
                  for (final d in s.subsetDigits)
                    if (d != ea) d,
                  9,
                },
              ),
            ),
            contains('必须都落在数组数字'),
          );
        });

        test('把数组删除算到成员格自己头上会被抓住', () {
          expect(
            checkGrave(
              page,
              graveLike(s, conclusionFalse: [
                ...s.conclusionFalse,
                CandidateRef(
                  s.subsetCells.single.row,
                  s.subsetCells.single.col,
                  s.subsetDigits.first,
                ),
              ]),
            ),
            contains('删不到它'),
          );
        });
      });

      group('Type 4', () {
        final page = byId['bug_type4']!;
        final s = page.structure!;

        test('强链数字写成例外格自己多出来的那个会被抓住', () {
          // Type 4 锁的必须是两个例外格共有的底数；
          // 多出来的那个候选恰恰不是底数，拿它当强链就全错了。
          expect(
            checkGrave(page, graveLike(s, lockDigit: s.extras.first.num)),
            contains('共有的底数'),
          );
        });

        test('强链数字写成两格都没有的数字会被抓住', () {
          final board = SudokuBoard.fromString(page.examplePuzzle);
          final owners = ownersOf(s);
          final shared = {
            for (final d in board.getCandidates(owners[0].row, owners[0].col))
              if (board.getCandidates(owners[1].row, owners[1].col).contains(d))
                d
          };
          final absent = [for (int d = 1; d <= 9; d++) d]
              .firstWhere((d) => !shared.contains(d));
          expect(
            checkGrave(page, graveLike(s, lockDigit: absent)),
            contains('共有的底数'),
          );
        });

        test('强链房屋写成容不下两个例外格的那条会被抓住', () {
          final owners = ownersOf(s);
          final wrong = [
            for (int h = 0; h < 9; h++) h
          ].firstWhere((h) => !houseCells(h).any(
              (cell) => cell[0] == owners[0].row && cell[1] == owners[0].col));
          expect(
            checkGrave(page, graveLike(s, lockHouses: [wrong])),
            contains('并不同时容纳'),
          );
        });

        test('删掉例外格上「锁定数字或自己多出来的候选」会被抓住', () {
          expect(
            checkGrave(
              page,
              graveLike(s, conclusionFalse: [
                ...s.conclusionFalse,
                CandidateRef(
                  s.extras.first.row,
                  s.extras.first.col,
                  s.lockDigit!,
                ),
              ]),
            ),
            contains('删不到它'),
          );
        });
      });

      group('待定 BUG', () {
        final page = byId['pending_bug']!;
        final s = page.structure!;

        test('换一个推不出矛盾的删除会被抓住', () {
          // 真结论是「r8c4 不能填 2」。把同一格的另一个候选说成能删，
          // 那条链就接不上了：假设它为真，配上死盘节点也推不出矛盾。
          final target = s.conclusionFalse.single;
          final board = SudokuBoard.fromString(page.examplePuzzle);
          final other = board
              .getCandidates(target.row, target.col)
              .firstWhere((d) => d != target.num);
          expect(
            checkGrave(
              page,
              graveLike(s, conclusionFalse: [
                CandidateRef(target.row, target.col, other),
              ]),
            ),
            contains('推不出矛盾'),
          );
        });

        test('推理步数不够时不许算落地', () {
          expect(
            checkGrave(page, graveLike(s, replayBudget: 1)),
            contains('推不出矛盾'),
          );
        });

        test('不声明推理步数会被抓住', () {
          expect(
            checkGrave(
              page,
              TeachingStructure(
                family: s.family,
                claim: s.claim,
                extras: s.extras,
                conclusionFalse: s.conclusionFalse,
              ),
            ),
            contains('replayBudget'),
          );
        });

        test('那条矛盾真的是死盘节点顶出来的，不是唯余摒除自己走到的', () {
          // 把节点规则撤掉、其余照旧：同一个假设推同样多步应当推不出矛盾。
          // 否则这一页讲的其实是「假设一下再唯余摒除」，和死盘结构没关系。
          final target = s.conclusionFalse.single;
          final g = LogicGrid.fromBoard(page.examplePuzzle);
          g.budget = s.replayBudget!;
          g.assign(target.row * 9 + target.col, target.num, '假设');
          g.propagate();
          expect(
            g.broken,
            isFalse,
            reason: '不用死盘节点也能推出矛盾，这一页没讲出结构的价值',
          );
        });
      });

      // 这一组盯的是复核以前真正漏掉的那个口子：五条死盘页当时都停在 deadlyOnly
      // 档上，却各自带着删除结论，而 deadlyOnly 的检查根本没被调用。现在死盘家族
      // 只认 grave 系列的档位，借用矩形族的同名类型也不行——矩形族 type2 的前置
      // 检查里有「其余结构格只剩底数」，而死盘的 cells 是空的，那一条会自动通过，
      // 等于什么都没查。
      for (final claim in const [
        TeachingClaim.deadlyOnly,
        TeachingClaim.type1,
        TeachingClaim.type2,
        TeachingClaim.type3,
        TeachingClaim.type4,
        TeachingClaim.chainNode,
        TeachingClaim.elimination,
      ]) {
        test('死盘条目挂在 ${claim.name} 档上会被抓住', () {
          final page = byId['bug_type2']!;
          expect(
            checkGrave(page, graveLike(page.structure!, claim: claim)),
            contains('要用 grave 系列的结论档位'),
          );
        });
      }

      test('矩形族条目借用死盘的类型也会被抓住', () {
        final page = byId['incomplete_ur']!;
        final real = page.structure!;
        expect(
          structureViolations(
            page.examplePuzzle,
            TeachingStructure(
              family: real.family,
              claim: TeachingClaim.graveType2,
              baseDigits: real.baseDigits,
              cells: real.cells,
              extras: real.extras,
              boxSpan: real.boxSpan,
            ),
          ).join('\n'),
          contains('用不了它的推理'),
        );
      });
    });

    test('和唯一解冲突的结论会被抓住', () {
      // 唯一解里 r6c2 填 1，所以「删 1r6c2」是个错结论。
      expect(
        conclusionViolations(
          ur.examplePuzzle,
          const [],
          const [CandidateRef(5, 1, 1)],
        ).join('\n'),
        isNotEmpty,
      );
    });
  });

  // 鱼类和同数字短链这几族的检查也照样改坏一遍：这些页面的声明比矩形族长得多，
  // 光看「现在全绿」根本判断不出哪一条真的在拦人。
  group('鱼类与短链的复核手段咬得住常见错法', () {
    final sashimi = byId['sashimi']!;
    final sashimiFish = sashimi.structure!.fishes.single;
    final siamese = byId['siamese_fish']!;
    final mutant = byId['mutant_fish']!;
    final cannibal = byId['cannibalism']!;
    final turbot = byId['turbot']!;

    FishSpec tweak(
      FishSpec f, {
      List<FishHouse>? baseHouses,
      List<FishHouse>? coverHouses,
      List<CandidateRef>? fins,
      List<CellRef>? coverDeficits,
      List<CandidateRef>? eliminations,
      bool? sashimi,
      bool? mutant,
      bool? cannibal,
      bool? beyondTurbot,
      bool? beyondLocked,
    }) =>
        FishSpec(
          digit: f.digit,
          baseHouses: baseHouses ?? f.baseHouses,
          coverHouses: coverHouses ?? f.coverHouses,
          fins: fins ?? f.fins,
          coverDeficits: coverDeficits ?? f.coverDeficits,
          eliminations: eliminations ?? f.eliminations,
          sashimi: sashimi ?? f.sashimi,
          mutant: mutant ?? f.mutant,
          cannibal: cannibal ?? f.cannibal,
          beyondTurbot: beyondTurbot ?? f.beyondTurbot,
          beyondLocked: beyondLocked ?? f.beyondLocked,
        );

    String checkSashimi(FishSpec f) =>
        fishSpecViolations(sashimi.examplePuzzle, f).join('\n');

    test('鳍漏列一个会被抓住', () {
      expect(
        checkSashimi(tweak(sashimiFish, fins: const [])),
        contains('没被任何覆盖线盖住'),
      );
    });

    test('把没有缺口的鱼说成刺身会被抓住', () {
      // Mutant 那条鱼一个鳍都没有，每条基线在覆盖里都占满了顶点。
      final f = mutant.structure!.fishes.single;
      expect(
        fishSpecViolations(mutant.examplePuzzle, tweak(f, sashimi: true))
            .join('\n'),
        contains('这只是普通带鳍鱼'),
      );
    });

    test('刺身却不声明刺身会被抓住', () {
      expect(
        checkSashimi(tweak(sashimiFish, sashimi: false)),
        contains('这已经是刺身了'),
      );
    });

    test('缺掉的覆盖顶点写错会被抓住', () {
      expect(
        checkSashimi(tweak(sashimiFish, coverDeficits: const [CellRef(1, 6)])),
        contains('没写进声明'),
      );
    });

    test('两条基线共用一格会被抓住', () {
      // c9 上也有 3，拿它当第四条基线就和 r2、r6、r7 各撞一格。
      expect(
        checkSashimi(tweak(
          sashimiFish,
          baseHouses: const [
            FishHouse.r(1),
            FishHouse.r(5),
            FishHouse.r(6),
            FishHouse.c(8),
          ],
          coverHouses: const [
            FishHouse.c(2),
            FishHouse.c(6),
            FishHouse.c(8),
            FishHouse.r(0),
          ],
        )),
        contains('基线两两不共格'),
      );
    });

    test('删除漏报一条会被抓住', () {
      expect(
        checkSashimi(tweak(
          sashimiFish,
          eliminations: const [CandidateRef(0, 6, 3)],
        )),
        contains('结论声明漏了'),
      );
    });

    test('删除多报一条会被抓住', () {
      expect(
        checkSashimi(tweak(
          sashimiFish,
          eliminations: const [
            CandidateRef(0, 6, 3),
            CandidateRef(0, 7, 3),
            CandidateRef(0, 8, 3),
          ],
        )),
        contains('删不到它'),
      );
    });

    test('声明超出多宝鱼一档却其实被包住会被抓住', () {
      final f = siamese.structure!.fishes.first;
      expect(
        fishSpecViolations(
          siamese.examplePuzzle,
          FishSpec(
            digit: f.digit,
            baseHouses: f.baseHouses,
            coverHouses: f.coverHouses,
            fins: f.fins,
            coverDeficits: f.coverDeficits,
            eliminations: f.eliminations,
            sashimi: f.sashimi,
            beyondTurbot: true,
            beyondLocked: f.beyondLocked,
          ),
        ).join('\n'),
        contains('把这组删除整个包住了'),
      );
    });

    test('声明避开了区块摒除其实没避开会被抓住', () {
      // 这条鱼的删除区块摒除确实碰不到，所以反过来把标志摘掉就该报。
      expect(
        checkSashimi(tweak(sashimiFish, beyondLocked: false)),
        contains('区块摒除一个都碰不到'),
      );
    });

    test('Mutant 标志说错会被抓住', () {
      final f = mutant.structure!.fishes.single;
      expect(
        fishSpecViolations(
          mutant.examplePuzzle,
          tweak(f, mutant: false),
        ).join('\n'),
        contains('已经是 Mutant 了'),
      );
      expect(
        fishSpecViolations(
          sashimi.examplePuzzle,
          tweak(sashimiFish, mutant: true),
        ).join('\n'),
        contains('声明是 Mutant'),
      );
    });

    test('自噬标志说错会被抓住', () {
      final f = cannibal.structure!.fishes.single;
      expect(
        fishSpecViolations(
          cannibal.examplePuzzle,
          tweak(f, cannibal: false),
        ).join('\n'),
        contains('这已经是自噬了'),
      );
      expect(
        fishSpecViolations(
          sashimi.examplePuzzle,
          tweak(sashimiFish, cannibal: true),
        ).join('\n'),
        contains('声明有自噬'),
      );
    });

    test('双生鱼两条覆盖一样会被抓住', () {
      final a = siamese.structure!.fishes.first;
      final bad = TeachingStructure(
        family: TeachingFamily.siameseFish,
        claim: TeachingClaim.elimination,
        fishes: [a, a],
        conclusionFalse: a.eliminations,
      );
      expect(
        siameseViolations(siamese.examplePuzzle, bad).join('\n'),
        contains('那是同一条鱼'),
      );
    });

    test('双生鱼两条鱼身不一样会被抓住', () {
      final s2 = siamese.structure!;
      final bad = TeachingStructure(
        family: TeachingFamily.siameseFish,
        claim: TeachingClaim.elimination,
        fishes: [
          s2.fishes[0],
          FishSpec(
            digit: s2.fishes[1].digit,
            baseHouses: const [FishHouse.r(0), FishHouse.r(7)],
            coverHouses: s2.fishes[1].coverHouses,
            fins: s2.fishes[1].fins,
            coverDeficits: s2.fishes[1].coverDeficits,
            eliminations: s2.fishes[1].eliminations,
            sashimi: s2.fishes[1].sashimi,
            beyondLocked: s2.fishes[1].beyondLocked,
          ),
        ],
        conclusionFalse: s2.conclusionFalse,
      );
      expect(
        siameseViolations(siamese.examplePuzzle, bad).join('\n'),
        contains('基线集合必须一模一样'),
      );
    });

    TeachingStructure turbotWith(
      List<ChainSegment> chain, {
      bool generalized = true,
      List<CandidateRef>? elims,
    }) =>
        TeachingStructure(
          family: TeachingFamily.turbot,
          claim: TeachingClaim.elimination,
          fishDigit: 4,
          chain: chain,
          generalizedTurbot: generalized,
          beyondLocked: true,
          conclusionFalse: elims ?? turbot.structure!.conclusionFalse,
        );

    test('把弱链一段说成强链会被抓住', () {
      final c = turbot.structure!.chain;
      expect(
        turbotViolations(
          turbot.examplePuzzle,
          turbotWith([
            c[0],
            ChainSegment(
              from: c[1].from,
              to: c[1].to,
              strong: true,
              house: c[1].house,
            ),
            c[2],
          ]),
        ).join('\n'),
        contains('应当是弱链'),
      );
    });

    test('强链房屋里候选不止两个会被抓住', () {
      // c8 上的 4 有四个位置，把那一段的房屋改成 c8 就撑不起强链。
      final c = turbot.structure!.chain;
      expect(
        turbotViolations(
          turbot.examplePuzzle,
          turbotWith([
            c[0],
            c[1],
            ChainSegment(
              from: c[2].from,
              to: c[2].to,
              strong: true,
              house: 16,
            ),
          ]),
        ).join('\n'),
        contains('不是这一段的两端'),
      );
    });

    test('三段接不上会被抓住', () {
      final c = turbot.structure!.chain;
      expect(
        turbotViolations(
          turbot.examplePuzzle,
          turbotWith([
            c[0],
            ChainSegment(
              from: const CandidateRef(8, 7, 4),
              to: c[1].to,
              strong: false,
              house: c[1].house,
            ),
            c[2],
          ]),
        ).join('\n'),
        contains('接不上'),
      );
    });

    // 另一块盘面上 2 的一条摩天楼：r5 与 r8 各有两个位置，靠 c2 接起来。
    const skyscraperPuzzle =
        '000900000069472010000300204300006020005047000708203400'
        '400600002100050007000001300';
    const skyscraperChain = [
      ChainSegment(
        from: CandidateRef(4, 0, 2),
        to: CandidateRef(4, 1, 2),
        strong: true,
        house: 4,
      ),
      ChainSegment(
        from: CandidateRef(4, 1, 2),
        to: CandidateRef(7, 1, 2),
        strong: false,
        house: 10,
      ),
      ChainSegment(
        from: CandidateRef(7, 1, 2),
        to: CandidateRef(7, 2, 2),
        strong: true,
        house: 7,
      ),
    ];
    // 这条摩天楼的删除区块摒除本来就吃得下，所以 beyondLocked 只能写 false。
    TeachingStructure skyscraperWith({required bool generalized}) =>
        TeachingStructure(
          family: TeachingFamily.turbot,
          claim: TeachingClaim.elimination,
          fishDigit: 2,
          chain: skyscraperChain,
          generalizedTurbot: generalized,
          conclusionFalse: const [CandidateRef(8, 0, 2)],
        );

    test('摩天楼冒充一般形状会被抓住', () {
      expect(
        turbotViolations(skyscraperPuzzle, skyscraperWith(generalized: true))
            .join('\n'),
        contains('这条链就是摩天楼'),
      );
    });

    test('摩天楼老实声明成已命名特例就放过', () {
      expect(
        turbotViolations(skyscraperPuzzle, skyscraperWith(generalized: false)),
        isEmpty,
      );
    });

    test('多宝鱼的删除说错会被抓住', () {
      expect(
        turbotViolations(
          turbot.examplePuzzle,
          turbotWith(
            turbot.structure!.chain,
            elims: const [CandidateRef(8, 0, 4)],
          ),
        ).join('\n'),
        contains('删不到它'),
      );
    });
  });

  // 数组/锁定集与动态链这几族的检查同样要挨一遍改坏：
  // 这几页的声明字段最多，也最容易「图画对了、推理没接上」。
  group('数组与动态链的复核手段咬得住常见错法', () {
    /// 照原样复制一条结构声明，只换掉指名的那几个字段。
    TeachingStructure like(
      TeachingStructure s, {
      TeachingFamily? family,
      Set<int>? baseDigits,
      List<CellRef>? cells,
      List<int>? lockHouses,
      List<CandidateRef>? guards,
      List<SectorLink>? sectorLinks,
      CandidateRef? burr,
      CellRef? splitCell,
      DynamicAssumption? assumption,
      ExocetSpec? exocet,
      int? replayBudget,
      bool dropReplayBudget = false,
      int? lockedDigitCount,
      List<CandidateRef>? conclusionFalse,
    }) =>
        TeachingStructure(
          family: family ?? s.family,
          claim: s.claim,
          baseDigits: baseDigits ?? s.baseDigits,
          cells: cells ?? s.cells,
          extras: s.extras,
          lockHouses: lockHouses ?? s.lockHouses,
          fishDigit: s.fishDigit,
          guards: guards ?? s.guards,
          lockedDigitCount: lockedDigitCount ?? s.lockedDigitCount,
          sectorLinks: sectorLinks ?? s.sectorLinks,
          burr: burr ?? s.burr,
          splitCell: splitCell ?? s.splitCell,
          assumption: assumption ?? s.assumption,
          exocet: exocet ?? s.exocet,
          replayBudget:
              dropReplayBudget ? null : (replayBudget ?? s.replayBudget),
          conclusionFalse: conclusionFalse ?? s.conclusionFalse,
        );

    String check(TechniqueInfo t, TeachingStructure s) =>
        structureViolations(t.examplePuzzle, s).join('\n');

    group('死环', () {
      final loop = byId['dead_loop']!;
      final s = loop.structure!;

      test('守卫漏数一个会被抓住', () {
        expect(
          check(loop, like(s, guards: s.guards.take(2).toList())),
          contains('守卫'),
        );
      });

      test('圈长变成偶数会被抓住', () {
        expect(
          check(
            loop,
            like(
              s,
              cells: s.cells.take(4).toList(),
              lockHouses: s.lockHouses.take(4).toList(),
            ),
          ),
          contains('奇数'),
        );
      });

      test('两条边共用一个房屋会被抓住', () {
        expect(
          check(loop, like(s, lockHouses: const [3, 16, 6, 14, 3])),
          contains('房屋'),
        );
      });

      test('删除落点看不全守卫会被抓住', () {
        expect(
          // 9r4c7 本身就是一个守卫，删它等于替守卫下了结论。
          check(loop, like(s, conclusionFalse: const [CandidateRef(3, 6, 9)])),
          contains('删不到它'),
        );
      });
    });

    group('毛刺数组', () {
      final burr = byId['burr_array']!;
      final s = burr.structure!;

      test('毛刺写在不是唯一落点的格子上会被抓住', () {
        // 5 在这三格里出现了三次，当不成毛刺。
        expect(
          check(burr, like(s, burr: const CandidateRef(6, 0, 5))),
          contains('毛刺必须只落在一格上'),
        );
      });

      test('只有一支删得掉的候选被当成结论会被抓住', () {
        // 情况一把 4r7c7 删了，情况二却把它填成真，交集里没有它。
        expect(
          check(
            burr,
            like(s, conclusionFalse: [
              ...s.conclusionFalse,
              const CandidateRef(6, 6, 4)
            ]),
          ),
          contains('删不到它'),
        );
      });

      test('不声明推演步数会被抓住', () {
        expect(
          check(burr, like(s, dropReplayBudget: true)),
          contains('replayBudget'),
        );
      });
    });

    group('弱待定数组', () {
      final wals = byId['wals']!;
      final s = wals.structure!;

      test('只有一支删得掉的成员候选被当成结论会被抓住', () {
        // 情况一 r3c7=4 把 5r3c7 删了，情况二却把 r3c7 填成 5。
        expect(
          check(
            wals,
            like(s, conclusionFalse: [
              ...s.conclusionFalse,
              const CandidateRef(2, 6, 5)
            ]),
          ),
          contains('删不到它'),
        );
      });

      test('落点漏列一格会被抓住', () {
        expect(
          check(
            wals,
            like(
              s,
              cells: const [CellRef(2, 6), CellRef(7, 6)],
              splitCell: const CellRef(7, 6),
            ),
          ),
          contains('没有写进结构声明'),
        );
      });

      test('N 个数字只占 N 格时会被抓住', () {
        // c7 上 1、4、5 的落点合起来只有 r2c7、r3c7、r8c7 三格，
        // 那是个现成的隐性三数组，不是「差一格」的弱待定数组。
        expect(
          check(
            wals,
            like(
              s,
              baseDigits: const {1, 4, 5},
              cells: const [CellRef(1, 6), CellRef(2, 6), CellRef(7, 6)],
            ),
          ),
          contains('要求恰好 4 格'),
        );
      });

      test('分支格写在结构之外会被抓住', () {
        expect(
          check(wals, like(s, splitCell: const CellRef(5, 6))),
          contains('不在落点里'),
        );
      });
    });

    group('DDS', () {
      final dds = byId['dds']!;
      final s = dds.structure!;

      test('漏了一条链接会被抓住', () {
        expect(
          check(dds, like(s, sectorLinks: s.sectorLinks.take(5).toList())),
          isNotEmpty,
        );
      });

      test('数字配错房屋会被抓住', () {
        // 4 那一片必须跨到左下宫，写成 c1 装不下它的落点。
        expect(
          check(
            dds,
            like(s, sectorLinks: const [
              SectorLink(1, [9]),
              SectorLink(5, [9]),
              SectorLink(8, [9]),
              SectorLink(4, [9]),
              SectorLink(9, [7]),
              SectorLink(2, [7]),
            ]),
          ),
          isNotEmpty,
        );
      });
    });

    group('MSLS', () {
      final msls = byId['msls']!;
      final s = msls.structure!;

      test('一个数字占两条房屋却按 DDS 讲会被抓住', () {
        expect(
          check(
              msls, like(s, family: TeachingFamily.distributedDisjointSubset)),
          isNotEmpty,
        );
      });

      test('漏掉数字占的第二条房屋会被抓住', () {
        expect(
          check(
            msls,
            like(s, sectorLinks: const [
              SectorLink(3, [6]),
              SectorLink(7, [6]),
              SectorLink(9, [6]),
              SectorLink(5, [1]),
              SectorLink(8, [16]),
            ]),
          ),
          isNotEmpty,
        );
      });
    });

    group('动态 AIC', () {
      final dyn = byId['dynamic_aic']!;
      final s = dyn.structure!;
      final a = s.assumption!;

      DynamicAssumption assumeWith({
        int? linkDigit,
        int? linkHouse,
        List<CellRef>? linkCells,
        int? staticSpots,
      }) =>
          DynamicAssumption(
            assume: a.assume,
            linkDigit: linkDigit ?? a.linkDigit,
            linkHouse: linkHouse ?? a.linkHouse,
            linkCells: linkCells ?? a.linkCells,
            staticSpots: staticSpots ?? a.staticSpots,
          );

      test('假设之前的落点数说错会被抓住', () {
        expect(
          check(dyn, like(s, assumption: assumeWith(staticSpots: 4))),
          contains('实际是 3 个'),
        );
      });

      test('本来就只有两个落点的强链会被抓住', () {
        // 3 在 r1 上静态就只有 r1c4、r1c6 两格，那是条普通强链，不必假设。
        expect(
          check(
            dyn,
            like(
              s,
              assumption: assumeWith(
                linkDigit: 3,
                linkHouse: 0,
                linkCells: const [CellRef(0, 3), CellRef(0, 5)],
                staticSpots: 2,
              ),
            ),
          ),
          contains('静态'),
        );
      });

      test('动态强链收成的那两格写错会被抓住', () {
        expect(
          check(
            dyn,
            like(
              s,
              assumption:
                  assumeWith(linkCells: const [CellRef(4, 3), CellRef(4, 7)]),
            ),
          ),
          contains('不是声明的'),
        );
      });
    });

    group('飞鱼导弹', () {
      final exocet = byId['exocet']!;
      final s = exocet.structure!;
      final e = s.exocet!;

      ExocetSpec exocetWith({
        List<CellRef>? baseCells,
        List<CellRef>? targets,
        List<CellRef>? companions,
        List<List<CellRef>>? mirrors,
        List<int>? crossLines,
        List<SectorLink>? coverLines,
        List<CandidateRef>? eliminations,
      }) =>
          ExocetSpec(
            baseCells: baseCells ?? e.baseCells,
            targets: targets ?? e.targets,
            companions: companions ?? e.companions,
            mirrors: mirrors ?? e.mirrors,
            crossLines: crossLines ?? e.crossLines,
            coverLines: coverLines ?? e.coverLines,
            eliminations: eliminations ?? e.eliminations,
          );

      test('基数集不是两个基格候选的并集会被抓住', () {
        expect(
          check(exocet, like(s, baseDigits: const {2, 5})),
          isNotEmpty,
        );
      });

      test('目标格落在基线上会被抓住', () {
        // r5c3 和两个基格同在 r5，看得见它们，当不了目标格。
        expect(
          check(
            exocet,
            like(
              s,
              exocet: exocetWith(targets: const [CellRef(4, 2), CellRef(3, 6)]),
            ),
          ),
          isNotEmpty,
        );
      });

      test('伴随格写错会被抓住', () {
        expect(
          check(
            exocet,
            like(
              s,
              exocet: exocetWith(
                companions: const [CellRef(4, 2), CellRef(5, 6)],
              ),
            ),
          ),
          isNotEmpty,
        );
      });

      test('删除多报一条会被抓住', () {
        expect(
          check(
            exocet,
            like(
              s,
              exocet: exocetWith(
                eliminations: [...e.eliminations, const CandidateRef(5, 2, 2)],
              ),
              conclusionFalse: [
                ...s.conclusionFalse,
                const CandidateRef(5, 2, 2),
              ],
            ),
          ),
          isNotEmpty,
        );
      });
    });
  });
}
