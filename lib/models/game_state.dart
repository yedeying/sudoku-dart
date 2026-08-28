import 'package:flutter/material.dart';
import 'sudoku_board.dart';
import 'board_markup.dart';
import 'puzzle_grade.dart';
import '../services/current_game_store.dart';
import '../services/puzzle_bank.dart';
import '../services/sudoku_solver.dart';

enum HintPhase { none, offerDeep, failed, ready }

class HintSession {
  final SudokuHint? hint;
  final bool fromDeepSearch;
  final HintPhase phase;

  const HintSession({
    this.hint,
    this.fromDeepSearch = false,
    required this.phase,
  });
}

/// 游戏状态管理
class GameState extends ChangeNotifier {
  SudokuBoard? _board;
  String _difficulty = 'normal';
  String? _puzzleId;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  int _hintsUsed = 0;
  bool _isPlaying = false;
  int? _selectedRow;
  int? _selectedCol;
  bool _justCompleted = false;
  MarkupMode markupMode = MarkupMode.off;
  BoardMarkup userMarkup = BoardMarkup();
  BoardMarkup? hintMarkup;
  HintSession? hintSession;
  CandidateRef? arrowAnchor;
  Color markupColor = MarkupPalette.colors.first;
  String? autoStrongNotice;

  /// 由强/弱链模式推导，不再单独设置
  ArrowKind? get pendingArrowKind {
    switch (markupMode) {
      case MarkupMode.strong:
        return ArrowKind.strong;
      case MarkupMode.weak:
        return ArrowKind.weak;
      case MarkupMode.off:
      case MarkupMode.cellColor:
      case MarkupMode.candidateColor:
      case MarkupMode.autoStrong:
        return null;
    }
  }

  // 候选数功能
  bool _showCandidates = false;
  bool _candidateMode = false;

  // 撤销/重做历史
  final List<GameMove> _history = [];
  int _historyIndex = -1;

  // Getters
  SudokuBoard? get board => _board;
  String get difficulty => _difficulty;
  String? get puzzleId => _puzzleId;
  bool get hasResumableGame =>
      _board != null && _isPlaying && !_justCompleted && !_board!.isComplete();
  int get elapsedSeconds => _elapsedSeconds;
  int get hintsUsed => _hintsUsed;
  bool get isPlaying => _isPlaying;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;

  /// 提示展示期间不把选格、行列宫、同数字弱高亮叠在技巧标记上。
  bool get hintActive =>
      hintSession != null && hintSession!.phase != HintPhase.none;

  int? get displaySelectedRow => hintActive ? null : _selectedRow;
  int? get displaySelectedCol => hintActive ? null : _selectedCol;
  bool get canUndo => _historyIndex >= 0;
  bool get canRedo => _historyIndex < _history.length - 1;
  bool get showCandidates => _showCandidates;
  bool get candidateMode => _candidateMode;
  bool get justCompleted => _justCompleted;
  bool get markupEnabled => markupMode != MarkupMode.off;

  BoardMarkup get displayMarkup {
    final merged = userMarkup.copy();
    if (hintMarkup != null) {
      merged.cellColors.addAll(hintMarkup!.cellColors);
      merged.candidateColors.addAll(hintMarkup!.candidateColors);
      merged.arrows.addAll(hintMarkup!.arrows);
      merged.struck.addAll(hintMarkup!.struck);
    }
    return merged;
  }

  /// 开始新游戏：从内置题库按难度随机抽一题，覆盖当前缓存。
  Future<void> startNewGame(String difficulty) async {
    final record = await PuzzleBank.loadRecord(difficulty);
    _difficulty = difficulty;
    _puzzleId = record.id;
    _board = SudokuBoard.fromString(record.grid);
    _resetSessionState();
    notifyListeners();
    await _persistCurrent();
  }

  /// 启动时恢复上一盘未完成的对局（含自定义）。没有就不做事。
  Future<void> restoreCurrent() async {
    try {
      final data = await CurrentGameStore.read();
      if (data == null) return;
      final board = CurrentGameStore.restoreBoard(data);
      if (board.isComplete()) {
        await CurrentGameStore.clear();
        return;
      }
      _board = board;
      _difficulty = data['difficulty'] as String? ?? 'custom';
      _puzzleId = data['id'] as String?;
      _elapsedSeconds = data['elapsedSeconds'] as int? ?? 0;
      _hintsUsed = data['hintsUsed'] as int? ?? 0;
      _showCandidates = data['showCandidates'] as bool? ?? false;
      _candidateMode = data['candidateMode'] as bool? ?? false;
      _startTime = DateTime.now().subtract(Duration(seconds: _elapsedSeconds));
      _isPlaying = true;
      _justCompleted = false;
      notifyListeners();
    } catch (_) {
      await CurrentGameStore.clear();
    }
  }

