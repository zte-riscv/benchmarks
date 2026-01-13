#!/bin/bash

# Script description: Generate results.md by running benchmarks and analyzing profiles
# Usage: ./generate-results.sh <config file> <directory> <results file> <arch suffix>
# Example: ./generate-results.sh tmp/picked.toml tmp/testbin results.md Amd64-Static

set -uo pipefail

# Check parameters
if [ $# -lt 4 ]; then
    echo "Error: Please provide config file, directory, results file, and arch suffix"
    echo "Usage: $0 <config file> <directory> <results file> <arch suffix>"
    exit 1
fi

CONFIG_FILE=$1
TESTBIN_DIR=$2
RESULTS_FILE=$3
ARCH_SUFFIX=$4
PROFILE_FILE="cpu.out"

# Threshold for flat% filtering (only include functions with flat% > this value)
FLAT_PCT_THRESHOLD=5.0

# Initialize results file
echo "|测试包|测试用例|热点函数|" > "$RESULTS_FILE"
echo "|------|--------|--------|" >> "$RESULTS_FILE"

echo "Starting benchmark hotspot analysis"
echo "Config file: $CONFIG_FILE"
echo "Test binary directory: $TESTBIN_DIR"
echo "=========================================="

# Parse TOML file and process benchmarks
awk '
BEGIN {
    in_benchmark = 0
    name = ""
    benchmarks = ""
    disabled = 0
}

/^\[\[Benchmarks\]\]/ {
    # Process previous benchmark (if any)
    if (in_benchmark && name != "" && !disabled && benchmarks != "") {
        print name "|" benchmarks
    }
    # Reset state
    in_benchmark = 1
    name = ""
    benchmarks = ""
    disabled = 0
    next
}

/^\[\[/ {
    # Encounter new section, process previous benchmark
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
    # Extract Name field
    match($0, /"[^"]*"/)
    name = substr($0, RSTART+1, RLENGTH-2)
    next
}

in_benchmark && /^[[:space:]]*Benchmarks[[:space:]]*=[[:space:]]*"/ {
    # Extract Benchmarks field
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
    # Process last benchmark
    if (in_benchmark && name != "" && !disabled && benchmarks != "") {
        print name "|" benchmarks
    }
}
' "$CONFIG_FILE" | while IFS='|' read -r name benchmarks; do
    # Skip empty lines
    [ -z "$name" ] && continue
    
    # Build binary file path
    binary="${TESTBIN_DIR}/${name}_${ARCH_SUFFIX}"
    
    # Check if file exists
    if [ ! -f "$binary" ]; then
        echo "[Skip] $binary does not exist"
        continue
    fi
    
    # Check if file is executable
    if [ ! -x "$binary" ]; then
        echo "[Warning] $binary exists but is not executable, skipping"
        continue
    fi
    
    echo ""
    echo "[Process] $binary"
    echo "  Benchmark pattern: $benchmarks"
    
    # Get list of matching benchmarks
    # Run benchmark once to get the list (without profile)
    set +e
    benchmark_list=$(cd "$TESTBIN_DIR" && ./"$(basename "$binary")" -test.run=none -test.bench="$benchmarks" 2>&1 | grep -E "^Benchmark" | awk '{print $1}' | sort -u)
    set -e
    
    if [ -z "$benchmark_list" ]; then
        echo "  [Warning] No benchmarks found matching pattern: $benchmarks"
        continue
    fi
    
    # Process each benchmark separately
    while IFS= read -r benchmark_name; do
        [ -z "$benchmark_name" ] && continue
        
        echo "  [Running] $benchmark_name"
        
        # Remove the -N suffix (e.g., -6) from benchmark name for execution
        # The -N suffix indicates the number of iterations, but we need the base name for -test.bench
        # Example: "BenchmarkStandardJSON-6" -> "BenchmarkStandardJSON"
        benchmark_base_name=$(echo "$benchmark_name" | sed 's/-[0-9]\+$//')
        
        # Run benchmark with cpuprofile
        set +e
        cd "$TESTBIN_DIR"
        ./"$(basename "$binary")" -test.run=none -test.bench="^${benchmark_base_name}$" -test.cpuprofile="$PROFILE_FILE" >/dev/null 2>&1
        exit_code=$?
        cd - >/dev/null
        set -e
        
        if [ $exit_code -ne 0 ]; then
            echo "    [Failed] Execution failed for $benchmark_name"
            continue
        fi
        
        # Analyze profile with pprof
        if [ ! -f "${TESTBIN_DIR}/${PROFILE_FILE}" ]; then
            echo "    [Warning] Profile file not generated for $benchmark_name"
            continue
        fi
        
        # Get top 30 from pprof, filter flat% > FLAT_PCT_THRESHOLD
        # Use pprof in non-interactive mode with pipe input
        # Parse pprof output to extract lines with flat% > FLAT_PCT_THRESHOLD
        # Write results directly to file to avoid subshell issues
        echo "top 30" | go tool pprof -flat "${TESTBIN_DIR}/${PROFILE_FILE}" 2>/dev/null | awk -v pkg_name="$name" -v bench_name="$benchmark_name" -v results_file="$RESULTS_FILE" -v flat_pct_threshold="$FLAT_PCT_THRESHOLD" '
BEGIN {
    header_found = 0
}
/flat[[:space:]]+flat%/ {
    header_found = 1
    next
}
header_found && /^[[:space:]]*[0-9]/ {
    # Extract flat% value (second percentage column)
    # Format: flat_time flat% sum% cum_time cum% function_name
    # Example: "     0.84s 51.22% 51.22%      1.52s 92.68%  github.com/tetratelabs/wazero/..."
    # Match the first percentage value (flat%) - it is the second field after time
    # Split the line to get fields: time, flat%, sum%, cum_time, cum%, function
    if (NF >= 6) {
        # Extract flat% from the second field (remove % sign)
        flat_pct_str = $2
        gsub(/%/, "", flat_pct_str)
        flat_pct = flat_pct_str + 0
        if (flat_pct > flat_pct_threshold) {
            # Write directly to results file from awk, record the full line
            printf "|%s|%s|%s|\n", pkg_name, bench_name, $0 >> results_file
            close(results_file)
        }
    }
}
'
        
        # Clean up profile file after recording results
        rm -f "${TESTBIN_DIR}/${PROFILE_FILE}"
        
        echo "    [Complete] $benchmark_name"
    done <<< "$benchmark_list"
    
    echo "[Complete] $binary"
done

echo ""
echo "Results generation completed"
echo "Results saved to: $RESULTS_FILE"

