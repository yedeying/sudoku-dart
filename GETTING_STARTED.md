# 新手入门指南

欢迎！这是一份专为 Android/iOS 开发零经验新手准备的完整指南。

## 📦 第一步：安装 Flutter

### macOS 用户（推荐使用 Homebrew）

1. **安装 Homebrew**（如果还没有）
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **安装 Flutter**
   ```bash
   brew install --cask flutter
   ```

3. **验证安装**
   ```bash
   flutter doctor
   ```

### 安装开发工具

你需要一个代码编辑器。推荐：

#### 方案 A：Visual Studio Code（轻量级，推荐新手）
```bash
brew install --cask visual-studio-code
```

然后在 VS Code 中安装 Flutter 扩展：
1. 打开 VS Code
2. 点击左侧扩展图标
3. 搜索 "Flutter"
4. 安装 Flutter 和 Dart 扩展

#### 方案 B：Android Studio（功能全面）
```bash
brew install --cask android-studio
```

## 🚀 第二步：运行项目

1. **打开终端，进入项目目录**
   ```bash
   cd /Users/yedeying/Files/web/tencent/hellodart
   ```

2. **获取依赖包**
   ```bash
   flutter pub get
   ```

3. **运行项目**

   有多种运行方式：

   **在 Web 浏览器中运行（最简单）**
   ```bash
   flutter run -d chrome
   ```

   **在模拟器中运行**
   ```bash
   # 先启动 iOS 模拟器
   open -a Simulator
   
   # 然后运行
   flutter run
   ```

   **查看可用设备**
   ```bash
   flutter devices
   ```

## 📱 第三步：在真机上运行

### iOS 设备（需要 Mac）

1. 用数据线连接 iPhone/iPad
2. 在设备上信任你的 Mac
3. 运行：
   ```bash
   flutter run
   ```

### Android 设备

1. 在 Android 设备上开启"开发者模式"和"USB 调试"
2. 用数据线连接设备
3. 运行：
   ```bash
   flutter run
   ```

## 🎮 使用 App

1. **主界面**：选择难度开始游戏
   - 简单：适合新手
   - 中等：需要一些技巧
   - 困难：挑战高手

2. **游戏界面**：
   - 点击格子选中
   - 使用底部数字键盘填入数字
   - 点击"提示"获得解题建议
   - 点击"撤销/重做"修改操作

3. **手动输入**：
   - 点击主界面的"手动输入题目"
   - 输入81个数字（0表示空格）
   - 可以粘贴从其他地方找到的数独题目

## 🛠️ 常用命令

```bash
# 热重载（修改代码后，在运行中的终端按 'r' 键）
r

# 完全重启（按 'R' 键）
R

# 停止运行（按 'q' 键）
q

# 格式化代码
flutter format .

# 分析代码
flutter analyze

# 清理构建缓存
flutter clean

# 升级 Flutter
flutter upgrade
```

## 📝 项目结构说明

```
lib/
├── main.dart                 # 应用入口（从这里开始）
├── models/                   # 数据模型
│   ├── sudoku_board.dart    # 数独棋盘逻辑
│   └── game_state.dart      # 游戏状态管理
├── services/                 # 业务逻辑
│   ├── sudoku_generator.dart # 生成数独题目
│   └── sudoku_solver.dart    # 求解和提示算法
├── screens/                  # 页面
│   ├── home_screen.dart      # 首页
│   ├── game_screen.dart      # 游戏页面
│   └── input_screen.dart     # 输入页面
└── widgets/                  # UI 组件
    └── sudoku_grid.dart      # 数独网格组件
```

## 🎯 学习路径

作为新手，建议按以下顺序学习：

1. **先运行起来**（第二步）
2. **玩一玩 App**，熟悉功能
3. **修改 UI 颜色**：
   - 打开 `lib/main.dart`
   - 修改 `primarySwatch: Colors.blue` 为其他颜色
   - 保存文件，在运行中按 `r` 热重载
   
4. **修改文本**：
   - 打开 `lib/screens/home_screen.dart`
   - 修改 `'数独游戏'` 为你喜欢的标题
   - 保存并热重载

5. **理解代码结构**：
   - 阅读 `lib/models/sudoku_board.dart` 了解数据结构
   - 阅读 `lib/services/sudoku_solver.dart` 了解算法

6. **添加新功能**：
   - 参考现有代码
   - 在 Discord/Slack 社区提问

## ❓ 常见问题

### 1. Flutter doctor 报错

运行 `flutter doctor` 后，根据提示逐一解决：
- ✗ Android toolchain：需要安装 Android Studio
- ✗ Xcode：需要安装 Xcode（仅 iOS 开发需要）

### 2. 依赖安装失败

```bash
flutter clean
flutter pub get
```

### 3. 模拟器启动失败

**iOS 模拟器：**
```bash
# 确保 Xcode 已安装
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**Android 模拟器：**
- 打开 Android Studio
- Tools > AVD Manager
- 创建一个新的虚拟设备

### 4. 代码修改后没有生效

按 `R`（大写）完全重启应用，而不是 `r`（小写）热重载。

### 5. 运行时报错

```bash
# 清理并重新构建
flutter clean
flutter pub get
flutter run
```

## 📚 学习资源

### 官方文档
- [Flutter 中文网](https://flutter.cn)
- [Dart 语言教程](https://dart.cn/guides)

### 视频教程
- [Flutter 实战视频](https://www.bilibili.com/video/BV1S4411E7LY)
- [Dart 语言基础](https://www.bilibili.com/video/BV1qE411c7Yf)

### 社区
- [Flutter 中文社区](https://flutter.cn/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

## 💡 下一步

完成基础学习后，你可以：

1. **添加更多功能**：
   - 保存游戏进度
   - 添加音效
   - 实现排行榜
   - 添加主题切换

2. **发布应用**：
   ```bash
   # 构建 Android APK
   flutter build apk
   
   # 构建 iOS App
   flutter build ios
   ```

3. **学习其他 Flutter 项目**：
   - [Flutter Gallery](https://gallery.flutter.dev/)
   - [Flutter Samples](https://flutter.github.io/samples/)

## 🆘 需要帮助？

如果遇到问题：
1. 查看错误信息
2. 运行 `flutter doctor` 检查环境
3. 搜索错误信息（通常别人也遇到过）
4. 在社区提问

祝你学习愉快！🎉
