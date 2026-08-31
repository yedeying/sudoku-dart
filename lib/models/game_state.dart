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

  /// 快捷键撤销/重做。`redo: true` 为重做。
  bool handleUndoShortcut({required bool redo}) {
    if (redo) {
      if (!canRedo) return false;
      this.redo();
      return true;
    }
    if (!canUndo) return false;
    undo();
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
    _commitMarkup(() {
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
              userMarkup.candidateColors[CandidateRef(r, c, digit)] =
                  markupColor;
            }
          }
        }
      }
    });
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
      _commitMarkup(() {
        final key = BoardMarkup.cellKey(row, col);
        if (userMarkup.cellColors[key] == markupColor) {
          userMarkup.cellColors.remove(key);
        } else {
          userMarkup.cellColors[key] = markupColor;
        }
      });
      return;
    }
    notifyListeners();
  }

  void paintSelectedCell() {
    if (_selectedRow == null || _selectedCol == null) return;
    _commitMarkup(() {
      userMarkup.cellColors[BoardMarkup.cellKey(_selectedRow!, _selectedCol!)] =
          markupColor;
    });
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
    _commitMarkup(() {
      final ref = CandidateRef(r, c, number);
      if (userMarkup.candidateColors[ref] == markupColor) {
        userMarkup.candidateColors.remove(ref);
      } else {
        userMarkup.candidateColors[ref] = markupColor;
      }
    });
  }

  /// 点棋盘上的小数字：候选色模式直接上色，强/弱链模式设锚点或连线。
  void onCandidateTap(int row, int col, int num) {
    if (_board == null) return;
    if (!_board!.visibleCandidates(row, col).contains(num)) return;
    switch (markupMode) {
      case MarkupMode.candidateColor:
        _commitMarkup(() {
          final ref = CandidateRef(row, col, num);
          if (userMarkup.candidateColors[ref] == markupColor) {
            userMarkup.candidateColors.remove(ref);
          } else {
            userMarkup.candidateColors[ref] = markupColor;
          }
        });
        return;
      case MarkupMode.strong:
      case MarkupMode.weak:
        onCandidateMarkupTap(row, col, num);
        return;
      case MarkupMode.autoStrong:
        expandAutoAic(row, col, num);
        return;
      case MarkupMode.off:
      case MarkupMode.cellColor:
        return;
    }
  }

  /// 仅强/弱链：点候选设锚点或画箭头。其它模式勿调用（由 UI 不接线）。
  void onCandidateMarkupTap(int row, int col, int num) {
    final kind = pendingArrowKind;
    if (kind == null) return;

    final ref = CandidateRef(row, col, num);
    _commitMarkup(() {
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
    });
  }

  void clearAutoStrongNotice() {
    if (autoStrongNotice == null) return;
    autoStrongNotice = null;
    notifyListeners();
  }

  void setFilterDigit(int? d) {
    _commitMarkup(() {
      final next = userMarkup.copy();
      userMarkup = BoardMarkup(
        cellColors: next.cellColors,
        candidateColors: next.candidateColors,
        arrows: next.arrows,
        struck: next.struck,
        filterDigit: d,
      );
    });
  }

  void toggleStrikeOnSelected(int num) {
    if (_selectedRow == null || _selectedCol == null) return;
    final ref = CandidateRef(_selectedRow!, _selectedCol!, num);
    _commitMarkup(() {
      if (userMarkup.struck.contains(ref)) {
        userMarkup.struck.remove(ref);
      } else {
        userMarkup.struck.add(ref);
      }
    });
  }

  /// 自动强弱链下点某个候选：只画以它为强链端点、另一端同数字的 AIC。
  void expandAutoAic(int row, int col, int num) {
    if (_board == null) return;
    if (!_board!.visibleCandidates(row, col).contains(num)) return;
    autoStrongNotice = null;
    final start = CandidateRef(row, col, num);
    _commitMarkup(() {
      final focused = _aicSameDigitPaths(start, _aicLinks());
      final digits = {start.num};
      for (final e in focused.edges) {
        digits.add(e.a.num);
        digits.add(e.b.num);
      }
      userMarkup.arrows.removeWhere(
        (a) => digits.contains(a.from.num) || digits.contains(a.to.num),
      );
      userMarkup.candidateColors
          .removeWhere((ref, _) => digits.contains(ref.num));
      if (focused.edges.isEmpty) {
        autoStrongNotice = '该候选展不开 AIC';
        return;
      }
      final endColor = MarkupPalette.contrast(markupColor);
      final elimColor = markupColor == MarkupPalette.red
          ? MarkupPalette.blue
          : MarkupPalette.red;
      Color nodeColor(CandidateRef ref) =>
          focused.ends.contains(ref) ? endColor : markupColor;
      final onPath = <CandidateRef>{};
      for (final e in focused.edges) {
        onPath.add(e.a);
        onPath.add(e.b);
        if (e.a.row == e.b.row && e.a.col == e.b.col) {
          userMarkup.candidateColors[e.a] = nodeColor(e.a);
          userMarkup.candidateColors[e.b] = nodeColor(e.b);
          continue;
        }
        userMarkup.addArrow(
          e.a,
          e.b,
          e.kind,
          _board!.candidates,
          color: e.kind == ArrowKind.strong ? markupColor : null,
          directed: false,
        );
        userMarkup.candidateColors[e.a] = nodeColor(e.a);
        userMarkup.candidateColors[e.b] = nodeColor(e.b);
      }
      for (final end in focused.ends) {
        if (end == start) continue;
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            if (_board!.get(r, c) != 0) continue;
            if (!_board!.visibleCandidates(r, c).contains(start.num)) continue;
            final z = CandidateRef(r, c, start.num);
            if (onPath.contains(z) || z == start || z == end) continue;
            if (_sameDigitCanSee(z, start) && _sameDigitCanSee(z, end)) {
              userMarkup.candidateColors[z] = elimColor;
            }
          }
        }
      }
    });
  }

  /// 扫描行、列、宫：恰两处画强链；两条不同强链的端点互相看得见则补弱链。
  int paintAutoStrong(int digit) {
    if (_board == null) return 0;
    autoStrongNotice = null;
    var added = 0;
    _commitMarkup(() {
      final links = _sameDigitAicLinks(digit);
      bool alreadyLinked(CandidateRef a, CandidateRef b) =>
          userMarkup.arrows.any((arrow) =>
              (arrow.from == a && arrow.to == b) ||
              (arrow.from == b && arrow.to == a));

      for (final e in links) {
        if (e.a.row == e.b.row && e.a.col == e.b.col) continue;
        if (alreadyLinked(e.a, e.b)) continue;
        if (userMarkup.addArrow(
          e.a,
          e.b,
          e.kind,
          _board!.candidates,
          color: e.kind == ArrowKind.strong ? markupColor : null,
          directed: false,
        )) {
          added++;
        }
      }

      if (!links.any((e) => e.kind == ArrowKind.strong)) {
        autoStrongNotice = '该数字没有强链';
      }
    });
    return added;
  }

  bool _sameDigitCanSee(CandidateRef a, CandidateRef b) =>
      a.row == b.row ||
      a.col == b.col ||
      (a.row ~/ 3 == b.row ~/ 3 && a.col ~/ 3 == b.col ~/ 3);

  /// 同格不同数字，或同数字且同行/列/宫。
  bool _aicCanSee(CandidateRef a, CandidateRef b) {
    if (a == b) return false;
    if (a.row == b.row && a.col == b.col) return a.num != b.num;
    return a.num == b.num && _sameDigitCanSee(a, b);
  }

  bool _aicLinked(
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> edges,
    CandidateRef a,
    CandidateRef b,
  ) =>
      edges.any((e) =>
          (e.a == a && e.b == b) || (e.a == b && e.b == a));

  void _addConjugatePair(
    List<(CandidateRef, CandidateRef)> strongs,
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> out,
    List<CandidateRef> hits,
  ) {
    if (hits.length != 2) return;
    final a = hits[0];
    final b = hits[1];
    strongs.add((a, b));
    if (_aicLinked(out, a, b)) return;
    out.add((a: a, b: b, kind: ArrowKind.strong));
  }

  void _addHouseConjugates(
    int digit,
    List<(CandidateRef, CandidateRef)> strongs,
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> out,
  ) {
    for (int r = 0; r < 9; r++) {
      final hits = <CandidateRef>[];
      for (int c = 0; c < 9; c++) {
        if (_board!.get(r, c) == 0 &&
            _board!.getCandidates(r, c).contains(digit)) {
          hits.add(CandidateRef(r, c, digit));
        }
      }
      _addConjugatePair(strongs, out, hits);
    }

    for (int c = 0; c < 9; c++) {
      final hits = <CandidateRef>[];
      for (int r = 0; r < 9; r++) {
        if (_board!.get(r, c) == 0 &&
            _board!.getCandidates(r, c).contains(digit)) {
          hits.add(CandidateRef(r, c, digit));
        }
      }
      _addConjugatePair(strongs, out, hits);
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
        _addConjugatePair(strongs, out, hits);
      }
    }
  }

  void _addAicWeaks(
    List<(CandidateRef, CandidateRef)> strongs,
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> out,
    bool Function(CandidateRef a, CandidateRef b) canSee,
  ) {
    for (var i = 0; i < strongs.length; i++) {
      for (var j = i + 1; j < strongs.length; j++) {
        for (final a in [strongs[i].$1, strongs[i].$2]) {
          for (final b in [strongs[j].$1, strongs[j].$2]) {
            if (a == b || !canSee(a, b) || _aicLinked(out, a, b)) continue;
            out.add((a: a, b: b, kind: ArrowKind.weak));
          }
        }
      }
    }
  }

  void _addBivalueStrongs(
    List<(CandidateRef, CandidateRef)> strongs,
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> out, {
    int? digit,
  }) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board!.get(r, c) != 0) continue;
        final cands = _board!.getCandidates(r, c).toList();
        if (cands.length != 2) continue;
        if (digit != null && !cands.contains(digit)) continue;
        _addConjugatePair(
          strongs,
          out,
          [CandidateRef(r, c, cands[0]), CandidateRef(r, c, cands[1])],
        );
      }
    }
  }

  List<({CandidateRef a, CandidateRef b, ArrowKind kind})> _sameDigitAicLinks(
    int digit,
  ) {
    final strongs = <(CandidateRef, CandidateRef)>[];
    final out = <({CandidateRef a, CandidateRef b, ArrowKind kind})>[];
    _addHouseConjugates(digit, strongs, out);
    _addBivalueStrongs(strongs, out, digit: digit);
    _addAicWeaks(
      strongs,
      out,
      (a, b) => a.num == b.num && _sameDigitCanSee(a, b),
    );
    return out;
  }

  /// 全盘 AIC：房屋共轭 + 双值格为强链；不同强链端点互相看得见则补弱链。
  List<({CandidateRef a, CandidateRef b, ArrowKind kind})> _aicLinks() {
    final strongs = <(CandidateRef, CandidateRef)>[];
    final out = <({CandidateRef a, CandidateRef b, ArrowKind kind})>[];
    for (var digit = 1; digit <= 9; digit++) {
      _addHouseConjugates(digit, strongs, out);
    }
    _addBivalueStrongs(strongs, out);
    _addAicWeaks(strongs, out, _aicCanSee);
    return out;
  }

  /// 从强链端点出发，对每个同数字目标端点各留一条最短交替路径（至少 S-W-S）。
  ({
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> edges,
    Set<CandidateRef> ends,
  }) _aicSameDigitPaths(
    CandidateRef start,
    List<({CandidateRef a, CandidateRef b, ArrowKind kind})> links,
  ) {
    final strongAdj = <CandidateRef, List<CandidateRef>>{};
    final weakAdj = <CandidateRef, List<CandidateRef>>{};
    void addAdj(
      Map<CandidateRef, List<CandidateRef>> adj,
      CandidateRef a,
      CandidateRef b,
    ) {
      (adj[a] ??= []).add(b);
      (adj[b] ??= []).add(a);
    }

    for (final e in links) {
      addAdj(e.kind == ArrowKind.strong ? strongAdj : weakAdj, e.a, e.b);
    }
    if (!strongAdj.containsKey(start)) {
      return (edges: const [], ends: const {});
    }

    const maxLinks = 14;
    final seenState = <(CandidateRef, bool)>{(start, true)};
    final queue = <({
      CandidateRef u,
      bool needStrong,
      List<({CandidateRef a, CandidateRef b, ArrowKind kind})> path,
    })>[
      (u: start, needStrong: true, path: const []),
    ];
    final pathByEnd =
        <CandidateRef, List<({CandidateRef a, CandidateRef b, ArrowKind kind})>>{};
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur.path.length >= maxLinks) continue;
      final nbrs = cur.needStrong
          ? strongAdj[cur.u]
          : <CandidateRef>{...?weakAdj[cur.u], ...?strongAdj[cur.u]};
      if (nbrs == null || nbrs.isEmpty) continue;
      final kind = cur.needStrong ? ArrowKind.strong : ArrowKind.weak;
      for (final v in nbrs) {
        if (cur.path.any((e) => e.a == v || e.b == v) || v == start) {
          continue;
        }
        final next = [...cur.path, (a: cur.u, b: v, kind: kind)];
        final nextNeed = !cur.needStrong;
        if (cur.needStrong && v.num == start.num && cur.path.isNotEmpty) {
          pathByEnd.putIfAbsent(v, () => next);
        }
        if (seenState.add((v, nextNeed))) {
          queue.add((u: v, needStrong: nextNeed, path: next));
        }
      }
    }
    if (pathByEnd.isEmpty) {
      return (edges: const [], ends: const {});
    }
    final used = <({CandidateRef a, CandidateRef b, ArrowKind kind})>[];
    bool samePair(
      ({CandidateRef a, CandidateRef b, ArrowKind kind}) e,
      CandidateRef a,
      CandidateRef b,
    ) =>
        (e.a == a && e.b == b) || (e.a == b && e.b == a);
    for (final path in pathByEnd.values) {
      for (final e in path) {
        final i = used.indexWhere((x) => samePair(x, e.a, e.b));
        if (i < 0) {
          used.add(e);
        } else if (e.kind == ArrowKind.strong && used[i].kind == ArrowKind.weak) {
          used[i] = e;
        }
      }
    }
    return (edges: used, ends: {start, ...pathByEnd.keys});
  }

  void clearUserMarkup() {
    _commitMarkup(() {
      userMarkup = BoardMarkup();
      arrowAnchor = null;
    });
  }

  /// 撤销
  void undo() {
    if (!canUndo || _board == null) return;

    hintMarkup = null;
    hintSession = null;

    var move = _history[_historyIndex];
    if (move.isMarkup) {
      userMarkup = move.markupBefore!.copy();
      arrowAnchor = move.arrowAnchorBefore;
    } else if (move.eliminations.isNotEmpty) {
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
    if (move.isMarkup) {
      userMarkup = move.markupAfter!.copy();
      arrowAnchor = move.arrowAnchorAfter;
    } else if (move.eliminations.isNotEmpty) {
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

  void _commitMarkup(VoidCallback mutate) {
    final before = userMarkup.copy();
    final anchorBefore = arrowAnchor;
    mutate();
    if (_sameMarkup(before, userMarkup) && anchorBefore == arrowAnchor) {
      notifyListeners();
      return;
    }
    _addToHistory(GameMove.markup(
      before: before,
      after: userMarkup.copy(),
      arrowAnchorBefore: anchorBefore,
      arrowAnchorAfter: arrowAnchor,
    ));
    notifyListeners();
  }

  bool _sameMarkup(BoardMarkup a, BoardMarkup b) {
    if (a.filterDigit != b.filterDigit) return false;
    if (a.cellColors.length != b.cellColors.length) return false;
    for (final e in a.cellColors.entries) {
      if (b.cellColors[e.key] != e.value) return false;
    }
    if (a.candidateColors.length != b.candidateColors.length) return false;
    for (final e in a.candidateColors.entries) {
      if (b.candidateColors[e.key] != e.value) return false;
    }
    if (a.arrows.length != b.arrows.length) return false;
    for (var i = 0; i < a.arrows.length; i++) {
      if (a.arrows[i] != b.arrows[i]) return false;
    }
    if (a.struck.length != b.struck.length) return false;
    return a.struck.containsAll(b.struck);
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

  /// 当前所有冲突格子（成数互撞，或候选看见了同宫成数）
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
    conflicts.addAll(_candidateConflicts().cells);
    return conflicts;
  }

  /// 与成数共宫的可见候选，数字要标红。
  Set<CandidateRef> candidateColorConflictRefs() => _candidateConflicts().refs;

  ({Set<int> cells, Set<CandidateRef> refs}) _candidateConflicts() {
    final cells = <int>{};
    final refs = <CandidateRef>{};
    if (_board == null) return (cells: cells, refs: refs);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_board!.get(r, c) != 0) continue;
        for (final digit in _board!.visibleCandidates(r, c)) {
          if (_board!.canPlace(r, c, digit)) continue;
          refs.add(CandidateRef(r, c, digit));
          _addFilledPeers(r, c, digit, cells);
        }
      }
    }
    return (cells: cells, refs: refs);
  }

  void _addFilledPeers(int row, int col, int digit, Set<int> cells) {
    for (int j = 0; j < 9; j++) {
      if (_board!.get(row, j) == digit) cells.add(row * 9 + j);
    }
    for (int i = 0; i < 9; i++) {
      if (_board!.get(i, col) == digit) cells.add(i * 9 + col);
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (_board!.get(i, j) == digit) cells.add(i * 9 + j);
      }
    }
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
  final BoardMarkup? markupBefore;
  final BoardMarkup? markupAfter;
  final CandidateRef? arrowAnchorBefore;
  final CandidateRef? arrowAnchorAfter;

  bool get isMarkup => markupBefore != null;

  GameMove({
    required this.row,
    required this.col,
    required this.oldValue,
    required this.newValue,
  })  : isCandidate = false,
        candidateNum = null,
        candidateAdded = null,
        eliminations = const [],
        markupBefore = null,
        markupAfter = null,
        arrowAnchorBefore = null,
        arrowAnchorAfter = null;

  GameMove.candidate({
    required this.row,
    required this.col,
    required this.candidateNum,
    required this.candidateAdded,
  })  : oldValue = 0,
        newValue = 0,
        isCandidate = true,
        eliminations = const [],
        markupBefore = null,
        markupAfter = null,
        arrowAnchorBefore = null,
        arrowAnchorAfter = null;

  GameMove.eliminations(this.eliminations)
      : row = 0,
        col = 0,
        oldValue = 0,
        newValue = 0,
        isCandidate = false,
        candidateNum = null,
        candidateAdded = null,
        markupBefore = null,
        markupAfter = null,
        arrowAnchorBefore = null,
        arrowAnchorAfter = null;

  GameMove.markup({
    required BoardMarkup before,
    required BoardMarkup after,
    this.arrowAnchorBefore,
    this.arrowAnchorAfter,
  })  : row = 0,
        col = 0,
        oldValue = 0,
        newValue = 0,
        isCandidate = false,
        candidateNum = null,
        candidateAdded = null,
        eliminations = const [],
        markupBefore = before,
        markupAfter = after;
}
