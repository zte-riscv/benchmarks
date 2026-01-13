#!/bin/bash

# Script description: Analyze benchmark hotspots by running each benchmark separately
# and collecting profile data, then generating summary reports
# Usage: ./analyze-hotspots.sh <config file> <directory>
# Example: ./analyze-hotspots.sh tmp/picked.toml tmp/testbin

set -uo pipefail

# Check parameters
if [ $# -lt 2 ]; then
    echo "Error: Please provide config file path and directory path"
    echo "Usage: $0 <config file> <directory>"
    echo "Example: $0 tmp/picked.toml tmp/testbin"
    exit 1
fi

CONFIG_FILE=$1
TESTBIN_DIR=$2

# Architecture suffix for binary files (e.g., Amd64-Static, RISC-V-Static)
ARCH_SUFFIX="Amd64-Static"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

# Check if directory exists
if [ ! -d "$TESTBIN_DIR" ]; then
    echo "Error: Directory $TESTBIN_DIR not found"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Output files (use absolute paths to avoid issues when script is run from different directories)
RESULTS_FILE="${SCRIPT_DIR}/results.md"
POINT_FILE="${SCRIPT_DIR}/point.md"

# Check if helper scripts exist
GENERATE_RESULTS="${SCRIPT_DIR}/generate-results.sh"
GENERATE_POINTS="${SCRIPT_DIR}/generate-points.sh"
OPTIMIZE_RESULTS="${SCRIPT_DIR}/optimize-results.sh"

if [ ! -f "$GENERATE_RESULTS" ]; then
    echo "Error: generate-results.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$GENERATE_POINTS" ]; then
    echo "Error: generate-points.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$OPTIMIZE_RESULTS" ]; then
    echo "Error: optimize-results.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Step 1: Generate results.md
echo "=========================================="
echo "Step 1: Generating results.md"
echo "=========================================="
"$GENERATE_RESULTS" "$CONFIG_FILE" "$TESTBIN_DIR" "$RESULTS_FILE" "$ARCH_SUFFIX"

# Step 2: Generate point.md from results.md
echo ""
echo "=========================================="
echo "Step 2: Generating point.md from results.md"
echo "=========================================="
"$GENERATE_POINTS" "$RESULTS_FILE" "$POINT_FILE"

# Step 3: Optimize results.md
echo ""
echo "=========================================="
echo "Step 3: Optimizing results.md"
echo "=========================================="
"$OPTIMIZE_RESULTS" "$RESULTS_FILE"

echo ""
echo "=========================================="
echo "Analysis completed"
echo "Results saved to: $RESULTS_FILE"
echo "Hotspot points saved to: $POINT_FILE"
