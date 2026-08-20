/// 数独棋盘数据模型
class SudokuBoard {
  // 9x9 的棋盘，0 表示空格
  List<List<int>> board;
  // 原始题目（用于区分用户输入和原题）
  List<List<int>> initial;
  // 记录每个格子的候选数字（自动计算）
  List<List<Set<int>>> candidates;
  // 用户手动设置的候选数字（用于笔记功能）
  List<List<Set<int>>> userCandidates;
  // 逻辑推理过程中被排除的候选数字（技巧删除的候选）
  List<List<Set<int>>> eliminated;

  SudokuBoard({
    required this.board,
    required this.initial,
  })  : candidates = List.generate(9, (_) => List.generate(9, (_) => <int>{})),
        userCandidates =
            List.generate(9, (_) => List.generate(9, (_) => <int>{})),
        eliminated = List.generate(9, (_) => List.generate(9, (_) => <int>{})) {
    _updateCandidates();
  }

  /// 从字符串创建棋盘（用于测试和导入）
  /// 例如: "530070000600195000098000060..."
  factory SudokuBoard.fromString(String str) {
    if (str.length != 81) {
      throw ArgumentError('棋盘字符串必须是81个字符');
    }

    List<List<int>> board = [];
    for (int i = 0; i < 9; i++) {
      List<int> row = [];
      for (int j = 0; j < 9; j++) {
        int val = int.parse(str[i * 9 + j]);
        row.add(val);
      }
      board.add(row);
    }

    return SudokuBoard(
      board: board,
      initial: board.map((row) => List<int>.from(row)).toList(),
    );
  }

  /// 创建空白棋盘
  factory SudokuBoard.empty() {
    return SudokuBoard(
      board: List.generate(9, (_) => List.filled(9, 0)),
      initial: List.generate(9, (_) => List.filled(9, 0)),
    );
  }

