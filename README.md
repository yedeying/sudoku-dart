# 数独 Sudoku App

一个功能完整的数独游戏应用，支持 Android、iOS 和 Web 平台。

## 功能特性

- ✅ 自动生成不同难度的数独题目（简单、中等、困难、专家）
- ✅ 手动输入自定义题目
- ✅ 智能提示（填数 + 候选删除）
- ✅ 解题过程演示
- ✅ 高阶技巧提示（X-Wing、XY-Wing、W-Wing、着色等）
- ✅ 计时和计分系统
- ✅ 撤销/重做功能（含笔记模式）
- ✅ 冲突高亮与相对唯一解验证

## 安装 Flutter 环境

### macOS
```bash
# 使用 Homebrew 安装
brew install --cask flutter

# 运行诊断
flutter doctor

# 安装依赖
flutter pub get
```

### 验证安装
```bash
flutter doctor -v
```

## 运行项目

```bash
# 获取依赖
flutter pub get

# 运行在模拟器/设备上
flutter run

# 运行在 Web 浏览器
flutter run -d chrome

# 构建 APK（Android）
flutter build apk

# 构建 iOS
flutter build ios
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/
│   ├── sudoku_board.dart    # 数独棋盘数据模型
│   └── game_state.dart      # 游戏状态管理
├── services/
│   ├── sudoku_generator.dart      # 题目生成器入口
│   ├── sudoku_generator_v2.dart   # 基于技巧的生成
│   ├── sudoku_solver.dart         # 求解器和技巧分析
│   ├── advanced_techniques.dart   # 高级技巧
│   └── difficulty_analyzer.dart   # 难度评估
├── screens/
│   ├── home_screen.dart      # 主界面
│   ├── game_screen.dart      # 游戏界面
│   └── input_screen.dart     # 手动输入界面
└── widgets/
    └── sudoku_grid.dart      # 数独网格组件
```

## 开发指南

作为 Android/iOS 开发新手，建议按以下步骤学习：

1. **先运行项目看效果** - `flutter run`
2. **修改 UI 样式** - 从 `widgets/` 目录开始
3. **理解游戏逻辑** - 查看 `models/` 和 `services/`
4. **添加新功能** - 参考现有代码结构

## 常用命令

```bash
# 热重载（开发时修改代码即时生效）
# 在运行时按 'r' 键

# 格式化代码
flutter format .

# 分析代码
flutter analyze

# 清理构建缓存
flutter clean
```

## 学习资源

- [Flutter 中文文档](https://flutter.cn/docs)
- [Dart 语言教程](https://dart.cn/guides)
- [Flutter 实战](https://book.flutterchina.club/)

## 故障排除

如果遇到问题：
1. 运行 `flutter doctor` 检查环境
2. 运行 `flutter clean` 清理缓存
3. 删除 `pubspec.lock` 后重新 `flutter pub get`

## License

MIT
