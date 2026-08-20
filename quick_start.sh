#!/bin/bash

# 数独 App 快速启动脚本
# 这个脚本会自动检查环境并运行项目

echo "🎮 数独 App 启动脚本"
echo "===================="
echo ""

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装"
    echo ""
    echo "请先安装 Flutter："
    echo "  brew install --cask flutter"
    echo ""
    echo "或参考 GETTING_STARTED.md 查看详细安装步骤"
    exit 1
fi

echo "✅ Flutter 已安装"
flutter --version
echo ""

# 检查依赖
echo "📦 检查并安装依赖..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ 依赖安装失败"
    exit 1
fi

echo "✅ 依赖安装成功"
echo ""

# 显示可用设备
echo "📱 可用设备："
flutter devices
echo ""

# 询问运行方式
echo "请选择运行方式："
echo "  1) Web 浏览器 (推荐新手)"
echo "  2) iOS 模拟器"
echo "  3) Android 模拟器/真机"
echo "  4) 自动选择"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo "🌐 在 Chrome 浏览器中启动..."
        flutter run -d chrome
        ;;
    2)
        echo "📱 在 iOS 模拟器中启动..."
        open -a Simulator
        sleep 3
        flutter run
        ;;
    3)
        echo "🤖 在 Android 设备中启动..."
        flutter run
        ;;
    4)
        echo "🚀 自动选择设备启动..."
        flutter run
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac
