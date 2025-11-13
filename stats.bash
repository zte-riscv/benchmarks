#!/bin/bash
set -e

# 参数解析
BASELINE_DIR="$1"
NEW_DIR="$2"
BENCHSTAT_BIN="${3:-benchstat}"

# 如果 benchstat 不在 PATH 中，尝试当前目录
if ! command -v "$BENCHSTAT_BIN" &> /dev/null; then
    # 尝试当前目录下的 benchstat
    if [ -f "./benchstat" ] && [ -x "./benchstat" ]; then
        BENCHSTAT_BIN="./benchstat"
    elif [ -f "../benchstat" ] && [ -x "../benchstat" ]; then
        BENCHSTAT_BIN="../benchstat"
    else
        echo "Error: $BENCHSTAT_BIN not found!"
        echo ""
        echo "To install benchstat, run:"
        echo "  go install golang.org/x/perf/cmd/benchstat@latest"
        echo ""
        echo "Or specify the path as the third argument:"
        echo "  $0 baseline_dir new_dir /path/to/benchstat"
        exit 1
    fi
fi

# 如果指定了两个目录，进行显式比较
if [ -n "$BASELINE_DIR" ] && [ -n "$NEW_DIR" ]; then
    # 检查目录是否存在
    if [ ! -d "$BASELINE_DIR" ]; then
        echo "Error: Baseline directory '$BASELINE_DIR' not found!"
        exit 1
    fi
    if [ ! -d "$NEW_DIR" ]; then
        echo "Error: New directory '$NEW_DIR' not found!"
        exit 1
    fi
    
    echo "Comparing benchmark results:"
    echo "  Baseline: $BASELINE_DIR"
    echo "  New:      $NEW_DIR"
    echo "  Using:    $BENCHSTAT_BIN"
    echo ""
    
    # 查找转换脚本路径
    CONVERT_SCRIPT=""
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/convert_gc_latency.sh" ]; then
        CONVERT_SCRIPT="$SCRIPT_DIR/convert_gc_latency.sh"
    elif [ -f "./convert_gc_latency.sh" ]; then
        CONVERT_SCRIPT="./convert_gc_latency.sh"
    fi
    
    # 查找所有基准测试并比较
    BENCHMARKS=("json" "garbage" "gc_latency")
    FOUND_ANY=false
    
    for bench_name in "${BENCHMARKS[@]}"; do
        baseline_file="$BASELINE_DIR/${bench_name}-results.txt"
        new_file="$NEW_DIR/${bench_name}-results.txt"
        
        if [ -f "$baseline_file" ] && [ -f "$new_file" ]; then
            FOUND_ANY=true
            echo "=== $bench_name ==="
            echo "  Baseline: $(basename "$baseline_file")"
            echo "  New:      $(basename "$new_file")"
            echo ""
            
            # 如果是 gc_latency，需要先转换格式
            if [ "$bench_name" = "gc_latency" ] && [ -n "$CONVERT_SCRIPT" ]; then
                # 创建临时转换文件
                TMP_DIR=$(mktemp -d)
                trap "rm -rf $TMP_DIR" EXIT
                
                baseline_converted="$TMP_DIR/baseline-converted.txt"
                new_converted="$TMP_DIR/new-converted.txt"
                
                echo "  Converting gc_latency format for benchstat..."
                if "$CONVERT_SCRIPT" "$baseline_file" "$baseline_converted" 2>&1 | sed 's/^/    /' && \
                   "$CONVERT_SCRIPT" "$new_file" "$new_converted" 2>&1 | sed 's/^/    /'; then
                    if "$BENCHSTAT_BIN" "$baseline_converted" "$new_converted" 2>&1; then
                        echo ""
                    else
                        echo "  ⚠ Comparison failed"
                        echo ""
                    fi
                else
                    echo "  ⚠ Conversion failed, trying direct comparison..."
                    if "$BENCHSTAT_BIN" "$baseline_file" "$new_file" 2>&1; then
                        echo ""
                    else
                        echo "  ⚠ Comparison failed"
                        echo ""
                    fi
                fi
            else
                # 标准格式，直接比较
                if "$BENCHSTAT_BIN" "$baseline_file" "$new_file" 2>&1; then
                    echo ""
                else
                    echo "  ⚠ Comparison failed"
                    echo ""
                fi
            fi
        elif [ -f "$baseline_file" ] || [ -f "$new_file" ]; then
            echo "⚠ $bench_name: Missing one of the result files"
            echo "  Baseline: $([ -f "$baseline_file" ] && echo "✓ $(basename "$baseline_file")" || echo "✗ not found")"
            echo "  New:      $([ -f "$new_file" ] && echo "✓ $(basename "$new_file")" || echo "✗ not found")"
            echo ""
        fi
    done
    
    if [ "$FOUND_ANY" = false ]; then
        echo "No matching result files found in both directories."
        echo "Expected files: *-results.txt (e.g., json-results.txt, garbage-results.txt)"
    fi
    
    exit 0
