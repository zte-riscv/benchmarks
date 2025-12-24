#!/bin/bash

# 脚本用于生成benchmark测试文件
# 用法: ./build_benchmarks.sh [arch]
# 如果参数包含"arm"则生成arm64架构，否则生成riscv64架构

set -e  # 遇到错误立即退出

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 检查参数，判断架构
ARCH_PARAM="${1:-}"
if [[ "$ARCH_PARAM" == *"arm"* ]]; then
    echo "检测到arm参数，生成arm64架构文件"
    export GOOS=linux
    export GOARCH=arm64
    export CGO_ENABLED=0
    ARCH_SUFFIX="arm64"
else
    echo "生成riscv64架构文件（rva23u64）"
    export GOOS=linux
    export GOARCH=riscv64
    export GORISCV64=rva23u64
    export CGO_ENABLED=0
    ARCH_SUFFIX="riscv64"
fi

echo "环境变量设置:"
echo "  GOOS=$GOOS"
echo "  GOARCH=$GOARCH"
if [ -n "$GORISCV64" ]; then
    echo "  GORISCV64=$GORISCV64"
fi
echo "  CGO_ENABLED=$CGO_ENABLED"
echo ""

# 创建输出目录
GO_BENCHMARKS_DIR="$SCRIPT_DIR/go_benchmarks"
mkdir -p "$GO_BENCHMARKS_DIR"

echo "=== 第一部分: 编译benchmark本身的二进制文件 ==="
echo "输出目录: $GO_BENCHMARKS_DIR"
echo ""

# 编译garbage
echo "编译 garbage..."
cd "$PROJECT_ROOT/garbage"
go build -o "$GO_BENCHMARKS_DIR/garbage-$ARCH_SUFFIX" .
if [ $? -eq 0 ]; then
    echo "✓ garbage 编译成功"
else
    echo "✗ garbage 编译失败"
    exit 1
fi

# 编译gc_latency
echo "编译 gc_latency..."
cd "$PROJECT_ROOT/gc_latency"
go build -o "$GO_BENCHMARKS_DIR/gc_latency-$ARCH_SUFFIX" .
if [ $? -eq 0 ]; then
    echo "✓ gc_latency 编译成功"
else
    echo "✗ gc_latency 编译失败"
    exit 1
fi

# 编译json
echo "编译 json..."
cd "$PROJECT_ROOT/json"
go build -o "$GO_BENCHMARKS_DIR/json-$ARCH_SUFFIX" .
if [ $? -eq 0 ]; then
    echo "✓ json 编译成功"
else
    echo "✗ json 编译失败"
    exit 1
fi

echo ""
echo "=== 第二部分: 生成bent测试文件 ==="

# 创建bent工作目录
BENT_DIR="$SCRIPT_DIR/bent"
mkdir -p "$BENT_DIR"

# 进入bent目录
cd "$BENT_DIR"

# 运行bent -I初始化（会在当前目录创建Dockerfile和配置文件）
# 使用-f参数强制初始化，兼容二次初始化的情况
echo "运行 bent -I -f 初始化..."
bent -I -f
if [ $? -ne 0 ]; then
    echo "✗ bent -I 初始化失败"
    exit 1
fi
echo "✓ bent -I 初始化成功"

# 复制configurations.toml到bent目录（覆盖bent -I创建的默认文件）
echo "复制 configurations.toml 到bent目录..."
cp "$SCRIPT_DIR/configurations.toml" configurations.toml

# 运行bent命令生成测试文件
echo "运行 bent -v -N 1 -B benchmarks-50.toml -C configurations.toml..."
bent -v -N 1 -B benchmarks-50.toml -C configurations.toml -b wazero
if [ $? -ne 0 ]; then
    echo "✗ bent 运行失败"
    exit 1
fi
echo "✓ bent 运行成功"

echo ""
echo "=== 完成 ==="
echo "生成的二进制文件位置:"
echo "  1. Benchmark二进制文件: $GO_BENCHMARKS_DIR/"
echo "     - garbage-$ARCH_SUFFIX"
echo "     - gc_latency-$ARCH_SUFFIX"
echo "     - json-$ARCH_SUFFIX"
echo ""
echo "  2. Bent测试二进制文件: $BENT_DIR/testbin/"
echo ""