  /// 加载示例游戏（用于快速测试）
  Future<void> loadExampleGame(String difficulty) async {
    await startNewGame(difficulty);
  }

  /// 教学页「用此盘对局」时切到对局页。
  int? _requestedShellIndex;
  int? get requestedShellIndex => _requestedShellIndex;

  void clearShellRequest() {
    _requestedShellIndex = null;
  }

  /// 从字符串加载游戏（手动输入）
  void loadCustomGame(
    String puzzleString, {
    bool showCandidates = false,
    int? shellIndex,
    String difficulty = 'custom',
  }) {
    try {
      _board = SudokuBoard.fromString(puzzleString);
      _difficulty = difficulty;
      _puzzleId = difficulty == 'custom' ? 'custom' : _puzzleId ?? 'custom';
      _resetSessionState();
      _showCandidates = showCandidates;
      if (shellIndex != null) _requestedShellIndex = shellIndex;
      notifyListeners();
      _persistCurrent();
    } catch (e) {
      debugPrint('加载自定义游戏失败: $e');
    }
  }

  /// 把教学页上的那张盘带进对局，并打开候选。
  void loadTeachingBoard(String puzzleString) {
    loadCustomGame(puzzleString, showCandidates: true, shellIndex: 0);
  }

  /// 新棋盘 = 全新一局：显示开关、笔记模式、标记全部回到初始状态。
  void _resetSessionState() {
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _hintsUsed = 0;
    _isPlaying = true;
    _justCompleted = false;
    _selectedRow = null;
    _selectedCol = null;
    _history.clear();
    _historyIndex = -1;
    _showCandidates = false;
    _candidateMode = false;
    markupColor = MarkupPalette.colors.first;
    markupMode = MarkupMode.off;
    _clearBoardMarkup();
  }

  /// 清掉棋盘上的一切标记与进行中的提示。
  void _clearBoardMarkup() {
    userMarkup = BoardMarkup();
    hintMarkup = null;
    hintSession = null;
    arrowAnchor = null;
    autoStrongNotice = null;
  }

  /// 消费“刚完成”标志（避免重复弹窗）
  void consumeCompletionFlag() {
    _justCompleted = false;
  }

  /// 选择格子
  void selectCell(int row, int col) {
    if (_selectedRow == row && _selectedCol == col) {
      _selectedRow = null;
      _selectedCol = null;
    } else {
      _selectedRow = row;
      _selectedCol = col;
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedRow == null && _selectedCol == null) return;
    _selectedRow = null;
    _selectedCol = null;
    notifyListeners();
  }

  /// 高亮格沿行列移动，到边后绕回。无选中时不做事。
  bool moveSelection(int dRow, int dCol) {
    if (_selectedRow == null || _selectedCol == null) return false;
    _selectedRow = (_selectedRow! + dRow + 9) % 9;
    _selectedCol = (_selectedCol! + dCol + 9) % 9;
    notifyListeners();
    return true;
  }

  /// 键盘数字：玩法下空格 toggle 候选，Shift 填成数；标记态走数字区同一套路由。
  bool handleDigitKey(int number, {required bool shift}) {
    if (_board == null || hintActive) return false;
    if (number < 1 || number > 9) return false;

    switch (markupMode) {
      case MarkupMode.off:
        if (_selectedRow == null || _selectedCol == null) return false;
        if (_board!.isInitial(_selectedRow!, _selectedCol!)) return false;
        if (_board!.get(_selectedRow!, _selectedCol!) != 0) return false;
        final wasNotes = _candidateMode;
        _candidateMode = !shift;
        placeNumber(number);
        _candidateMode = wasNotes;
        return true;
      case MarkupMode.candidateColor:
        if (_selectedRow == null) {
          toggleGlobalCandidateColor(number);
          return true;
        }
        onNumberPad(number);
        return true;
      case MarkupMode.strong:
      case MarkupMode.weak:
        if (_selectedRow == null || _selectedCol == null) return false;
        onNumberPad(number);
        return true;
      case MarkupMode.autoStrong:
        onNumberPad(number);
        return true;
      case MarkupMode.cellColor:
        return false;
    }
  }

  /// 删掉手填成数并重算候选。题目已知数不动。
  bool handleBackspace() {
    if (_board == null || hintActive) return false;
    if (markupMode != MarkupMode.off) return false;
    if (_selectedRow == null || _selectedCol == null) return false;
    if (_board!.isInitial(_selectedRow!, _selectedCol!)) return false;
    if (_board!.get(_selectedRow!, _selectedCol!) == 0) return false;
    clearSelected();
    return true;
  }