fi

# 如果只指定了一个参数，使用自动检测模式
if [ -n "$BASELINE_DIR" ] && [ -z "$NEW_DIR" ]; then
    RESULTS_DIR="$BASELINE_DIR"
elif [ -z "$BASELINE_DIR" ] && [ -z "$NEW_DIR" ]; then
    RESULTS_DIR="results"
else
    # 不应该到这里，因为两个目录的情况已经在上面处理了
    echo "Error: Invalid arguments"
    exit 1
fi

# 检查结果目录是否存在
if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Results directory '$RESULTS_DIR' not found!"
    echo ""
    echo "Usage:"
    echo "  # Compare two directories explicitly"
    echo "  $0 baseline_dir new_dir [benchstat_path]"
    echo ""
    echo "  # Auto-detect in single directory"
    echo "  $0 results_dir"
    echo ""
    echo "Examples:"
    echo "  $0 results-go1.21 results-go1.22"
    echo "  $0 results-go1.21 results-go1.22 ./benchstat"
    echo "  $0 results  # auto-detect mode"
    exit 1
fi

echo "Analyzing results in: $RESULTS_DIR/"
echo "Using benchstat: $BENCHSTAT_BIN"
echo ""

# 查找所有结果文件
RESULT_FILES=$(find "$RESULTS_DIR" -name "*-results.txt" -type f 2>/dev/null | sort)

if [ -z "$RESULT_FILES" ]; then
    echo "No result files found in $RESULTS_DIR/"
    echo "Expected files matching pattern: *-results.txt"
    exit 1
fi

# 统计每个基准测试的结果文件
declare -A BENCHMARK_FILES
for file in $RESULT_FILES; do
    # 提取基准测试名称（例如：json-results.txt -> json）
    basename_file=$(basename "$file")
    bench_name=$(echo "$basename_file" | sed 's/-results\.txt$//')
    
    if [ -z "${BENCHMARK_FILES[$bench_name]}" ]; then
        BENCHMARK_FILES[$bench_name]="$file"
    else
        BENCHMARK_FILES[$bench_name]="${BENCHMARK_FILES[$bench_name]} $file"
    fi
done

# 如果有多个版本的结果，尝试配对比较
echo "=== Benchmark Results Summary ==="
echo ""

for bench_name in $(printf '%s\n' "${!BENCHMARK_FILES[@]}" | sort); do
    files="${BENCHMARK_FILES[$bench_name]}"
    file_count=$(echo "$files" | wc -w)
    
    echo "Benchmark: $bench_name"
    echo "  Found $file_count result file(s):"
    for file in $files; do
        file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "?")
        echo "    - $(basename "$file") ($(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size}B"))"
    done
    
    if [ "$file_count" -eq 1 ]; then
        # 单个文件，只显示统计信息
        echo ""
        echo "  Results:"
        file=$(echo "$files" | awk '{print $1}')
        if [ -f "$file" ]; then
            # 提取关键指标
            if grep -q "ns/op" "$file"; then
                line_count=$(grep -c "^Benchmark" "$file" 2>/dev/null || echo "0")
                if [ "$line_count" -gt 0 ]; then
                    echo "    Number of runs: $line_count"
                    # 显示第一行和最后一行的 ns/op 值
                    first_ns=$(grep "^Benchmark" "$file" | head -1 | awk '{print $3}' || echo "N/A")
                    last_ns=$(grep "^Benchmark" "$file" | tail -1 | awk '{print $3}' || echo "N/A")
                    echo "    First run ns/op:  $first_ns"
                    echo "    Last run ns/op:   $last_ns"
                fi
            else
                echo "    ⚠ No benchmark data found in expected format"
            fi
        fi
    elif [ "$file_count" -eq 2 ]; then
        # 两个文件，进行对比
        file1=$(echo "$files" | awk '{print $1}')
        file2=$(echo "$files" | awk '{print $2}')
        echo ""
        echo "  Comparing:"
        echo "    Baseline:   $(basename "$file1")"
        echo "    Experiment: $(basename "$file2")"
        echo ""
        echo "  Comparison results:"
        echo "  ──────────────────────────────────────────────────────────"
        if "$BENCHSTAT_BIN" "$file1" "$file2" 2>&1 | sed 's/^/  /'; then
            echo "  ──────────────────────────────────────────────────────────"
        else
            echo "  ⚠ Comparison failed, check file formats"
        fi
    else
        # 多个文件，尝试智能配对
        echo ""
        echo "  Multiple result files found. Attempting smart pairing..."
        
        # 尝试找到 baseline 和 experiment 配对
        baseline_file=$(echo "$files" | tr ' ' '\n' | grep -i "baseline\|go1\.21\|v1" | head -1)
        experiment_file=$(echo "$files" | tr ' ' '\n' | grep -i "experiment\|go1\.22\|v2" | head -1)
        
        if [ -n "$baseline_file" ] && [ -n "$experiment_file" ] && [ "$baseline_file" != "$experiment_file" ]; then
            echo "  Auto-paired files:"
            echo "    Baseline:   $(basename "$baseline_file")"
            echo "    Experiment: $(basename "$experiment_file")"
            echo ""
            echo "  Comparison results:"
            echo "  ──────────────────────────────────────────────────────────"
            if "$BENCHSTAT_BIN" "$baseline_file" "$experiment_file" 2>&1 | sed 's/^/  /'; then
                echo "  ──────────────────────────────────────────────────────────"
            else
                echo "  ⚠ Comparison failed"
            fi
        else
            echo "  ⚠ Could not auto-pair files. Please specify which files to compare."
            echo "  Example: $BENCHSTAT_BIN $RESULTS_DIR/${bench_name}-baseline.txt $RESULTS_DIR/${bench_name}-experiment.txt"
        fi
    fi
    echo ""
