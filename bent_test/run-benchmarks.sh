#!/bin/bash

# Script description: Execute compiled benchmark test files based on TOML configuration file
# Usage: ./run-benchmarks.sh <TOML file> <test count> <output file>
# Example: ./run-benchmarks.sh benchmarks-50.toml 5 results.txt

set -uo pipefail
# Do not use -e, so execution continues in loop even if a command fails

# Check parameters
if [ $# -lt 3 ]; then
    echo "Error: Please provide TOML file path, test count, and output file path"
    echo "Usage: $0 <TOML file> <test count> <output file>"
    echo "Example: $0 benchmarks-50.toml 5 results.txt"
    exit 1
fi

TOML_FILE=$1
COUNT=$2
OUTPUT_FILE=$3

# Check if TOML file exists
if [ ! -f "$TOML_FILE" ]; then
    echo "Error: File $TOML_FILE not found"
    exit 1
fi

# Validate test count is a positive integer
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
    echo "Error: Test count must be a positive integer"
    exit 1
fi

echo "Starting benchmark test execution"
echo "TOML configuration file: $TOML_FILE"
echo "Test count: $COUNT"
echo "Output file: $OUTPUT_FILE"
echo "=========================================="

# Parse TOML file and execute benchmarks
# Use awk to parse TOML format
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
    # Extract Benchmarks field (supports both single and double quotes)
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
' "$TOML_FILE" | while IFS='|' read -r name benchmarks; do
    # Skip empty lines
    [ -z "$name" ] && continue
    
    # Build binary file name
    binary="${name}_RISC-V-Static"
    
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
    echo "[Execute] $binary"
    echo "  Benchmark pattern: $benchmarks"
    echo "  Test count: $COUNT"
    
    # Execute benchmark test
    # Use -test.bench to specify tests to run, -test.count to specify run count
    set +e  # Temporarily disable error exit to capture exit code
    ./"$binary" -test.run=^$ -test.bench="$benchmarks" -test.count="$COUNT" >> "$OUTPUT_FILE"
    exit_code=$?
    set -e  # Re-enable error exit (though not used here)
    
    if [ $exit_code -eq 0 ]; then
        echo "[Complete] $binary"
    else
        echo "[Failed] $binary execution failed, exit code: $exit_code"
        # Continue to next, do not interrupt script
    fi
done

echo ""
echo "=========================================="
echo "All benchmark tests execution completed"
echo "Results saved to: $OUTPUT_FILE"
