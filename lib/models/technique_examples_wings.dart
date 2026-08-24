import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';

int _ck(int r, int c) => BoardMarkup.cellKey(r, c);
CandidateRef _cr(int r, int c, int n) => CandidateRef(r, c, n);
MarkupArrow _arrow(
  int r1,
  int c1,
  int n1,
  int r2,
  int c2,
  int n2,
  ArrowKind kind,
) =>
    MarkupArrow(from: _cr(r1, c1, n1), to: _cr(r2, c2, n2), kind: kind);

const _chainLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '起点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '中继格'),
  TechniqueLegendItem(color: TeachingColors.end, label: '终点'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _wxyzLegend = [
  TechniqueLegendItem(color: TeachingColors.node, label: '支点'),
  TechniqueLegendItem(color: TeachingColors.start, label: '翼格'),
  TechniqueLegendItem(color: TeachingColors.end, label: '翼格'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _coloringLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '颜色 A'),
  TechniqueLegendItem(color: TeachingColors.end, label: '颜色 B'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _urLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '矩形四格'),
  TechniqueLegendItem(color: TeachingColors.end, label: '额外数字'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _bugLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '关键格'),
  TechniqueLegendItem(color: TeachingColors.end, label: '保留数字'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

/// 链/翼类技巧的标记：起点涂 start（绿），终点涂 end（黄），
/// 中间的中继格涂 node（蓝），被删掉的候选所在格涂 elimCell（浅黄）、
/// 候选本身涂 elimCand（红）。强链箭头实线、弱链箭头虚线由 [ArrowKind] 驱动。
BoardMarkup _chainMarkup({
  required List<int> start,
  required List<int> end,
  List<List<int>> nodes = const [],
  required List<MarkupArrow> arrows,
  required List<List<int>> eliminated,
}) {
  final cellColors = <int, Color>{
    _ck(start[0], start[1]): TeachingColors.start,
    _ck(end[0], end[1]): TeachingColors.end,
    for (final n in nodes) _ck(n[0], n[1]): TeachingColors.node,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// Simple Coloring 专用：不分起终点方向，只分两种着色，
/// 分别借用 start/end 两个颜色表示「同一条强链链条上的两种奇偶」。
BoardMarkup _coloringMarkup({
  required List<List<int>> colorA,
  required List<List<int>> colorB,
  required List<MarkupArrow> arrows,
  required List<List<int>> eliminated,
}) {
  final cellColors = <int, Color>{
    for (final c in colorA) _ck(c[0], c[1]): TeachingColors.start,
    for (final c in colorB) _ck(c[0], c[1]): TeachingColors.end,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// 唯一矩形/BUG+1 专用：矩形（或 BUG 的四个关键格）涂 pattern（浅蓝），
/// 额外数字的候选涂 end（金黄），真正被删除的候选涂 elimCand（红），
/// 删除目标所在格顺带涂 elimCell。
BoardMarkup _urMarkup({
  required List<List<int>> rectangle,
  List<List<int>> extraCandidates = const [],
  List<List<int>> eliminated = const [],
  List<MarkupArrow> arrows = const [],
}) {
  final cellColors = <int, Color>{
    for (final c in rectangle) _ck(c[0], c[1]): TeachingColors.pattern,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final e in extraCandidates)
        _cr(e[0], e[1], e[2]): TeachingColors.end,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// 翼类、唯一矩形与 Simple Coloring 的十三个教学盘面。
///
/// 摩天楼、双线风筝、空矩形、XY-Wing、XYZ-Wing、W-Wing、Simple Coloring、
/// 唯一矩形 Type 2/3、Simple Coloring 与唯一矩形 Type 4 都是从随机生成的
/// 完整解里挖出题目后，用 [AdvancedTechniques] 对应的 finder 在一块全新的
/// 快照上重新求解，确认能推出同样的技巧名字、同样的删除/填入结果，
/// 才把这一刻的 81 位盘面和候选写成常量。WXYZ-Wing 与 BUG+1 在本引擎里
/// 还没有对应的 finder，改用「从完整解出发挖空」的办法：先取一个真实的
/// 完整解，按目标形态挖空支点/翼格/矩形四格涉及的格子，再逐一核对挖空后的
/// 候选形状与题目唯一解都成立——盘面依然是真实解的子集，只是形态本身没有
/// 引擎自动验证。
List<TechniqueInfo> wingTechniqueExamples() => [
      TechniqueInfo(
        id: 'skyscraper',
        name: '摩天楼',
        summary: '两列（或两行）上各有一条同数字强链，删同时看到两条链远端的候选。',
        definition: '摩天楼（Skyscraper）指某个数字在两列（或两行）上各自只剩两个候选，'
            '组成两条独立的强链，并且这两条强链有一端落在同一行（或同一列）上，'
            '像两座楼共用一段屋脊。因为每条强链的两端必有一端为真，'
            '屋脊那一行把两条链的“无关”端连在一起，凡是能同时看到两条链另一端的格子，'
            '这个数字都不可能出现，可以直接删除。',
        howToSpot: '选定一个数字，找两列（或两行）候选都恰好剩两格的强链，'
            '再看它们是否有一端共享同一行（或同一列）。',
        walkthrough: '本例中数字 3 在第 4 列的候选只剩第 2 行和第 6 行，'
            '在第 7 列的候选只剩第 1 行和第 6 行，两条强链都在第 6 行有一个端点，'
            '构成屋脊。无论两条链具体怎么取值，第 1 行第 6 列（同时看到第 6 行第 4 列'
            '所在的宫、第 1 行第 7 列所在的行）和第 2 行第 8 列（同时看到第 2 行第 4 列'
            '所在的行、第 1 行第 7 列所在的宫）都不可能是 3，因此删除这两处的候选 3。',
        caveats: '两条强链必须是真正的强链（该数字在那条线上恰好只剩两格），'
            '屋脊只是端点共线，本身不必是强链，别把普通候选重合误判成摩天楼。',
        rank: 100,
        examplePuzzle:
            '024610007006070402003824560000200800301060024002001000069002100240130600130006240',
        exampleMarkup: _chainMarkup(
          start: [1, 3],
          end: [0, 6],
          nodes: [
            [5, 3],
            [5, 6],
          ],
          arrows: [
            _arrow(1, 3, 3, 5, 3, 3, ArrowKind.strong),
            _arrow(0, 6, 3, 5, 6, 3, ArrowKind.strong),
            _arrow(5, 3, 3, 5, 6, 3, ArrowKind.weak),
          ],
          eliminated: [
            [0, 5, 3],
            [1, 7, 3],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'kite',
        name: '双线风筝',
        summary: '一行一条强链、一列一条强链，两条链在同一个宫里拐弯相连，删两条链另一端的交汇格。',
        definition: '双线风筝（2-String Kite）指某个数字在一行上只剩两个候选组成强链，'
            '在一列上也只剩两个候选组成强链，并且两条强链各有一端落在同一个宫里——'
            '这两个端点像风筝的两根骨架在宫里交叉。因为这两个端点必有一个为真，'
            '两条链另外两端所在行、列的交叉格就不可能是这个数字，可以删除。',
        howToSpot: '选定一个数字，先找一行的强链，再找一列的强链，'
            '看它们是否各有一端落在同一个宫内；如果有，两条链另一端的交叉格就是删除目标。',
        walkthrough: '本例中数字 9 在第 4 行只能出现在第 5 列和第 7 列，在第 6 列只能出现'
            '在第 4 行和第 8 行，第 4 行第 5 列和第 8 行第 6 列同在一个宫内，构成拐弯。'
            '无论这两个宫内候选具体谁为真，第 4 行第 7 列（既在第 4 行看见一端，'
            '又在第 6 列看见另一端）都不可能是 9，因此删除该处候选 9。',
        caveats: '两条强链的“拐弯”端必须真正同宫，只是数值相近或位置相邻不算，'
            '删除目标要同时被两条链的另一端用行、列分别看到才成立。',
        rank: 105,
        examplePuzzle:
            '100300004375924681040010030200000007087163420000207003020801076816000302709602108',
        exampleMarkup: _chainMarkup(
          start: [3, 5],
          end: [6, 6],
          nodes: [
            [7, 5],
            [6, 4],
          ],
          arrows: [
            _arrow(3, 5, 9, 7, 5, 9, ArrowKind.strong),
            _arrow(6, 4, 9, 6, 6, 9, ArrowKind.strong),
            _arrow(7, 5, 9, 6, 4, 9, ArrowKind.weak),
          ],
          eliminated: [
            [3, 6, 9],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'empty_rect',
        name: '空矩形',
        summary: '宫内某数字的候选挤在一行一列上形成空心矩形，配合宫外一条强链删除交汇格。',
        definition: '空矩形（Empty Rectangle）指某个数字在一个宫内的候选全部挤在其中一行'
            '和一列的交叉范围内，形成一个“空心”的矩形轮廓。如果宫外恰好有一条该数字的'
            '强链，其中一端落在空矩形所在的行（或列）上，那么这条强链的另一端和空矩形'
            '所在列（或行）的交叉格，就不可能是这个数字，可以删除。',
        howToSpot: '先看某个数字在一个宫内的候选是否都挤在同一行和同一列上（呈空心矩形），'
            '再找宫外一条该数字的强链，其一端是否与空矩形共享那一行（或列）。',
        walkthrough: '本例中数字 4 在右上宫的候选都挤在第 4 行与第 9 列上，形成空矩形；'
            '第 3 列上第 4 行和第 8 行恰好是数字 4 的一条强链。第 4 行把空矩形和这条'
            '强链的一端连起来，因此强链另一端所在的第 8 行，和空矩形所在的第 9 列，'
            '两者交汇处——第 8 行第 9 列——不可能是 4，可以删除。',
        caveats: '空矩形要求宫内候选严格挤在一行一列上，多出一个候选就不成立；'
            '外部强链必须真的与空矩形共享那一行或那一列，不能只是邻近。',
        rank: 110,
        examplePuzzle:
            '498061300361009008007384090980010700136078520702000810013847900870690030009100087',
        exampleMarkup: _chainMarkup(
          start: [3, 2],
          end: [7, 2],
          nodes: [
            [3, 7],
            [3, 8],
            [4, 8],
            [5, 8],
          ],
          arrows: [
            _arrow(3, 2, 4, 7, 2, 4, ArrowKind.strong),
          ],
          eliminated: [
            [7, 8, 4],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'xy_wing',
        name: 'XY-Wing',
        summary: '支点格与两个翼格各共享一个候选，删同时看到两翼且含公共数字的格子。',
        definition: 'XY-Wing 由三个双值格组成：支点格候选是 {x, y}，'
            '两个翼格分别是 {x, z} 和 {y, z}，且支点与每个翼格都同行、同列或同宫。'
            '支点最终只能填 x 或 y：填 x 时第一个翼格被迫填 z，填 y 时第二个翼格'
            '被迫填 z——无论哪种情况，z 都会落在某个翼格上，因此同时能看到两个翼格的'
            '格子都不可能是 z，可以删除。',
        howToSpot: '先找一个双值格当支点，再看它能否连到两个双值格，'
            '其中一个和支点共享一个候选、另一个共享另一个候选，且两个翼格还各剩一个'
            '共同的第三个数字。',
        walkthrough: '本例中第 9 行第 3 列是支点，候选 {5, 7}；它与第 7 行第 2 列'
            '（候选 {4, 5}）共享候选 5，又与第 9 行第 6 列（候选 {4, 7}）共享候选 7。'
            '两个翼格都还剩候选 4：支点填 5 时右翼被迫填 4，支点填 7 时左翼被迫填 4，'
            '因此同时看到两翼的第 7 行第 6 列不可能是 4，删除该处候选 4。',
        caveats: '三格必须都恰好是双值格，支点到每个翼格的可见关系（同行/列/宫）'
            '缺一个都不成立，别把三个候选凑巧重合的格子误判成 XY-Wing。',
        rank: 120,
        examplePuzzle:
            '596002341420600785780405269964001508300948126218560904802300617109006053630100092',
        exampleMarkup: _chainMarkup(
          start: [6, 1],
          end: [8, 5],
          nodes: [
            [8, 2],
          ],
          arrows: [
            _arrow(6, 1, 5, 8, 2, 5, ArrowKind.weak),
            _arrow(8, 2, 7, 8, 5, 7, ArrowKind.weak),
          ],
          eliminated: [
            [6, 5, 4],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'xyz_wing',
        name: 'XYZ-Wing',
        summary: '支点三个候选、两翼各含其中两个且都含公共数字，删三格共同可见处的公共数字。',
        definition: 'XYZ-Wing 是 XY-Wing 的三候选版：支点格候选是 {x, y, z}，'
            '两个翼格分别是 {x, z} 和 {y, z}，支点与每个翼格都同行、同列或同宫。'
            '因为支点填 x、y 或 z 时都可能让某个翼格被迫填 z，'
            '所以只要一个格子同时能看到支点和两个翼格，这个格子就不可能是 z，可以删除。',
        howToSpot: '先找一个三值格当支点，再看它能否连到两个双值格，'
            '一个翼格候选是支点候选里的两个（含 z），另一个翼格候选是支点候选里的另两个'
            '（也含 z），三格都共享 z。',
        walkthrough: '本例中第 8 行第 4 列是支点，候选 {1, 4, 5}；它与第 8 行第 8 列'
            '（候选含 4，同行）、第 9 行第 5 列（候选含 4，同宫）相连，三格都共享候选 4。'
            '无论支点最终填 1、4 还是 5，4 总会落在支点或某个翼格上，'
            '因此同时看到三格的第 8 行第 6 列不可能是 4，删除该处候选 4。',
        caveats: '三格必须都真的共享同一个数字 z，且支点要同时看到两个翼格；'
            '漏检其中一个可见关系会把普通的三候选重合误判成 XYZ-Wing。',
        rank: 125,
        examplePuzzle:
            '964821735005697000871000269493286157587000326010375090040000570708060900109700603',
        exampleMarkup: _chainMarkup(
          start: [7, 7],
          end: [8, 4],
          nodes: [
            [7, 3],
          ],
          arrows: [
            _arrow(7, 3, 4, 7, 7, 4, ArrowKind.weak),
            _arrow(7, 3, 4, 8, 4, 4, ArrowKind.weak),
          ],
          eliminated: [
            [7, 5, 4],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'w_wing',
        name: 'W-Wing',
        summary: '两个候选相同的双值格被某数字的一条强链连上，删同时看到两格的另一个数字。',
        definition: 'W-Wing 指两个格子的候选完全相同、都是 {a, b}，且存在一条数字 b 的'
            '强链，其中一端能看到第一个双值格，另一端能看到第二个双值格。因为强链的两端'
            '必有一端为真，把 b 顶到某个双值格上，逼得那一格填 b、另一格填 a——两种情况下'
            'a 都会落在某个双值格里，因此同时能看到两个双值格的格子都不可能是 a，可以删除。',
        howToSpot: '先找两个候选完全相同的双值格 {a, b}，再看是否存在一条数字 b 的强链，'
            '两端分别能看到这两个双值格。',
        walkthrough: '本例中第 5 行第 6 列和第 4 行第 7 列的候选都是 {4, 7}；'
            '第 6 行第 6 列与第 6 行第 9 列组成候选 7 的强链，第 6 行第 6 列同列能看到'
            '第 5 行第 6 列，第 6 行第 9 列同宫能看到第 4 行第 7 列。无论强链哪端为真，'
            '数字 4 都会落在两个双值格中的一个，因此同时看到两格的第 4 行第 4、5、6 列'
            '都不可能是 4，删除这三处候选 4。',
        caveats: '两个双值格的候选必须完全一致，强链必须是真正的强链（该数字恰好只剩'
            '两格），删除的是双值格里“另一个”数字，别删成强链本身的数字。',
        rank: 130,
        examplePuzzle:
            '639000275821975643547362981052000096018690532960520810170856029285039160096200058',
        exampleMarkup: _chainMarkup(
          start: [4, 5],
          end: [3, 6],
          nodes: [
            [5, 5],
            [5, 8],
          ],
          arrows: [
            _arrow(4, 5, 7, 5, 5, 7, ArrowKind.weak),
            _arrow(5, 5, 7, 5, 8, 7, ArrowKind.strong),
            _arrow(5, 8, 7, 3, 6, 7, ArrowKind.weak),
          ],
          eliminated: [
            [3, 3, 4],
            [3, 4, 4],
            [3, 5, 4],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'wxyz_wing',
        name: 'WXYZ-Wing',
        summary: '支点四个候选、三个翼格各剩两个候选且都含同一个锁定数字，删公共可见处的它。',
        definition: 'WXYZ-Wing 由一个支点格和三个翼格组成：支点候选是 {w, x, y, z}，'
            '三个翼格分别是 {w, z}、{x, z}、{y, z}，且支点与每个翼格都同行、同列或同宫。'
            '因为支点最终只能填 w、x、y、z 中的一个，而 z 又同时出现在支点和三个翼格里，'
            '无论最终谁填了 z，这四格里必有一格是 z，因此同时能看到这四格的格子'
            '都不可能是 z，可以删除。',
        howToSpot: '先找一个四值格当支点，再看它是否能连到三个双值格，'
            '每个翼格都含支点候选里的两个数字，且三个翼格合起来正好覆盖支点的另外三个'
            '数字，四格还共享同一个数字 z。',
        walkthrough: '本例中第 1 行第 1 列是支点，候选 {3, 4, 7, 9}；第 1 行第 2 列'
            '（候选 {4, 9}）、第 2 行第 1 列（候选 {3, 4}）、第 3 行第 3 列（候选 {4, 7}）'
            '是三个翼格，四格都共享候选 4。无论支点和三翼最终怎么填，4 必然落在'
            '这四格中的一格，因此同时看到四格的第 3 行第 2 列不可能是 4，删除该处候选 4。',
        caveats: '四格必须真的共享同一个锁定数字，且支点要能看到每一个翼格；'
            '三个翼格覆盖的数字合起来要正好补满支点的四个候选，缺一个都不成立。',
        rank: 135,
        examplePuzzle:
            '006280105018059726200136098005318264081692357632574981160823579873945612529761843',
        exampleMarkup: _chainMarkup(
          start: [0, 1],
          end: [2, 2],
          nodes: [
            [0, 0],
            [1, 0],
          ],
          arrows: [
            _arrow(0, 0, 4, 0, 1, 4, ArrowKind.weak),
            _arrow(0, 0, 4, 1, 0, 4, ArrowKind.weak),
            _arrow(0, 0, 4, 2, 2, 4, ArrowKind.weak),
          ],
          eliminated: [
            [2, 1, 4],
          ],
        ),
        legend: _wxyzLegend,
      ),
      TechniqueInfo(
        id: 'simple_coloring',
        name: 'Simple Coloring',
        summary: '单数字沿强链把格子涂成两种颜色，同色互见或一格看见两色时都能删。',
        definition: 'Simple Coloring 是把一个数字所有的强链串起来染色：任选一格涂颜色 A，'
            '沿着强链走到的下一格必须涂颜色 B（强链两端一真一假），再往下交替，'
            '直到整条链上的格子都染上 A 或 B 两种颜色中的一种。这两种颜色代表这个数字'
            '的两种互斥可能：如果某个未染色的候选格能同时看到颜色 A 和颜色 B 的格子，'
            '无论最终哪种颜色为真，这个候选都会被其中一种颜色排除，因此可以直接删除。',
        howToSpot: '选定一个数字，把它所有的强链连成一张图，从任意一格出发交替染两色，'
            '再检查是否有候选格同时能看到两种颜色的格子。',
        walkthrough: '本例中数字 1 的强链把第 1 行第 4 列、第 2 行第 9 列、第 8 行第 5 列、'
            '第 7 行第 3 列染成颜色 A，把第 7 行第 4 列、第 2 行第 5 列、第 8 行第 2 列、'
            '第 5 行第 3 列染成颜色 B。第 5 行第 9 列同行能看到颜色 B 的第 5 行第 3 列，'
            '同列能看到颜色 A 的第 2 行第 9 列，两种颜色都能看到，因此这里的候选 1 '
            '不可能成立，删除。',
        caveats: '染色只能沿真正的强链交替，弱链不能用来染色；'
            '删除的前提是同一个格子真的同时看到两种颜色，只看到一种颜色不能删。',
        rank: 140,
        examplePuzzle:
            '459020000070500200123806000285001370900375020307280000090030502504902080702058010',
        exampleMarkup: _coloringMarkup(
          colorA: [
            [0, 3],
            [1, 8],
            [7, 4],
            [6, 2],
          ],
          colorB: [
            [6, 3],
            [1, 4],
            [7, 1],
            [4, 2],
          ],
          arrows: [
            _arrow(0, 3, 1, 6, 3, 1, ArrowKind.strong),
            _arrow(0, 3, 1, 1, 4, 1, ArrowKind.strong),
            _arrow(6, 3, 1, 6, 2, 1, ArrowKind.strong),
            _arrow(6, 3, 1, 7, 4, 1, ArrowKind.strong),
            _arrow(1, 4, 1, 1, 8, 1, ArrowKind.strong),
            _arrow(1, 4, 1, 7, 4, 1, ArrowKind.strong),
            _arrow(7, 4, 1, 7, 1, 1, ArrowKind.strong),
            _arrow(7, 1, 1, 6, 2, 1, ArrowKind.strong),
            _arrow(6, 2, 1, 4, 2, 1, ArrowKind.strong),
          ],
          eliminated: [
            [4, 8, 1],
          ],
        ),
        legend: _coloringLegend,
      ),
      TechniqueInfo(
        id: 'ur1',
        name: '唯一矩形 Type 1',
        summary: '题目保证唯一解：2×2 矩形三格都是 {a,b}，第四格多一个数字，必须填那个。',
        definition: '唯一矩形（Unique Rectangle）利用「数独题目保证只有一个解」这个前提：'
            '如果一个 2×2 矩形横跨两行两列，四格恰好落在同两个宫里，其中三格的候选都'
            '恰好是同样的两个数字 {a, b}，第四格除了 {a, b} 还多一个数字，'
            '那么第四格就不能是 a 也不能是 b——如果它是 a 或 b，四格就会形成一个'
            'a、b 可以互相对调的“死亡矩形”，导致题目有两个解，与唯一解的前提矛盾。'
            '因此第四格只能填那个多出来的数字。',
        howToSpot: '先找一个横跨两行两列、落在两个不同宫里的矩形，'
            '看是否有三格候选恰好都是同样两个数字，第四格是否只多了一个候选。',
        walkthrough: '本例中第 1 行第 1 列、第 1 行第 4 列、第 2 行第 1 列的候选都是 '
            '{1, 7}，第 2 行第 4 列的候选是 {1, 5, 7}。如果第 2 行第 4 列填 1 或 7，'
            '这四格就能在两组解之间互相对调，题目就不再唯一，与前提矛盾，'
            '因此第 2 行第 4 列只能填 5。',
        caveats: '矩形必须横跨两个不同的宫，如果四格全部落在同一个宫里就不成立；'
            '判断前要确认题目本身确实只有一个解，这是整个推理的前提。',
        rank: 150,
        examplePuzzle:
            '049086253028043609653902874385471962274659138916238547462395781897064325531827496',
        exampleMarkup: _urMarkup(
          rectangle: [
            [0, 0],
            [0, 3],
            [1, 0],
            [1, 3],
          ],
          extraCandidates: [
            [1, 3, 5],
          ],
        ),
        legend: _urLegend,
      ),
      TechniqueInfo(
        id: 'ur2',
        name: '唯一矩形 Type 2',
        summary: '题目保证唯一解：矩形里同一个额外数字出现两次，删它们共同可见处的这个数字。',
        definition: '唯一矩形 Type 2 指矩形四格里，两格候选恰好是同样的两个数字 {a, b}，'
            '另外两格除了 {a, b} 还各多出同一个数字 c。为了避免四格里的 a、b '
            '能互相对调形成多解的死亡矩形，这两个额外候选里必须至少有一个是 c，'
            '所以只要某个格子能同时看到这两个多出 c 的格子，它的候选 c 就可以删除。',
        howToSpot: '先找一个横跨两个宫的矩形，两格是纯 {a, b}，另外两格除了 {a, b} '
            '还都多出同一个数字 c，再看谁能同时看到这两个多出 c 的格子。',
        walkthrough: '本例中第 7 行第 2 列、第 9 行第 2 列的候选是纯 {1, 2}，'
            '第 7 行第 4 列、第 9 行第 4 列除了 {1, 2} 还都多出候选 3。'
            '为了不让矩形出现死亡对调，这两格里必须有一个填 3，'
            '因此同时看到它们的第 1 行第 4 列、第 8 行第 5 列的候选 3 都可以删除。',
        caveats: '两个额外候选必须是同一个数字，且要能被同一个格子同时看到才能删；'
            '如果额外数字不一样，就要按 Type 3 或其它类型分析。',
        rank: 155,
        examplePuzzle:
            '687040001031008700049701008123596800956874123874123500005082410012400080408010002',
        exampleMarkup: _urMarkup(
          rectangle: [
            [6, 1],
            [6, 3],
            [8, 1],
            [8, 3],
          ],
          extraCandidates: [
            [6, 3, 3],
            [8, 3, 3],
          ],
          eliminated: [
            [0, 3, 3],
            [7, 4, 3],
          ],
        ),
        legend: _urLegend,
      ),
      TechniqueInfo(
        id: 'ur3',
        name: '唯一矩形 Type 3',
        summary: '题目保证唯一解：额外候选和同一区域里的其它格子组成数组，当数组一起删。',
        definition: '唯一矩形 Type 3 指矩形四格里两格是纯 {a, b}，另外两格除了 {a, b} '
            '还各多出一些额外候选。为了避免死亡矩形，这两个额外格里必须有一个填 a 或 b，'
            '于是可以把这两格的额外候选当成一个整体，和同一行、列或宫里其它候选相同的'
            '格子拼成一个数组（数对、三数组……），再按普通数组的规则删除同区域里'
            '其它格子上重复的候选。',
        howToSpot: '先找矩形里两个额外格子的候选（去掉 {a, b} 之后），'
            '看它们和同一行/列/宫里其它候选是否恰好能拼成一个数组。',
        walkthrough: '本例中第 6 行第 4 列、第 6 行第 5 列的候选除了 {1, 2} 还都多出'
            '{6, 7}，相当于一个隐藏在矩形里的数对 {6, 7}。这个数对和第 6 行的其它格子'
            '构成显性数对，因此第 6 行第 1、2、8 列上和它们重复的候选 6、7 都要删除。',
        caveats: '额外候选去掉矩形本身的 {a, b} 之后才是真正要拼数组的部分，'
            '别把 {a, b} 也算进数组里，否则会多删或少删。',
        rank: 160,
        examplePuzzle:
            '300090002020104000090300700643519287875003914219007635002001000000905020900030006',
        exampleMarkup: _urMarkup(
          rectangle: [
            [5, 3],
            [5, 4],
            [6, 3],
            [6, 4],
          ],
          extraCandidates: [
            [6, 3, 6],
            [6, 3, 7],
            [6, 4, 6],
            [6, 4, 7],
          ],
          eliminated: [
            [6, 0, 7],
            [6, 1, 6],
            [6, 7, 7],
          ],
        ),
        legend: _urLegend,
      ),
      TechniqueInfo(
        id: 'ur4',
        name: '唯一矩形 Type 4',
        summary: '题目保证唯一解：矩形所在线上一个数字形成强链，删矩形内另一个数字。',
        definition: '唯一矩形 Type 4 指矩形四格都恰好是同样的两个数字 {a, b}，'
            '其中一组对角所在的行或列上，数字 a（或 b）刚好只剩这两格能填，形成强链。'
            '因为强链保证 a 必然落在这两格之一，为了不让另一个数字 b 在这两格里同时'
            '出现两次形成死亡对调，这两格就都不能再是 b 了，可以把 b 从这两格删除。',
        howToSpot: '先找矩形四格是否都恰好是 {a, b}，再看矩形所在的某一行或某一列上，'
            '其中一个数字是否正好只剩矩形那两格能填（强链）。',
        walkthrough: '本例中第 4 行第 3 列、第 4 行第 9 列、第 5 行第 3 列、第 5 行第 9 列'
            '的候选都是 {4, 5}，且第 9 列上数字 5 只剩第 4 行和第 5 行这两格能填，'
            '形成强链。5 必然落在这两格之一，为了避免死亡对调，这两格都不能再是 4，'
            '因此删除第 4 行第 9 列、第 5 行第 9 列的候选 4。',
        caveats: '强链必须落在矩形本身所在的行或列上，且矩形四格要先确认真的都是'
            '同样的 {a, b}，否则不能套用 Type 4 的强链结论。',
        rank: 165,
        examplePuzzle:
            '360000050459760020780530040920000000830000000176045200643800579290650130510000002',
        exampleMarkup: _urMarkup(
          rectangle: [
            [3, 2],
            [3, 8],
            [4, 2],
            [4, 8],
          ],
          extraCandidates: [
            [3, 8, 5],
            [4, 8, 5],
          ],
          eliminated: [
            [3, 8, 4],
            [4, 8, 4],
          ],
          arrows: [
            _arrow(3, 8, 5, 4, 8, 5, ArrowKind.strong),
          ],
        ),
        legend: _urLegend,
      ),
      TechniqueInfo(
        id: 'bug1',
        name: 'BUG+1',
        summary: '题目保证唯一解：除一格外将构成多解双值盘，那一格必须填多出来的候选。',
        definition: 'BUG+1（Bivalue Universal Grave + 1）指整块盘面除了一个格子以外，'
            '所有空格的候选都恰好是两个数字（双值格），只有一个格子例外，'
            '候选比别的格子多一个。如果这个例外格填了它候选中「在所在行、列、宫里都'
            '出现偶数次」的那个数字，整块盘面就会退化成经典的双值墓地（BUG），'
            '出现可以互相对调、题目多解的死局，与唯一解前提矛盾。因此这个例外格'
            '必须填那个「在所在行、列、宫里出现奇数次」的候选，其余候选都要删除。',
        howToSpot: '先扫一遍所有空格的候选数，如果只有一个格子的候选数比其它双值格'
            '多一个，就去数它每个候选在所在行、列、宫里各出现了几次。',
        walkthrough: '本例中第 4 行第 8 列是唯一的三值格，候选是 {2, 5, 6}。'
            '数字 5 在这一行、这一列、这一宫里都各出现 3 次（奇数次），'
            '而数字 2 和 6 都各出现 2 次（偶数次）。如果填 2 或 6，'
            '盘面就会退化成可以对调的双值墓地、题目多解，因此第 4 行第 8 列必须填 5，'
            '候选 2 和 6 都要删除。',
        caveats: '一定要先确认「只有一个格子例外、其余全是双值格」这个前提成立，'
            '再去数候选出现次数；只要还有第二个非双值格，BUG+1 的结论就不成立。',
        rank: 170,
        examplePuzzle:
            '483716295125938647796542381004800109018200704600104803861359472030487516547621938',
        exampleMarkup: _urMarkup(
          rectangle: [
            [3, 7],
            [3, 1],
            [4, 7],
            [5, 7],
          ],
          extraCandidates: [
            [3, 7, 5],
            [3, 1, 5],
            [4, 7, 5],
            [5, 7, 5],
          ],
          eliminated: [
            [3, 7, 2],
            [3, 7, 6],
          ],
        ),
        legend: _bugLegend,
      ),
    ];