done

# 如果结果目录有子目录结构（如 results-go1.21/, results-go1.22/），尝试跨目录比较
echo "=== Cross-Directory Comparisons ==="
echo ""

# 查找可能的版本子目录
VERSION_DIRS=$(find "$RESULTS_DIR" -maxdepth 1 -type d -name "*go1.*" -o -name "*baseline*" -o -name "*experiment*" 2>/dev/null | sort)

if [ -n "$VERSION_DIRS" ] && [ "$(echo "$VERSION_DIRS" | wc -l)" -ge 2 ]; then
    baseline_dir=$(echo "$VERSION_DIRS" | grep -i "baseline\|go1\.21" | head -1)
    experiment_dir=$(echo "$VERSION_DIRS" | grep -i "experiment\|go1\.22" | head -1)
    
    if [ -n "$baseline_dir" ] && [ -n "$experiment_dir" ] && [ "$baseline_dir" != "$experiment_dir" ]; then
        echo "Found version directories:"
        echo "  Baseline:   $(basename "$baseline_dir")"
        echo "  Experiment: $(basename "$experiment_dir")"
        echo ""
        
        # 查找转换脚本路径
        CONVERT_SCRIPT=""
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$SCRIPT_DIR/convert_gc_latency.sh" ]; then
            CONVERT_SCRIPT="$SCRIPT_DIR/convert_gc_latency.sh"
        elif [ -f "./convert_gc_latency.sh" ]; then
            CONVERT_SCRIPT="./convert_gc_latency.sh"
        fi
        
        # 比较每个基准测试
        for bench_name in json garbage gc_latency; do
            baseline_file="$baseline_dir/${bench_name}-results.txt"
            experiment_file="$experiment_dir/${bench_name}-results.txt"
            
            if [ -f "$baseline_file" ] && [ -f "$experiment_file" ]; then
                echo "Comparing $bench_name:"
                echo "  ──────────────────────────────────────────────────────────"
                
                # 如果是 gc_latency，需要先转换格式
                if [ "$bench_name" = "gc_latency" ] && [ -n "$CONVERT_SCRIPT" ]; then
                    TMP_DIR=$(mktemp -d)
                    trap "rm -rf $TMP_DIR" EXIT
                    
                    baseline_converted="$TMP_DIR/baseline-converted.txt"
                    experiment_converted="$TMP_DIR/experiment-converted.txt"
                    
                    if "$CONVERT_SCRIPT" "$baseline_file" "$baseline_converted" >/dev/null 2>&1 && \
                       "$CONVERT_SCRIPT" "$experiment_file" "$experiment_converted" >/dev/null 2>&1; then
                        if "$BENCHSTAT_BIN" "$baseline_converted" "$experiment_converted" 2>&1 | sed 's/^/  /'; then
                            echo "  ──────────────────────────────────────────────────────────"
                        fi
                    else
                        echo "  ⚠ Conversion failed for gc_latency"
                    fi
                else
                    if "$BENCHSTAT_BIN" "$baseline_file" "$experiment_file" 2>&1 | sed 's/^/  /'; then
                        echo "  ──────────────────────────────────────────────────────────"
                    fi
                fi
                echo ""
            fi
        done
    fi
fi

# 提供使用建议
echo "=== Usage Tips ==="
echo ""
echo "To compare specific files manually:"
echo "  $BENCHSTAT_BIN $RESULTS_DIR/file1.txt $RESULTS_DIR/file2.txt"
echo ""
echo "To compare all results from two directories:"
echo "  $BENCHSTAT_BIN <(cat $RESULTS_DIR/*baseline*.txt) <(cat $RESULTS_DIR/*experiment*.txt)"
echo ""
echo "Result files should be in Go benchmark format with multiple runs."
echo "Each file should contain multiple lines like:"
echo "  BenchmarkJSON-4     1000    1234567 ns/op    ..."
echo ""

