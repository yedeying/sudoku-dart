import 'package:flutter/material.dart';
import 'sudoku_board.dart';
import 'board_markup.dart';
import '../services/sudoku_generator.dart';
import '../services/sudoku_solver.dart';

/// 游戏状态管理
class GameState extends ChangeNotifier {
  SudokuBoard? _board;
  String _difficulty = 'medium';
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
  CandidateRef? arrowAnchor;
  Color markupColor = const Color(0xFF90CAF9);
  String? conjugateNotice;

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
      case MarkupMode.autoConjugate:
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
  int get elapsedSeconds => _elapsedSeconds;
  int get hintsUsed => _hintsUsed;
  bool get isPlaying => _isPlaying;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;
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

  /// 开始新游戏（真实生成）
  void startNewGame(String difficulty) {
    _difficulty = difficulty;
    _board = SudokuGenerator.generate(difficulty);
    _resetSessionState();
    notifyListeners();
  }

  /// 加载示例游戏（用于快速测试）
  void loadExampleGame(String difficulty) {
    _difficulty = difficulty;
    _board = SudokuGenerator.generateExample(difficulty);
    _resetSessionState();
    notifyListeners();
  }

  /// 从字符串加载游戏（手动输入）
  void loadCustomGame(String puzzleString) {
    try {
      _board = SudokuBoard.fromString(puzzleString);
      _difficulty = 'custom';
      _resetSessionState();
      notifyListeners();
    } catch (e) {
      debugPrint('加载自定义游戏失败: $e');
    }
  }

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
    userMarkup = BoardMarkup();
    hintMarkup = null;
    arrowAnchor = null;
    conjugateNotice = null;
    markupMode = MarkupMode.off;
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
      final had = _board!.getUserCandidates(_selectedRow!, _selectedCol!).contains(number);
      _addToHistory(GameMove.candidate(
        row: _selectedRow!,
        col: _selectedCol!,
        candidateNum: number,
        candidateAdded: !had,
      ));
      _board!.toggleUserCandidate(_selectedRow!, _selectedCol!, number);
      notifyListeners();
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
    notifyListeners();
  }

  /// 获取提示（不增加提示计数，仅查看）。高级技巧（回溯填数）对用户视为未找到。
  SudokuHint? getHint({bool deep = false}) {
    if (_board == null) return null;

    var hint = SudokuSolver.getHint(_board!);
    if (hint != null && hint.technique == '高级技巧') {
      hint = null;
    }
    if (hint != null) {
      _selectedRow = hint.row;
      _selectedCol = hint.col;
      hintMarkup = markupFromHint(hint);
      notifyListeners();
    }
    return hint;
  }

  static BoardMarkup markupFromHint(SudokuHint hint) {
    final m = BoardMarkup();
    if (hint.isElimination) {
      for (final e in hint.eliminations) {
        m.cellColors[BoardMarkup.cellKey(e.row, e.col)] =
            const Color(0xFFFFCDD2);
        m.struck.add(CandidateRef(e.row, e.col, e.num));
      }
    } else {
      m.cellColors[BoardMarkup.cellKey(hint.row, hint.col)] =
          const Color(0xFFC8E6C9);
    }
    return m;
  }

  /// 自动应用提示（填数或删除候选），并计一次提示
  void applyHint(SudokuHint hint) {
    _hintsUsed++;
    _selectedRow = hint.row;
    _selectedCol = hint.col;

    if (hint.isElimination) {
      for (final e in hint.eliminations) {
        _board?.eliminateCandidate(e.row, e.col, e.num);
        // 同步用户笔记中对应候选
        _board?.userCandidates[e.row][e.col].remove(e.num);
      }
      _showCandidates = true;
      hintMarkup = null;
      notifyListeners();
      return;
    }

    // 填数：绕过 candidateMode
    final wasCandidateMode = _candidateMode;
    _candidateMode = false;
    placeNumber(hint.value);
    _candidateMode = wasCandidateMode;
    hintMarkup = null;
  }

  void clearHintMarkup() {
    hintMarkup = null;
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
    notifyListeners();
  }

  void setMarkupColor(Color color) {
    markupColor = color;
    notifyListeners();
  }

  /// 标记关闭且选中成数时，同数字成数格弱高亮（不写 markup）
  Set<int> sameDigitHighlightCells() {
    if (markupMode != MarkupMode.off) return {};
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
    if (markupMode != MarkupMode.off) return {};
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

  /// 数字键路由：填数 / 笔记 / 候选色 / 链锚点 / 自动共轭
  void onNumberPad(int number) {
    if (_board == null) return;
    switch (markupMode) {
      case MarkupMode.off:
        placeNumber(number);
        return;
      case MarkupMode.cellColor:
        return;
      case MarkupMode.candidateColor:
        _toggleSelectedCandidateColor(number);
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
      case MarkupMode.autoConjugate:
        paintConjugates(number);
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
      case MarkupMode.strong:
      case MarkupMode.weak:
        if (_selectedRow == null || _selectedCol == null) return false;
        final r = _selectedRow!;
        final c = _selectedCol!;
        if (_board!.get(r, c) != 0) return false;
        return _board!.visibleCandidates(r, c).contains(number);
      case MarkupMode.autoConjugate:
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

  void onCandidateMarkupTap(int row, int col, int num) {
    final ref = CandidateRef(row, col, num);
    final kind = pendingArrowKind;
    if (kind != null) {
      if (arrowAnchor == null) {
        arrowAnchor = ref;
      } else {
        userMarkup.addArrow(
          arrowAnchor!,
          ref,
          kind,
          _board?.candidates ?? [],
        );
        arrowAnchor = null;
      }
      notifyListeners();
      return;
    }
    userMarkup.candidateColors[ref] = markupColor;
    notifyListeners();
  }

  void clearConjugateNotice() {
    if (conjugateNotice == null) return;
    conjugateNotice = null;
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

  /// 扫描行、列、宫；恰两处则画共轭。返回新增条数。
  int paintConjugates(int digit) {
    if (_board == null) return 0;
    conjugateNotice = null;
    var added = 0;

    void addPair(List<CandidateRef> hits) {
      if (hits.length != 2) return;
      final a = hits[0];
      final b = hits[1];
      final duplicate = userMarkup.arrows.any(
        (arrow) =>
            arrow.kind == ArrowKind.conjugate &&
            ((arrow.from == a && arrow.to == b) ||
                (arrow.from == b && arrow.to == a)),
      );
      if (duplicate) return;
      if (userMarkup.addArrow(
          a, b, ArrowKind.conjugate, _board!.candidates)) {
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

    if (added == 0) {
      conjugateNotice = '该数字没有共轭对';
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

    var move = _history[_historyIndex];
    if (move.isCandidate) {
      if (move.candidateAdded == true) {
        _board!.userCandidates[move.row][move.col].remove(move.candidateNum!);
      } else {
        _board!.userCandidates[move.row][move.col].add(move.candidateNum!);
      }
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
  }

  /// 重做
  void redo() {
    if (!canRedo || _board == null) return;

    _historyIndex++;
    var move = _history[_historyIndex];
    if (move.isCandidate) {
      if (move.candidateAdded == true) {
        _board!.userCandidates[move.row][move.col].add(move.candidateNum!);
      } else {
        _board!.userCandidates[move.row][move.col].remove(move.candidateNum!);
      }
    } else {
      _board!.set(move.row, move.col, move.newValue);
    }

    if (_board!.isComplete()) {
      _isPlaying = false;
      _justCompleted = true;
    }
    notifyListeners();
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

    switch (_difficulty) {
      case 'easy':
        score += 100;
        break;
      case 'medium':
        score += 300;
        break;
      case 'hard':
        score += 500;
        break;
      case 'expert':
        score += 800;
        break;
    }

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

  void toggleShowCandidates() {
    _showCandidates = !_showCandidates;
    notifyListeners();
  }

  void toggleCandidateMode() {
    _candidateMode = !_candidateMode;
    notifyListeners();
  }

  void autoFillCandidates() {
    if (_board == null) return;
    _board!.fillAllCandidates();
    _showCandidates = true;
    notifyListeners();
  }

  void clearAllCandidates() {
    if (_board == null) return;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        _board!.clearUserCandidates(i, j);
      }
    }
    notifyListeners();
  }
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

  GameMove({
    required this.row,
    required this.col,
    required this.oldValue,
    required this.newValue,
  })  : isCandidate = false,
        candidateNum = null,
        candidateAdded = null;

  GameMove.candidate({
    required this.row,
    required this.col,
    required this.candidateNum,
    required this.candidateAdded,
  })  : oldValue = 0,
        newValue = 0,
        isCandidate = true;
}