  /// 深拷贝
  SudokuBoard copy() {
    var newBoard = SudokuBoard(
      board: board.map((row) => List<int>.from(row)).toList(),
      initial: initial.map((row) => List<int>.from(row)).toList(),
    );
    // 复制用户候选数和逻辑排除的候选数
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        newBoard.userCandidates[i][j] = Set<int>.from(userCandidates[i][j]);
        newBoard.eliminated[i][j] = Set<int>.from(eliminated[i][j]);
      }
    }
    // 重新计算候选数，使其考虑已复制的逻辑排除
    newBoard.refreshCandidates();
    return newBoard;
  }

  /// 获取指定位置的值
  int get(int row, int col) => board[row][col];

  /// 设置指定位置的值
  void set(int row, int col, int value) {
    if (initial[row][col] == 0) {
      board[row][col] = value;
      // 填入数字后清除该格的逻辑排除记录
      eliminated[row][col].clear();
      _updateCandidates();
    }
  }

  /// 逻辑排除某个格子的一个候选数字
  /// 返回 true 表示该格的候选数字确实发生了改变
  bool eliminateCandidate(int row, int col, int num) {
    if (board[row][col] != 0) return false;
    bool changed = candidates[row][col].contains(num);
    eliminated[row][col].add(num);
    if (changed) {
      candidates[row][col].remove(num);
    }
    return changed;
  }

  /// 批量逻辑排除候选数字
  /// 每个元素为 [row, col, num]；返回是否有任何候选数字被改变
  bool eliminateCandidates(Iterable<List<int>> elims) {
    bool changed = false;
    for (final e in elims) {
      if (eliminateCandidate(e[0], e[1], e[2])) changed = true;
    }
    return changed;
  }

  /// 重新计算所有候选数字（会考虑逻辑排除的候选）
  void refreshCandidates() {
    _updateCandidates();
  }

  /// 清除指定位置
  void clear(int row, int col) {
    if (initial[row][col] == 0) {
      board[row][col] = 0;
      _updateCandidates();
    }
  }

  /// 检查是否是初始题目中的数字
  bool isInitial(int row, int col) => initial[row][col] != 0;

  /// 检查棋盘是否完成
  bool isComplete() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] == 0) return false;
      }
    }
    return isValid();
  }

  /// 验证当前棋盘是否合法
  bool isValid() {
    // 检查每一行
    for (int i = 0; i < 9; i++) {
      if (!_isRowValid(i)) return false;
    }

    // 检查每一列
    for (int j = 0; j < 9; j++) {
      if (!_isColumnValid(j)) return false;
    }

    // 检查每个 3x3 宫格
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        if (!_isBoxValid(boxRow, boxCol)) return false;
      }
    }

    return true;
  }

  /// 检查在指定位置放置数字是否合法
  bool canPlace(int row, int col, int num) {
    if (num < 1 || num > 9) return false;

    // 检查行
    for (int j = 0; j < 9; j++) {
      if (j != col && board[row][j] == num) return false;
    }

    // 检查列
    for (int i = 0; i < 9; i++) {
      if (i != row && board[i][col] == num) return false;
    }

    // 检查 3x3 宫格
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (i != row && j != col && board[i][j] == num) {
          return false;
        }
      }
    }

    return true;
  }

  /// 获取指定位置的候选数字
  Set<int> getCandidates(int row, int col) {
    if (board[row][col] != 0) return {};
    return candidates[row][col];
  }

  /// 获取用户设置的候选数字
  Set<int> getUserCandidates(int row, int col) {
    if (board[row][col] != 0) return {};
    return userCandidates[row][col];
  }

  /// 可见候选：自动候选 ∪ 用户笔记（已填格为空）
  Set<int> visibleCandidates(int row, int col) {
    if (board[row][col] != 0) return {};
    return {...candidates[row][col], ...userCandidates[row][col]};
  }

  /// 设置用户候选数字
  void setUserCandidates(int row, int col, Set<int> newCandidates) {
    if (board[row][col] == 0) {
      userCandidates[row][col] = Set<int>.from(newCandidates);
    }
  }

  /// 切换某个候选数字
  void toggleUserCandidate(int row, int col, int num) {
    if (board[row][col] == 0) {
      if (userCandidates[row][col].contains(num)) {
        userCandidates[row][col].remove(num);
      } else {
        userCandidates[row][col].add(num);
      }
    }
  }

  /// 清除用户候选数字
  void clearUserCandidates(int row, int col) {
    userCandidates[row][col].clear();
  }

  /// 自动填充所有空格的候选数字
  void fillAllCandidates() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] == 0) {
          userCandidates[i][j] = Set<int>.from(candidates[i][j]);
        }
      }
    }
  }

  /// 更新所有候选数字
  void _updateCandidates() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] == 0) {
          candidates[i][j] = _calculateCandidates(i, j);
        } else {
          candidates[i][j] = {};
        }
      }
    }
  }

  /// 计算指定位置的候选数字
  Set<int> _calculateCandidates(int row, int col) {
    Set<int> possible = {1, 2, 3, 4, 5, 6, 7, 8, 9};

    // 排除同行的数字
    for (int j = 0; j < 9; j++) {
      possible.remove(board[row][j]);
    }

    // 排除同列的数字
    for (int i = 0; i < 9; i++) {
      possible.remove(board[i][col]);
    }

    // 排除同宫格的数字
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        possible.remove(board[i][j]);
      }
    }

    // 移除逻辑推理过程中被排除的候选数字
    possible.removeAll(eliminated[row][col]);

    return possible;
  }

  bool _isRowValid(int row) {
    Set<int> seen = {};
    for (int j = 0; j < 9; j++) {
      int val = board[row][j];
      if (val != 0) {
        if (seen.contains(val)) return false;
        seen.add(val);
      }
    }
    return true;
  }

  bool _isColumnValid(int col) {
    Set<int> seen = {};
    for (int i = 0; i < 9; i++) {
      int val = board[i][col];
      if (val != 0) {
        if (seen.contains(val)) return false;
        seen.add(val);
      }
    }
    return true;
  }

  bool _isBoxValid(int boxRow, int boxCol) {
    Set<int> seen = {};
    int startRow = boxRow * 3;
    int startCol = boxCol * 3;
    for (int i = startRow; i < startRow + 3; i++) {
      for (int j = startCol; j < startCol + 3; j++) {
        int val = board[i][j];
        if (val != 0) {
          if (seen.contains(val)) return false;
          seen.add(val);
        }
      }
    }
    return true;
  }

  /// 转换为字符串（用于保存和调试）
  String toStringRepresentation() {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        sb.write(board[i][j]);
      }
    }
    return sb.toString();
  }

  /// 美化输出（用于调试）
  String toPrettyString() {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < 9; i++) {
      if (i % 3 == 0 && i != 0) {
        sb.writeln('------+-------+------');
      }
      for (int j = 0; j < 9; j++) {
        if (j % 3 == 0 && j != 0) {
          sb.write('| ');
        }
        sb.write(board[i][j] == 0 ? '. ' : '${board[i][j]} ');
      }
      sb.writeln();
    }
    return sb.toString();
  }
}
