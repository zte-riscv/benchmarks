#!/bin/bash

# Script description: Generate point.md from results.md
# Usage: ./generate-points.sh <results file> <point file>
# Example: ./generate-points.sh results.md point.md

set -uo pipefail

# Check parameters
if [ $# -lt 2 ]; then
    echo "Error: Please provide results file and point file"
    echo "Usage: $0 <results file> <point file>"
    echo "Example: $0 results.md point.md"
    exit 1
fi

RESULTS_FILE=$1
POINT_FILE=$2

# Check if results file exists
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: Results file $RESULTS_FILE not found"
    exit 1
fi

echo "Generating point.md from results.md"

# Generate point.md from results.md
# Group by hotspot function and list all test cases with their flat% values
awk -F'|' '
NR > 2 && NF >= 4 {
    package = $2
    testcase = $3
    hotspot_line = $4
    
    # Extract function name from hotspot line
    # The format is: flat_time flat% sum% cum_time cum% function_name
    # Example: "     0.82s 56.55% 56.55%      1.35s 93.10%  github.com/tetratelabs/wazero/..."
    # Function name starts after the 5th field (cum%)
    # First, normalize multiple spaces to single space
    gsub(/[[:space:]]+/, " ", hotspot_line)
    sub(/^ /, "", hotspot_line)  # Remove leading space
    field_count = split(hotspot_line, field_array, " ")
    if (field_count >= 6) {
        # Function name is from field 6 to the end
        func_name = field_array[6]
        for (idx = 7; idx <= field_count; idx++) {
            func_name = func_name " " field_array[idx]
        }
    } else {
        # Fallback: use last field
        func_name = field_array[field_count]
    }
    
    # Extract flat% value
    # Match both integer percentages (100%) and decimal percentages (66.67%)
    match(hotspot_line, /[0-9]+(\.[0-9]+)?%/)
    if (RSTART > 0) {
        flat_pct = substr(hotspot_line, RSTART, RLENGTH-1)
        # Store: func_name -> testcase -> flat_pct
        if (!seen[func_name, testcase]) {
            seen[func_name, testcase] = flat_pct
            funcs[func_name] = 1
        }
    }
}
END {
    # Output point.md format
    print "|热点函数|热点值|"
    print "|--------|------|"
    
    # Collect all function names and sort them
    func_count = 0
    for (func_name in funcs) {
        func_count++
        func_list[func_count] = func_name
    }
    # Simple bubble sort for function names
    for (i = 1; i <= func_count; i++) {
        for (j = i + 1; j <= func_count; j++) {
            if (func_list[i] > func_list[j]) {
                temp = func_list[i]
                func_list[i] = func_list[j]
                func_list[j] = temp
            }
        }
    }
    
    # Process each function
    for (i = 1; i <= func_count; i++) {
        current_func = func_list[i]
        first = 1
        # Collect and output all test cases for this function
        for (key in seen) {
            split(key, parts, SUBSEP)
            if (parts[1] == current_func) {
                testcase = parts[2]
                flat_pct = seen[key]
                if (first) {
                    printf "|%s|%s             %s%%|\n", current_func, testcase, flat_pct
                    first = 0
                } else {
                    printf "||%s             %s%%|\n", testcase, flat_pct
                }
            }
        }
    }
}
' "$RESULTS_FILE" > "$POINT_FILE"

echo "Point generation completed"
echo "Hotspot points saved to: $POINT_FILE"

