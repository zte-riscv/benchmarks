#!/bin/bash
# 将 gc_latency 的输出转换为 benchstat 可识别的标准格式
# 用法: convert_gc_latency.sh <input_file> [output_file]
# 如果不指定 output_file，输出到 stdout

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Usage: $0 <gc_latency-results.txt> [output_file]" >&2
    echo "  If output_file is not specified, output to stdout" >&2
    exit 1
fi

# 解析 gc_latency 输出并转换为标准格式
# 输出格式: BenchmarkName-4    N    value ns/op
# 其中 N 是运行次数（对于单次运行，我们使用 1）

# 提取配置信息
HOW=$(grep "how=" "$INPUT_FILE" | sed 's/.*how=\([^,]*\).*/\1/')
FLUFF=$(grep "fluff=" "$INPUT_FILE" | sed 's/.*fluff=\(.*\)/\1/')

# 转换为基准测试名称
BENCH_NAME="GCLatency"
if [ -n "$HOW" ]; then
    BENCH_NAME="${BENCH_NAME}/how=${HOW}"
fi
if [ -n "$FLUFF" ]; then
    BENCH_NAME="${BENCH_NAME}/fluff=${FLUFF}"
fi

# 函数：将时间字符串转换为纳秒
# 支持: ns, µs, ms, s
time_to_ns() {
    local time_str="$1"
    local value=$(echo "$time_str" | sed 's/[^0-9.]//g')
    local unit=$(echo "$time_str" | sed 's/[0-9.]//g')
    
    case "$unit" in
        ns|n)
            echo "$value" | awk '{printf "%.0f", $1}'
            ;;
        µs|us|u)
            echo "$value" | awk '{printf "%.0f", $1 * 1000}'
            ;;
        ms|m)
            echo "$value" | awk '{printf "%.0f", $1 * 1000000}'
            ;;
        s|S)
            echo "$value" | awk '{printf "%.0f", $1 * 1000000000}'
            ;;
        *)
            # 默认假设是纳秒
            echo "$value" | awk '{printf "%.0f", $1}'
            ;;
    esac
}

# 提取各个指标并转换
AVG_LATENCY=$(grep "Average allocation latency:" "$INPUT_FILE" | awk '{print $4}')
MEDIAN_LATENCY=$(grep "Median allocation latency:" "$INPUT_FILE" | awk '{print $4}')
P99_LATENCY=$(grep "99% allocation latency:" "$INPUT_FILE" | awk '{print $4}')
P999_LATENCY=$(grep "99.9% allocation latency:" "$INPUT_FILE" | awk '{print $4}')
P9999_LATENCY=$(grep "99.99% allocation latency:" "$INPUT_FILE" | awk '{print $4}')
P99999_LATENCY=$(grep "99.999% allocation latency:" "$INPUT_FILE" | awk '{print $4}')
P999999_LATENCY=$(grep "99.9999% allocation latency:" "$INPUT_FILE" | awk '{print $4}')
WORST_LATENCY=$(grep "Worst allocation latency:" "$INPUT_FILE" | awk '{print $4}')

# 转换为纳秒
AVG_NS=$(time_to_ns "$AVG_LATENCY")
MEDIAN_NS=$(time_to_ns "$MEDIAN_LATENCY")
P99_NS=$(time_to_ns "$P99_LATENCY")
P999_NS=$(time_to_ns "$P999_LATENCY")
P9999_NS=$(time_to_ns "$P9999_LATENCY")
P99999_NS=$(time_to_ns "$P99999_LATENCY")
P999999_NS=$(time_to_ns "$P999999_LATENCY")
WORST_NS=$(time_to_ns "$WORST_LATENCY")

# 生成标准格式输出
{
    echo "pkg: golang.org/x/benchmarks"
    echo "goos: linux"
    echo "goarch: riscv64"
    echo "Benchmark${BENCH_NAME}-20    1    ${AVG_NS} avg-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${MEDIAN_NS} median-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${P99_NS} p99-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${P999_NS} p999-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${P9999_NS} p9999-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${P99999_NS} p99999-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${P999999_NS} p999999-latency-ns/op"
    echo "Benchmark${BENCH_NAME}-20    1    ${WORST_NS} worst-latency-ns/op"
} > "${OUTPUT_FILE:-/dev/stdout}"

if [ -n "$OUTPUT_FILE" ]; then
    echo "Converted gc_latency output to: $OUTPUT_FILE" >&2
fi

