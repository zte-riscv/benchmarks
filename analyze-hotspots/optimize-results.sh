#!/bin/bash

# Script description: Optimize results.md by removing duplicate package names and test case names in adjacent rows
# Usage: ./optimize-results.sh <results file>
# Example: ./optimize-results.sh results.md

set -uo pipefail

# Check parameters
if [ $# -lt 1 ]; then
    echo "Error: Please provide results file"
    echo "Usage: $0 <results file>"
    echo "Example: $0 results.md"
    exit 1
fi

RESULTS_FILE=$1

# Check if results file exists
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: Results file $RESULTS_FILE not found"
    exit 1
fi

# Create temporary file
TEMP_FILE="${RESULTS_FILE}.tmp"

# Process results.md to optimize duplicate package and test case names
awk -F'|' '
BEGIN {
    prev_package = ""
    prev_testcase = ""
}

# Keep header lines as is
NR <= 2 {
    print $0
    next
}

# Process data rows
NF >= 4 {
    current_package = $2
    current_testcase = $3
    hotspot = $4
    
    # If package name is same as previous, leave it empty
    if (current_package == prev_package) {
        package_output = ""
    } else {
        package_output = current_package
    }
    
    # If test case name is same as previous, leave it empty
    if (current_testcase == prev_testcase) {
        testcase_output = ""
    } else {
        testcase_output = current_testcase
    }
    
    # Output the optimized line
    printf "|%s|%s|%s|\n", package_output, testcase_output, hotspot
    
    # Update previous values
    prev_package = current_package
    prev_testcase = current_testcase
}
' "$RESULTS_FILE" > "$TEMP_FILE"

# Replace original file with optimized version
mv "$TEMP_FILE" "$RESULTS_FILE"

echo "Results optimization completed"
echo "Optimized results saved to: $RESULTS_FILE"

