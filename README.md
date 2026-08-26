# 我的数独

Flutter 数独教学应用：对局里按从易到难给一步提示，技巧说明是独立静态页。禁止把无说明的回溯填数当成提示。

在线演示：<https://yedeying.github.io/sudoku-dart/>

## 能做什么

- **对局：** 简单 / 中等 / 困难 / 专家题库，或手动输入；计时计分；撤销重做。
- **候选：** 自动候选与手写笔记并存（并集显示）；笔记划掉不影响引擎。
- **提示：** 先说明再应用；棋盘标出参与格和链；浅层找不到时询问是否深搜。
- **标记：** 格色、候选色、强弱链、自动共轭；与提示共用同一套标记。
- **技巧说明：** 目录与引擎报法对齐，每项固定例盘和 Hodoku 记号文案。
- **主题：** 亮暗跟随系统，强调色可改。

技巧名、难度和实现缺口见 [docs/techniques.md](docs/techniques.md)。产品约定见 [docs/](docs/README.md)。

## 运行

需要 [Flutter](https://docs.flutter.dev/get-started/install) 稳定版。

```bash
flutter pub get
flutter run                 # 本机已连接的设备 / 模拟器
flutter run -d chrome       # Web
```

Release 包（装上即可离线用，不挂调试会话）：

```bash
flutter build apk --release
flutter build ios --release   # 需 Xcode 与签名
flutter install --release
```

iOS 真机要在 Xcode 里设好 Team 和 Bundle ID。Web 发布路径是 `/sudoku-dart/`，与 GitHub Pages 一致。

## 检查

```bash
flutter analyze    # 有 issue（含 info）即失败
flutter test
```

推送 `main` 会跑上述检查，再构建 Web 并部署到 GitHub Pages。

## 代码结构

```
lib/
  models/      棋盘、对局状态、技巧目录与例题、标记、记号
  services/    求解与 finder、难度、生成器、题库
  screens/     底栏、选题、对局、输入、技巧列表 / 详情
  widgets/     棋盘、箭头、提示抽屉
  theme/       主题与强调色
assets/puzzles/    分级题库（Sudoku Exchange，公有领域）
docs/              技巧总表与架构说明
```

提示顺序由 `SudokuSolver.hintSearchOrder` 决定，必须与 `DifficultyAnalyzer.techniqueScores` 同向。

## License

MIT
