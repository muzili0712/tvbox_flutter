#!/bin/bash
# 一键构建脚本 - macOS/Linux
# 使用方法: ./quick-build.sh

set -e

echo "🚀 TVBox Flutter 一键构建脚本"
echo "========================================"

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODEJS_DIR="$SCRIPT_DIR/ios/Runner/nodejs-project"

cd "$NODEJS_DIR"

echo "📂 工作目录: $NODEJS_DIR"

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 错误: Node.js 未安装"
    echo "请从 https://nodejs.org 下载安装 Node.js 18+"
    exit 1
fi

echo "✅ Node.js $(node --version)"
echo "✅ npm $(npm --version)"

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo ""
    echo "📦 首次运行，正在安装依赖..."
    echo "(这可能需要几分钟)"
    echo ""
    npm install --legacy-peer-deps
fi

# 清理旧构建
if [ -d "dist" ]; then
    echo "🧹 清理旧构建文件..."
    rm -rf dist
fi

# 创建输出目录
mkdir -p dist

# 开始构建
echo ""
echo "🔨 开始构建..."
echo ""

node build-optimized.js

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✅ 构建成功！"
    echo ""
    echo "📦 构建产物: $NODEJS_DIR/dist/"
    echo ""
    echo "构建产物清单:"
    ls -lh dist/ 2>/dev/null || echo "   (无额外文件)"
    echo ""
    echo "========================================"
    echo ""
    echo "🎉 接下来:"
    echo "1. 打开 Xcode: open ios/Runner.xcworkspace"
    echo "2. 选择你的设备"
    echo "3. 点击运行 (Cmd+R)"
    echo ""
    echo "或在Flutter中运行: flutter run"
    echo ""
else
    echo ""
    echo "========================================"
    echo "❌ 构建失败！"
    echo ""
    echo "请检查:"
    echo "- Node.js依赖是否完整"
    echo "- 源代码是否有语法错误"
    echo "- 查看上方错误信息"
    echo ""
    exit 1
fi
