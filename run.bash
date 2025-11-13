#!/bin/bash
set -e

# 默认参数
BENCHMARK_DIR="${1:-go_benchmarks}"
RESULTS_DIR="${2:-results}"
BENCHNUM="${3:-10}"
BENCHTIME="${4:-5s}"

# 检查基准测试目录是否存在
if [ ! -d "$BENCHMARK_DIR" ]; then
    echo "Error: Benchmark directory '$BENCHMARK_DIR' not found!"
    echo "Usage: $0 [benchmark_dir] [results_dir] [benchnum] [benchtime]"
    echo "  benchmark_dir: Directory containing benchmark binaries (default: go_benchmarks)"
    echo "  results_dir:   Directory to save results (default: results)"
    echo "  benchnum:      Number of benchmark runs (default: 10)"
    echo "  benchtime:     Duration per run (default: 5s)"
    exit 1
fi

# 创建结果目录
mkdir -p "$RESULTS_DIR"
echo "Results will be saved to: $RESULTS_DIR/"

# 运行 JSON 基准测试
if [ -f "$BENCHMARK_DIR/json-riscv64" ]; then
    echo "Running JSON benchmark (benchnum=$BENCHNUM, benchtime=$BENCHTIME)..."
    if "$BENCHMARK_DIR/json-riscv64" -benchnum "$BENCHNUM" -benchtime "$BENCHTIME" 2>&1 | tee "$RESULTS_DIR/json-results.txt"; then
        echo "✓ JSON benchmark completed successfully"
        echo "  Results saved to: $RESULTS_DIR/json-results.txt"
    else
        echo "✗ JSON benchmark failed"
        echo "  Check $RESULTS_DIR/json-results.txt for details"
    fi
else
    echo "⚠ JSON benchmark binary not found: $BENCHMARK_DIR/json-riscv64"
fi

# 运行 Garbage 基准测试
if [ -f "$BENCHMARK_DIR/garbage-riscv64" ]; then
    echo "Running Garbage benchmark (benchnum=$BENCHNUM, benchtime=$BENCHTIME)..."
    if "$BENCHMARK_DIR/garbage-riscv64" -benchnum "$BENCHNUM" -benchtime "$BENCHTIME" 2>&1 | tee "$RESULTS_DIR/garbage-results.txt"; then
        echo "✓ Garbage benchmark completed successfully"
        echo "  Results saved to: $RESULTS_DIR/garbage-results.txt"
    else
        echo "✗ Garbage benchmark failed"
        echo "  Check $RESULTS_DIR/garbage-results.txt for details"
    fi
else
    echo "⚠ Garbage benchmark binary not found: $BENCHMARK_DIR/garbage-riscv64"
fi

# 运行 GC Latency 基准测试
# 注意：gc_latency 不使用 driver 包，不支持 -benchnum 和 -benchtime 参数
# 它只支持自己的参数：-how (stack/heap/global), -fluff, -trace
if [ -f "$BENCHMARK_DIR/gc_latency-riscv64" ]; then
    echo "Running GC Latency benchmark (note: does not support benchnum/benchtime)..."
    if "$BENCHMARK_DIR/gc_latency-riscv64" 2>&1 | tee "$RESULTS_DIR/gc_latency-results.txt"; then
        echo "✓ GC Latency benchmark completed successfully"
        echo "  Results saved to: $RESULTS_DIR/gc_latency-results.txt"
    else
        echo "✗ GC Latency benchmark failed"
        echo "  Check $RESULTS_DIR/gc_latency-results.txt for details"
    fi
else
    echo "⚠ GC Latency benchmark binary not found: $BENCHMARK_DIR/gc_latency-riscv64"
fi

echo ""
echo "All benchmarks completed!"
echo "Results directory: $RESULTS_DIR/"
echo "Result files:"
ls -lh "$RESULTS_DIR"/*.txt 2>/dev/null || echo "  (No result files found)"

echo ""
echo "To compare results, you can use benchstat:"
echo "  benchstat $RESULTS_DIR/baseline-json-results.txt $RESULTS_DIR/experiment-json-results.txt"

# 将结果文件夹移到上一级目录
if [ -d "$RESULTS_DIR" ]; then
    PARENT_RESULTS_DIR="../$RESULTS_DIR"
    if [ -d "$PARENT_RESULTS_DIR" ]; then
        echo ""
        echo "⚠ Warning: $PARENT_RESULTS_DIR already exists, will be overwritten"
        echo "  Removing existing directory: $PARENT_RESULTS_DIR"
        rm -rf "$PARENT_RESULTS_DIR"
    fi
    echo ""
    echo "Moving results directory to parent directory..."
    echo "  From: $RESULTS_DIR"
    echo "  To:   $PARENT_RESULTS_DIR"
    if mv "$RESULTS_DIR" "$PARENT_RESULTS_DIR"; then
        echo "✓ Results directory moved to: $PARENT_RESULTS_DIR"
    else
        echo "✗ Failed to move results directory"
    fi
fi