  /// 无选中时：该数字已有候选色则全部去掉，否则给盘上所有该数字候选涂当前色。
  void toggleGlobalCandidateColor(int digit) {
    if (_board == null) return;
    final existing = [
      for (final e in userMarkup.candidateColors.entries)
        if (e.key.num == digit) e.key,
    ];
    if (existing.isNotEmpty) {
      for (final ref in existing) {
        userMarkup.candidateColors.remove(ref);
      }
    } else {
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (_board!.visibleCandidates(r, c).contains(digit)) {
            userMarkup.candidateColors[CandidateRef(r, c, digit)] = markupColor;
          }
        }
      }
    }
    notifyListeners();
  }

  /// 在选中的格子填入数字
  void placeNumber(int number) {
    if (_board == null || _selectedRow == null || _selectedCol == null) {
      return;
    }

    if (_board!.isInitial(_selectedRow!, _selectedCol!)) {
      return;
    }

    // 候选数模式：切换候选数字，并记入历史
    if (_candidateMode) {
      final had = _board!
          .visibleCandidates(_selectedRow!, _selectedCol!)
          .contains(number);
      _addToHistory(GameMove.candidate(
        row: _selectedRow!,
        col: _selectedCol!,
        candidateNum: number,
        candidateAdded: !had,
      ));
      _board!.toggleUserCandidate(_selectedRow!, _selectedCol!, number);
      _showCandidates = true;
      notifyListeners();
      _persistCurrent();
      return;
    }

    int oldValue = _board!.get(_selectedRow!, _selectedCol!);
    if (oldValue == number) return;

    _addToHistory(GameMove(
      row: _selectedRow!,
      col: _selectedCol!,
      oldValue: oldValue,
      newValue: number,
    ));

    _board!.set(_selectedRow!, _selectedCol!, number);
    _board!.clearUserCandidates(_selectedRow!, _selectedCol!);

    if (_board!.isComplete()) {
      _isPlaying = false;
      _justCompleted = true;
    }
    _persistCurrent();

    notifyListeners();
  }

  /// 清除选中的格子
  void clearSelected() {
    if (_board == null || _selectedRow == null || _selectedCol == null) {
      return;
    }

    if (_board!.isInitial(_selectedRow!, _selectedCol!)) {
      return;
    }

    int oldValue = _board!.get(_selectedRow!, _selectedCol!);
    if (oldValue == 0) return;

    _addToHistory(GameMove(
      row: _selectedRow!,
      col: _selectedCol!,
      oldValue: oldValue,
      newValue: 0,
    ));

    _board!.clear(_selectedRow!, _selectedCol!);
    _showCandidates = true;
    notifyListeners();
    _persistCurrent();
  }

  /// 获取提示（不增加提示计数，仅查看）。
  /// 浅搜写入 [HintPhase.ready] 或 [HintPhase.offerDeep]；
  /// [deep] 为 true 时写入 ready 或 [HintPhase.failed]。
  /// 已有非 none 的 session 时忽略浅搜（再次点提示无效）。
  SudokuHint? getHint({bool deep = false}) {
    if (_board == null) return null;

    final active = hintSession != null && hintSession!.phase != HintPhase.none;
    if (active && !deep) return null;

    var hint = SudokuSolver.getHint(_board!);
    if (hint != null) {
      hintMarkup = markupFromHint(hint);
      hintSession = HintSession(
        hint: hint,
        fromDeepSearch: deep,
        phase: HintPhase.ready,
      );
      if (_hintUsesCandidates(hint)) _showCandidates = true;
    } else if (deep) {
      hintMarkup = null;
      hintSession = const HintSession(
        fromDeepSearch: true,
        phase: HintPhase.failed,
      );
    } else {
      hintMarkup = null;
      hintSession = const HintSession(phase: HintPhase.offerDeep);
    }
    notifyListeners();
    return hint;
  }

  /// 从 offerDeep 进入深搜：成功 → ready，失败 → failed。
  void requestDeepSearch() {
    getHint(deep: true);
  }

  /// 应用当前提示，并顺手找出下一步。
  ///
  /// 找不到下一步时静默收起面板，不再弹深搜询问——连点应用的过程中
  /// 不该被追问是否深搜。
  void applyHintAndAdvance(SudokuHint hint) {
    applyHint(hint);
    if (_board == null) return;
    final next = SudokuSolver.getHint(_board!);
    if (next == null) return;
    hintMarkup = markupFromHint(next);
    hintSession = HintSession(hint: next, phase: HintPhase.ready);
    if (_hintUsesCandidates(next)) _showCandidates = true;
    notifyListeners();
  }

  static const _hintWashes = {
    HintRole.pattern: Color(0xFFBBDEFB),
    HintRole.cover: Color(0xFFD1C4E9),
    HintRole.extra: Color(0xFFF3E5AB),
    HintRole.link: Color(0xFFC8E6C9),
    HintRole.target: Color(0xFFFFCDD2),
  };

  static Color _hintCandidateColor(HintRole role) {
    switch (role) {
      case HintRole.pattern:
        return MarkupPalette.blue;
      case HintRole.cover:
        return MarkupPalette.purple;
      case HintRole.extra:
        return MarkupPalette.gold;
      case HintRole.link:
        return MarkupPalette.green;
      case HintRole.target:
        return MarkupPalette.red;
    }
  }

  static int _hintPriority(HintRole role) {
    switch (role) {
      case HintRole.target:
        return 4;
      case HintRole.extra:
        return 3;
      case HintRole.link:
        return 2;
      case HintRole.cover:
        return 2;
      case HintRole.pattern:
        return 1;
    }
  }

  static BoardMarkup markupFromHint(SudokuHint hint) {
    final m = BoardMarkup();
    final cellRole = <int, HintRole>{};

    for (final r in hint.highlightRows) {
      for (var c = 0; c < 9; c++) {
        m.cellColors[BoardMarkup.cellKey(r, c)] = MarkupPalette.house;
      }
    }
    for (final c in hint.highlightCols) {
      for (var r = 0; r < 9; r++) {
        m.cellColors[BoardMarkup.cellKey(r, c)] = MarkupPalette.house;
      }
    }
    for (final b in hint.highlightBoxes) {
      final top = (b ~/ 3) * 3;
      final left = (b % 3) * 3;
      for (var r = top; r < top + 3; r++) {
        for (var c = left; c < left + 3; c++) {
          m.cellColors[BoardMarkup.cellKey(r, c)] = MarkupPalette.house;
        }
      }
    }

    void putCell(int row, int col, HintRole role) {
      final key = BoardMarkup.cellKey(row, col);
      final prev = cellRole[key];
      if (prev == null || _hintPriority(role) > _hintPriority(prev)) {
        cellRole[key] = role;
      }
    }

    for (final cell in hint.patternCells) {
      putCell(cell.row, cell.col, cell.role);
    }
    if (hint.isElimination) {
      for (final e in hint.eliminations) {
        putCell(e.row, e.col, HintRole.target);
        m.struck.add(CandidateRef(e.row, e.col, e.num));
      }
    } else if (hint.patternCells.isEmpty) {
      putCell(hint.row, hint.col, HintRole.pattern);
    }

    for (final entry in cellRole.entries) {
      m.cellColors[entry.key] = _hintWashes[entry.value]!;
    }
    for (final cand in hint.patternCandidates) {
      m.candidateColors[cand.ref] = _hintCandidateColor(cand.role);
    }
    for (final arrow in hint.links) {
      m.candidateColors.putIfAbsent(
        arrow.from,
        () => _hintCandidateColor(HintRole.link),
      );
      m.candidateColors.putIfAbsent(
        arrow.to,
        () => _hintCandidateColor(HintRole.link),
      );
    }
    m.arrows.addAll(hint.links);
    return m;
  }

  /// 当前盘面 81 位数字串（空格为 0），用于分享残局。
  String exportPuzzle() => _board?.toStringRepresentation() ?? '';

  /// 连续应用基础技巧，不计提示次数。
  ///
  /// 默认只走唯余，[includeHiddenSingle] 再加上摒除。专业 / 大师 / 地狱 /
  /// 自定义还会连走数对、数组、区块的删除，再继续填。
  ({int filled, int eliminated}) applySimpleFills({
    required bool includeHiddenSingle,
  }) {
    if (_board == null) return (filled: 0, eliminated: 0);
    final allowed = <String>{'唯余法'};
    if (includeHiddenSingle) allowed.add('摒除法（行/列/宫）');
    final extended = PuzzleGrades.extendsQuickFill(_difficulty);
    if (extended) {
      allowed
        ..add('摒除法（行/列/宫）')
        ..addAll(PuzzleGrades.quickFillExtraTechniques);
    }
    var filled = 0;
    var eliminated = 0;
    for (var i = 0; i < 200; i++) {
      final hint = SudokuSolver.getHint(_board!);
      if (hint == null) break;
      if (!allowed.contains(hint.technique)) break;
      applyHint(hint, countHint: false);
      if (hint.isElimination) {
        eliminated += hint.eliminations.length;
      } else {
        filled++;
      }
    }
    clearHintMarkup();
    return (filled: filled, eliminated: eliminated);
  }

  /// 自动应用提示（填数或删除候选），默认计一次提示
  void applyHint(SudokuHint hint, {bool countHint = true}) {
    if (countHint) _hintsUsed++;
    _selectedRow = hint.row;
    _selectedCol = hint.col;

    if (hint.isElimination) {
      final records = <CandidateElimUndo>[];
      for (final e in hint.eliminations) {
        final hadUser =
            _board?.userCandidates[e.row][e.col].contains(e.num) ?? false;
        final changed =
            _board?.eliminateCandidate(e.row, e.col, e.num) ?? false;
        _board?.userCandidates[e.row][e.col].remove(e.num);
        if (changed || hadUser) {
          records.add(CandidateElimUndo(
            row: e.row,
            col: e.col,
            num: e.num,
            hadUserCandidate: hadUser,
          ));
        }
      }
      if (records.isNotEmpty) {
        _addToHistory(GameMove.eliminations(records));
      }
      _showCandidates = true;
      hintMarkup = null;
      hintSession = null;
      notifyListeners();
      _persistCurrent();
      return;
    }

    // 填数：先清 session，再 placeNumber（其 notify 时面板已关闭）
    final wasCandidateMode = _candidateMode;
    _candidateMode = false;
    hintMarkup = null;
    hintSession = null;
    placeNumber(hint.value);
    _candidateMode = wasCandidateMode;
    notifyListeners();
  }

  void clearHintMarkup() {
    hintMarkup = null;
    hintSession = null;
    notifyListeners();
  }

  void toggleMarkupEnabled() {
    if (markupMode == MarkupMode.off) {
      setMarkupMode(MarkupMode.cellColor);
    } else {
      setMarkupMode(MarkupMode.off);
    }
  }

  void setMarkupMode(MarkupMode mode) {
    markupMode = mode;
    arrowAnchor = null;
    if (_markupUsesCandidates(mode)) _showCandidates = true;
    notifyListeners();
  }

  void setMarkupColor(Color color) {
    markupColor = color;
    notifyListeners();
  }

  /// 标记关闭且选中成数时，同数字成数格弱高亮（不写 markup）
  Set<int> sameDigitHighlightCells() {
    if (hintActive || markupMode != MarkupMode.off) return {};
    if (_board == null || _selectedRow == null || _selectedCol == null) {
      return {};
    }
    final value = _board!.get(_selectedRow!, _selectedCol!);
    if (value == 0) return {};
    final keys = <int>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board!.get(r, c) == value) {
          keys.add(BoardMarkup.cellKey(r, c));
        }
      }
    }
    return keys;
  }

  /// 标记关闭且选中成数时，同数字可见候选弱高亮（不写 markup）
  Set<CandidateRef> sameDigitHighlightCandidates() {
    if (hintActive || markupMode != MarkupMode.off) return {};
    if (_board == null || _selectedRow == null || _selectedCol == null) {
      return {};
    }
    final value = _board!.get(_selectedRow!, _selectedCol!);
    if (value == 0) return {};
    final refs = <CandidateRef>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board!.visibleCandidates(r, c).contains(value)) {
          refs.add(CandidateRef(r, c, value));
        }
      }
    }
    return refs;
  }

  /// 选格；仅在格色模式下上色（同色再点取消）
  void onCellTap(int row, int col) {
    if (markupMode == MarkupMode.off) {
      selectCell(row, col);
      return;
    }
    _selectedRow = row;
    _selectedCol = col;
    if (markupMode == MarkupMode.cellColor) {
      final key = BoardMarkup.cellKey(row, col);
      if (userMarkup.cellColors[key] == markupColor) {
        userMarkup.cellColors.remove(key);
      } else {
        userMarkup.cellColors[key] = markupColor;
      }
    }
    notifyListeners();
  }

  void paintSelectedCell() {
    if (_selectedRow == null || _selectedCol == null) return;
    userMarkup.cellColors[BoardMarkup.cellKey(_selectedRow!, _selectedCol!)] =
        markupColor;
    notifyListeners();
  }

  /// 数字键路由：填数 / 笔记 / 候选色 / 链锚点 / 自动强链
  void onNumberPad(int number) {
    if (_board == null) return;
    switch (markupMode) {
      case MarkupMode.off:
        placeNumber(number);
        return;
      case MarkupMode.cellColor:
        return;
      case MarkupMode.candidateColor:
        if (_selectedRow == null) {
          toggleGlobalCandidateColor(number);
        } else {
          _toggleSelectedCandidateColor(number);
        }
        return;
      case MarkupMode.strong:
      case MarkupMode.weak:
        if (_selectedRow == null || _selectedCol == null) return;
        final r = _selectedRow!;
        final c = _selectedCol!;
        if (_board!.get(r, c) != 0) return;
        if (!_board!.visibleCandidates(r, c).contains(number)) return;
        onCandidateMarkupTap(r, c, number);
        return;
      case MarkupMode.autoStrong:
        paintAutoStrong(number);
        return;
    }
  }

  bool isNumberPadEnabled(int number) {
    if (_board == null) return false;
    switch (markupMode) {
      case MarkupMode.off:
        return _selectedRow != null &&
            _selectedCol != null &&
            !_board!.isInitial(_selectedRow!, _selectedCol!);
      case MarkupMode.cellColor:
        return false;
      case MarkupMode.candidateColor:
        if (_selectedRow == null || _selectedCol == null) return true;
        final cr = _selectedRow!;
        final cc = _selectedCol!;
        if (_board!.get(cr, cc) != 0) return false;
        return _board!.visibleCandidates(cr, cc).contains(number);
      case MarkupMode.strong:
      case MarkupMode.weak:
        if (_selectedRow == null || _selectedCol == null) return false;
        final r = _selectedRow!;
        final c = _selectedCol!;
        if (_board!.get(r, c) != 0) return false;
        return _board!.visibleCandidates(r, c).contains(number);
      case MarkupMode.autoStrong:
        return true;
    }
  }

  void _toggleSelectedCandidateColor(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    final r = _selectedRow!;
    final c = _selectedCol!;
    if (_board!.get(r, c) != 0) return;
    if (!_board!.visibleCandidates(r, c).contains(number)) return;
    final ref = CandidateRef(r, c, number);
    if (userMarkup.candidateColors[ref] == markupColor) {
      userMarkup.candidateColors.remove(ref);
    } else {
      userMarkup.candidateColors[ref] = markupColor;
    }
    notifyListeners();
  }

  /// 点棋盘上的小数字：候选色模式直接上色，强/弱链模式设锚点或连线。
  void onCandidateTap(int row, int col, int num) {
    if (_board == null) return;
    if (!_board!.visibleCandidates(row, col).contains(num)) return;
    switch (markupMode) {
      case MarkupMode.candidateColor:
        final ref = CandidateRef(row, col, num);
        if (userMarkup.candidateColors[ref] == markupColor) {
          userMarkup.candidateColors.remove(ref);
        } else {
          userMarkup.candidateColors[ref] = markupColor;
        }
        notifyListeners();
        return;
      case MarkupMode.strong:
      case MarkupMode.weak:
        onCandidateMarkupTap(row, col, num);
        return;
      case MarkupMode.off:
      case MarkupMode.cellColor:
      case MarkupMode.autoStrong:
        return;
    }
  }

  /// 仅强/弱链：点候选设锚点或画箭头。其它模式勿调用（由 UI 不接线）。
  void onCandidateMarkupTap(int row, int col, int num) {
    final kind = pendingArrowKind;
    if (kind == null) return;

    final ref = CandidateRef(row, col, num);
    if (arrowAnchor == null) {
      arrowAnchor = ref;
    } else {
      userMarkup.addArrow(
        arrowAnchor!,
        ref,
        kind,
        _board?.candidates ?? [],
        color: markupColor,
      );
      arrowAnchor = null;
    }
    notifyListeners();
  }

  void clearAutoStrongNotice() {
    if (autoStrongNotice == null) return;
    autoStrongNotice = null;
    notifyListeners();
  }

  void setFilterDigit(int? d) {
    final next = userMarkup.copy();
    userMarkup = BoardMarkup(
      cellColors: next.cellColors,
      candidateColors: next.candidateColors,
      arrows: next.arrows,
      struck: next.struck,
      filterDigit: d,
    );
    notifyListeners();
  }

  void toggleStrikeOnSelected(int num) {
    if (_selectedRow == null || _selectedCol == null) return;
    final ref = CandidateRef(_selectedRow!, _selectedCol!, num);
    if (userMarkup.struck.contains(ref)) {
      userMarkup.struck.remove(ref);
    } else {
      userMarkup.struck.add(ref);
    }
    notifyListeners();
  }

  /// 扫描行、列、宫；恰两处则画强链。返回新增条数。
  int paintAutoStrong(int digit) {
    if (_board == null) return 0;
    autoStrongNotice = null;
    var added = 0;
    var foundExactTwo = false;

    void addPair(List<CandidateRef> hits) {
      if (hits.length != 2) return;
      foundExactTwo = true;
      final a = hits[0];
      final b = hits[1];
      final duplicate = userMarkup.arrows.any(
        (arrow) =>
            arrow.kind == ArrowKind.strong &&
            ((arrow.from == a && arrow.to == b) ||
                (arrow.from == b && arrow.to == a)),
      );
      if (duplicate) return;
      if (userMarkup.addArrow(
        a,
        b,
        ArrowKind.strong,
        _board!.candidates,
        color: markupColor,
        directed: false,
      )) {
        added++;
      }
    }

    for (int r = 0; r < 9; r++) {
      final hits = <CandidateRef>[];
      for (int c = 0; c < 9; c++) {
        if (_board!.get(r, c) == 0 &&
            _board!.getCandidates(r, c).contains(digit)) {
          hits.add(CandidateRef(r, c, digit));
        }
      }
      addPair(hits);
    }

    for (int c = 0; c < 9; c++) {
      final hits = <CandidateRef>[];
      for (int r = 0; r < 9; r++) {
        if (_board!.get(r, c) == 0 &&
            _board!.getCandidates(r, c).contains(digit)) {
          hits.add(CandidateRef(r, c, digit));
        }
      }
      addPair(hits);
    }

    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        final hits = <CandidateRef>[];
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            final r = br * 3 + i;
            final c = bc * 3 + j;
            if (_board!.get(r, c) == 0 &&
                _board!.getCandidates(r, c).contains(digit)) {
              hits.add(CandidateRef(r, c, digit));
            }
          }
        }
        addPair(hits);
      }
    }

    if (!foundExactTwo) {
      autoStrongNotice = '该数字没有强链';
    }
    notifyListeners();
    return added;
  }

  void clearUserMarkup() {
    userMarkup = BoardMarkup();
    arrowAnchor = null;
    notifyListeners();
  }

  /// 撤销
  void undo() {
    if (!canUndo || _board == null) return;

    hintMarkup = null;
    hintSession = null;

    var move = _history[_historyIndex];
    if (move.eliminations.isNotEmpty) {
      _applyEliminations(move, forward: false);
    } else if (move.isCandidate) {
      // 切换在可见集合上是自反的，再切一次即回到上一步。
      _board!.toggleUserCandidate(move.row, move.col, move.candidateNum!);
    } else {
      _board!.set(move.row, move.col, move.oldValue);
    }
    _historyIndex--;
    _justCompleted = false;
    if (_board!.isComplete()) {
      _isPlaying = false;
    } else {
      _isPlaying = true;
    }
    notifyListeners();
    _persistCurrent();
  }

  /// 重做
  void redo() {
    if (!canRedo || _board == null) return;

    hintMarkup = null;
    hintSession = null;

    _historyIndex++;
    var move = _history[_historyIndex];
    if (move.eliminations.isNotEmpty) {
      _applyEliminations(move, forward: true);
    } else if (move.isCandidate) {
      _board!.toggleUserCandidate(move.row, move.col, move.candidateNum!);
    } else {
      _board!.set(move.row, move.col, move.newValue);
    }

    if (_board!.isComplete()) {
      _isPlaying = false;
      _justCompleted = true;
    }
    _persistCurrent();
    notifyListeners();
  }

  void _applyEliminations(GameMove move, {required bool forward}) {
    for (final e in move.eliminations) {
      if (forward) {
        _board!.eliminateCandidate(e.row, e.col, e.num);
        _board!.userCandidates[e.row][e.col].remove(e.num);
      } else {
        _board!.eliminated[e.row][e.col].remove(e.num);
        if (e.hadUserCandidate) {
          _board!.userCandidates[e.row][e.col].add(e.num);
        }
      }
    }
    _board!.refreshCandidates();
  }

  void _addToHistory(GameMove move) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(move);
    _historyIndex++;

    if (_history.length > 100) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  /// 重置游戏
  void resetGame() {
    if (_board == null) return;

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (!_board!.isInitial(i, j)) {
          _board!.clear(i, j);
          _board!.clearUserCandidates(i, j);
          _board!.eliminated[i][j].clear();
        }
      }
    }
    _board!.refreshCandidates();

    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _hintsUsed = 0;
    _history.clear();
    _historyIndex = -1;
    _isPlaying = true;
    _justCompleted = false;
    // 棋盘内容被清空了，旧标记指向的候选已经不成立。
    _clearBoardMarkup();
    notifyListeners();
  }

  /// 更新计时器
  void updateTimer() {
    if (_isPlaying && _startTime != null) {
      _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
      notifyListeners();
    }
  }

  String getFormattedTime() {
    int minutes = _elapsedSeconds ~/ 60;
    int seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int getScore() {
    if (_board == null || !_board!.isComplete()) return 0;

    int score = 1000;
    score -= (_elapsedSeconds ~/ 60) * 10;
    score -= _hintsUsed * 50;

    score += PuzzleGrades.byId(_difficulty)?.scoreBonus ?? 200;

    return score.clamp(0, 2000);
  }

  /// 验证：相对唯一解检查已填数字是否正确（不仅是无冲突）
  bool validate() {
    if (_board == null) return false;
    if (!_board!.isValid()) return false;

    final solutionBoard = SudokuBoard(
      board: _board!.initial.map((row) => List<int>.from(row)).toList(),
      initial: _board!.initial.map((row) => List<int>.from(row)).toList(),
    );
    if (!SudokuSolver.solve(solutionBoard)) return false;

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        final v = _board!.get(i, j);
        if (v != 0 && v != solutionBoard.get(i, j)) {
          return false;
        }
      }
    }
    return true;
  }

  /// 当前所有冲突格子（用于高亮）
  Set<int> getConflictCells() {
    final conflicts = <int>{};
    if (_board == null) return conflicts;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (hasConflict(i, j)) {
          conflicts.add(i * 9 + j);
        }
      }
    }
    return conflicts;
  }

  bool hasConflict(int row, int col) {
    if (_board == null) return false;

    int value = _board!.get(row, col);
    if (value == 0) return false;

    _board!.board[row][col] = 0;
    bool canPlace = _board!.canPlace(row, col, value);
    _board!.board[row][col] = value;

    return !canPlace;
  }

  static bool _hintUsesCandidates(SudokuHint hint) =>
      hint.isElimination || hint.patternCandidates.isNotEmpty;

  static bool _markupUsesCandidates(MarkupMode mode) =>
      mode == MarkupMode.candidateColor ||
      mode == MarkupMode.strong ||
      mode == MarkupMode.weak ||
      mode == MarkupMode.autoStrong;

  void toggleShowCandidates() {
    _showCandidates = !_showCandidates;
    notifyListeners();
  }

  void toggleCandidateMode() {
    _candidateMode = !_candidateMode;
    if (_candidateMode) _showCandidates = true;
    notifyListeners();
  }

  Future<void> _persistQueue = Future<void>.value();

  Future<void> persistForTest() => _persistCurrent();

  Future<void> _persistCurrent() {
    _persistQueue =
        _persistQueue.then((_) => _writeCurrent()).catchError((_) {});
    return _persistQueue;
  }

  Future<void> _writeCurrent() async {
    if (_board == null || !hasResumableGame) {
      if (_justCompleted || (_board?.isComplete() ?? false)) {
        await CurrentGameStore.clear();
      }
      return;
    }
    try {
      await CurrentGameStore.write(CurrentGameStore.snapshot(
        id: _puzzleId ?? 'custom',
        difficulty: _difficulty,
        board: _board!,
        elapsedSeconds: _elapsedSeconds,
        hintsUsed: _hintsUsed,
        showCandidates: _showCandidates,
        candidateMode: _candidateMode,
      ));
    } catch (_) {}
  }

  void autoFillCandidates() {
    if (_board == null) return;
    _board!.fillAllCandidates();
    _showCandidates = true;
    notifyListeners();
    _persistCurrent();
  }

  void clearAllCandidates() {
    if (_board == null) return;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        _board!.clearUserCandidates(i, j);
      }
    }
    notifyListeners();
    _persistCurrent();
  }
}

class CandidateElimUndo {
  final int row;
  final int col;
  final int num;
  final bool hadUserCandidate;

  const CandidateElimUndo({
    required this.row,
    required this.col,
    required this.num,
    required this.hadUserCandidate,
  });
}

/// 游戏移动记录
class GameMove {
  final int row;
  final int col;
  final int oldValue;
  final int newValue;
  final bool isCandidate;
  final int? candidateNum;
  final bool? candidateAdded;
  final List<CandidateElimUndo> eliminations;

  GameMove({
    required this.row,
    required this.col,
    required this.oldValue,
    required this.newValue,
  })  : isCandidate = false,
        candidateNum = null,
        candidateAdded = null,
        eliminations = const [];

  GameMove.candidate({
    required this.row,
    required this.col,
    required this.candidateNum,
    required this.candidateAdded,
  })  : oldValue = 0,
        newValue = 0,
        isCandidate = true,
        eliminations = const [];

  GameMove.eliminations(this.eliminations)
      : row = 0,
        col = 0,
        oldValue = 0,
        newValue = 0,
        isCandidate = false,
        candidateNum = null,
        candidateAdded = null;
}
