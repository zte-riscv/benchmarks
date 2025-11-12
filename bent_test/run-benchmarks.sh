#!/bin/bash

# 脚本说明：根据 TOML 配置文件执行已编译的 benchmark 测试文件
# 用法: ./run-benchmarks.sh <TOML文件> <测试次数> <输出文件>
# 示例: ./run-benchmarks.sh benchmarks-50.toml 5 results.txt

set -uo pipefail
# 不使用 -e，以便在循环中继续执行即使某个命令失败

# 检查参数
if [ $# -lt 3 ]; then
    echo "错误: 请提供 TOML 文件路径、测试次数和输出文件路径"
    echo "用法: $0 <TOML文件> <测试次数> <输出文件>"
    echo "示例: $0 benchmarks-50.toml 5 results.txt"
    exit 1
fi

TOML_FILE=$1
COUNT=$2
OUTPUT_FILE=$3

# 检查 TOML 文件是否存在
if [ ! -f "$TOML_FILE" ]; then
    echo "错误: 找不到文件 $TOML_FILE"
    exit 1
fi

# 验证测试次数为正整数
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
    echo "错误: 测试次数必须是正整数"
    exit 1
fi

echo "开始执行 benchmark 测试"
echo "TOML 配置文件: $TOML_FILE"
echo "测试次数: $COUNT"
echo "输出文件: $OUTPUT_FILE"
echo "=========================================="

# 解析 TOML 文件并执行 benchmarks
# 使用 awk 来解析 TOML 格式
awk '
BEGIN {
    in_benchmark = 0
    name = ""
    benchmarks = ""
    disabled = 0
}

/^\[\[Benchmarks\]\]/ {
    # 处理上一个 benchmark（如果有）
    if (in_benchmark && name != "" && !disabled && benchmarks != "") {
        print name "|" benchmarks
    }
    # 重置状态
    in_benchmark = 1
    name = ""
    benchmarks = ""
    disabled = 0
    next
}

/^\[\[/ {
    # 遇到新的节，处理上一个 benchmark
    if (in_benchmark && name != "" && !disabled && benchmarks != "") {
        print name "|" benchmarks
    }
    in_benchmark = 0
    name = ""
    benchmarks = ""
    disabled = 0
    next
}

in_benchmark && /^[[:space:]]*Name[[:space:]]*=[[:space:]]*"/ {
    # 提取 Name 字段
    match($0, /"[^"]*"/)
    name = substr($0, RSTART+1, RLENGTH-2)
    next
}

in_benchmark && /^[[:space:]]*Benchmarks[[:space:]]*=[[:space:]]*"/ {
    # 提取 Benchmarks 字段（支持单引号和双引号）
    if (match($0, /"[^"]*"/)) {
        benchmarks = substr($0, RSTART+1, RLENGTH-2)
    } else if (match($0, /'\''[^'\'']*'\''/)) {
        benchmarks = substr($0, RSTART+1, RLENGTH-2)
    }
    next
}

in_benchmark && /^[[:space:]]*Disabled[[:space:]]*=[[:space:]]*[Tt][Rr][Uu][Ee]/ {
    disabled = 1
    next
}

END {
    # 处理最后一个 benchmark
    if (in_benchmark && name != "" && !disabled && benchmarks != "") {
        print name "|" benchmarks
    }
}
' "$TOML_FILE" | while IFS='|' read -r name benchmarks; do
    # 跳过空行
    [ -z "$name" ] && continue
    
    # 构建二进制文件名
    binary="${name}_RISC-V-Static"
    
    # 检查文件是否存在
    if [ ! -f "$binary" ]; then
        echo "[跳过] $binary 不存在"
        continue
    fi
    
    # 检查文件是否可执行
    if [ ! -x "$binary" ]; then
        echo "[警告] $binary 存在但不可执行，跳过"
        continue
    fi
    
    echo ""
    echo "[执行] $binary"
    echo "  Benchmark 模式: $benchmarks"
    echo "  测试次数: $COUNT"
    
    # 执行 benchmark 测试
    # 使用 -test.bench 指定要运行的测试，-test.count 指定运行次数
    set +e  # 临时关闭错误退出，以便捕获退出码
    ./"$binary" -test.run=^$ -test.bench="$benchmarks" -test.count="$COUNT" >> "$OUTPUT_FILE"
    exit_code=$?
    set -e  # 重新开启错误退出（虽然这里不会用到）
    
    if [ $exit_code -eq 0 ]; then
        echo "[完成] $binary"
    else
        echo "[失败] $binary 执行失败，退出码: $exit_code"
        # 继续执行下一个，不中断脚本
    fi
done

echo ""
echo "=========================================="
echo "所有 benchmark 测试执行完成"
echo "结果已保存到: $OUTPUT_FILE"
