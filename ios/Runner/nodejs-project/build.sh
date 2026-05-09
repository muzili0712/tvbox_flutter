#!/bin/bash

# TVBox Node.js Mobile 构建脚本
# 此脚本用于构建Node.js代码并集成到iOS Bundle

set -e

echo "🚀 TVBox Node.js Mobile 构建脚本"
echo "================================"

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"

# 进入nodejs-project目录
cd "$(dirname "$0")"

# 检查是否存在node_modules
if [ ! -d "node_modules" ]; then
    echo "📦 安装npm依赖..."
    npm install
else
    echo "✅ npm依赖已安装"
fi

# 检查esbuild
if [ ! -d "node_modules/esbuild" ]; then
    echo "📦 安装esbuild..."
    npm install esbuild
fi

# 检查less
if [ ! -d "node_modules/less" ]; then
    echo "📦 安装less..."
    npm install less
fi

# 创建dist目录
mkdir -p dist

echo "🔨 开始构建..."

# 运行构建脚本
node build.js

echo ""
echo "================================"
echo "✅ 构建完成！"
echo ""
echo "构建产物位于: dist/"
echo "- index.js - 主程序（含website bundle）"
echo "- index.config.js - 配置文件"
echo ""
echo "下一步："
echo "1. 将dist目录下的文件复制到iOS Bundle"
echo "2. 修改Runner项目的Build Phases"
echo "3. 重新编译iOS应用"
echo ""
