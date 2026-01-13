# Benchmark Hotspot Analysis Tools

## Overview

This toolset automates the analysis of hotspot functions in Go benchmark tests. It runs each benchmark test individually, collects CPU profile data, uses `pprof` to identify hotspot functions, and generates summary reports.

## Features

- Automatically parses TOML configuration files and iterates through all configured benchmarks
- Supports regular expressions to match multiple benchmark test cases
- Runs each benchmark test separately to ensure accurate performance analysis
- Automatically filters hotspot functions (only includes functions with `flat% > 5%`)
- Generates two summary reports:
  - `results.md`: Detailed information about test packages, test cases, and hotspot functions
  - `point.md`: Summary information grouped by hotspot function
- Optimizes output format for better Markdown readability

## Scripts

### Main Script

#### `analyze-hotspots.sh`
Main entry script that orchestrates the entire analysis workflow.

**Usage:**
```bash
./analyze-hotspots.sh <config file> <binary directory>
```

**Example:**
```bash
./analyze-hotspots.sh ../tmp/picked.toml ../tmp/testbin/
```

**Functionality:**
1. Validates input parameters and file existence
2. Calls `generate-results.sh` to generate `results.md`
3. Calls `generate-points.sh` to generate `point.md`
4. Calls `optimize-results.sh` to optimize `results.md` format

### Helper Scripts

#### `generate-results.sh`
Generates the `results.md` file containing all test packages, test cases, and corresponding hotspot functions.

**Usage:**
```bash
./generate-results.sh <config file> <binary directory> <results file> <arch suffix>
```

**Functionality:**
- Parses TOML configuration file
- Finds matching binary files (format: `<package>_<arch suffix>`)
- Lists all matching benchmark test cases
- Runs each benchmark separately and collects CPU profile
- Uses `go tool pprof` to analyze hotspot functions
- Filters and records functions with `flat% > threshold`

**Configurable Parameters:**
- `FLAT_PCT_THRESHOLD`: Hotspot function threshold (default: 5.0), only counts functions with `flat%` greater than this value

#### `generate-points.sh`
Generates `point.md` from `results.md`, grouped by hotspot function.

**Usage:**
```bash
./generate-points.sh <results file> <point file>
```

**Functionality:**
- Reads `results.md` file
- Extracts all hotspot functions and their corresponding test cases and `flat%` values
- Sorts and groups output by function name

#### `optimize-results.sh`
Optimizes the `results.md` file format for better readability.

**Usage:**
```bash
./optimize-results.sh <results file>
```

**Functionality:**
- For adjacent rows with the same test package name or test case name, only keeps the first occurrence
- Leaves subsequent identical items empty, following Markdown table reading conventions

## Configuration File Format

The configuration file uses TOML format. Each benchmark configuration contains the following fields:

```toml
[[Benchmarks]]
  Name = "package_name"
  Benchmarks = "regular_expression"
  Disabled = false  # Optional, defaults to false
```

**Field Description:**
- `Name`: Test package name, used to build binary file name (format: `<Name>_<arch suffix>`)
- `Benchmarks`: Regular expression to match benchmark test cases in this package
- `Disabled`: Optional field, set to `true` to skip this configuration item

**Example:**
```toml
[[Benchmarks]]
  Name = "uber_zap"
  Benchmarks = "Benchmark"

[[Benchmarks]]
  Name = "wazero"
  Benchmarks = "BenchmarkInvocation/interpreter/fib_for_20"
```

## Output Files

### `results.md`
Contains all test packages, test cases, and corresponding hotspot function information.

**Format:**
```markdown
|测试包|测试用例|热点函数|
|------|--------|--------|
|uber_zap|BenchmarkStandardJSON-6|     0.84s 51.22% 51.22%      1.52s 92.68%  github.com/...|
|uber_zap|BenchmarkStandardJSON-6|     0.23s  5.46% 56.68%      0.25s  5.68%  runtime.allocm|
```

**Notes:**
- Test package names and test case names are optimized to empty when identical in adjacent rows (only first occurrence is kept)
- Hotspot function column contains complete `pprof top` output line information

### `point.md`
Grouped by hotspot function, lists all related test cases and their `flat%` values.

**Format:**
```markdown
|热点函数|热点值|
|--------|------|
|runtime.mallocgc|BenchmarkStandardJSON-6             51.22%|
||BenchmarkFastTest2KB             35.47%|
|go.uber.org/zap/zapcore.(*BufferedWriteSyncer).Write|BenchmarkStandardJSON-6             5.46%|
```

**Notes:**
- Multiple test cases for the same function use empty cells for the function name
- Hotspot value format: `<test case name>             <flat%>%`

## Configurable Parameters

### `analyze-hotspots.sh`
- `ARCH_SUFFIX`: Architecture suffix for binary files (default: `"Amd64-Static"`)

### `generate-results.sh`
- `FLAT_PCT_THRESHOLD`: Hotspot function threshold (default: `5.0`), only counts functions with `flat%` greater than this value

## Usage Examples

### Basic Usage

```bash
# Execute in tools directory
cd tools
./analyze-hotspots.sh ../tmp/picked.toml ../tmp/testbin/
```

### Modify Architecture Suffix

Edit `analyze-hotspots.sh`, modify the `ARCH_SUFFIX` variable:
```bash
ARCH_SUFFIX="RISC-V-Static"  # or other architecture suffix
```

### Modify Hotspot Threshold

Edit `generate-results.sh`, modify the `FLAT_PCT_THRESHOLD` variable:
```bash
FLAT_PCT_THRESHOLD=10.0  # only count functions with flat% > 10%
```

## How It Works

1. **Parse Configuration**: Uses `awk` to parse TOML configuration file and extract all enabled benchmark configurations
2. **Find Binary Files**: Builds binary file paths based on `Name` in configuration and `ARCH_SUFFIX`
3. **List Test Cases**: Runs benchmark once (without profile collection) to get list of all matching test cases
4. **Run Tests Separately**: Runs each test case separately using `-test.cpuprofile` to collect CPU profile
5. **Analyze Hotspots**: Uses `go tool pprof` `top 30` command to analyze profile and extract functions with `flat% > threshold`
6. **Generate Reports**: Aggregates all results into `results.md`, then generates `point.md` and optimized `results.md`

## Notes

1. **Binary File Format**: Binary files must be named in `<package>_<arch suffix>` format and must be executable
2. **Go Toolchain**: Requires Go toolchain installation, ensure `go tool pprof` command is available
3. **Profile Files**: Each run overwrites the `cpu.out` profile file, but only after results are recorded
4. **Benchmark Names**: Preserves complete benchmark names, including iteration count suffix (e.g., `-6`)
5. **Regular Expressions**: The `Benchmarks` field supports regular expressions and can match multiple test cases
6. **Execution Time**: Each benchmark runs separately, large test sets may require significant time

## Troubleshooting

### Issue: `results.md` is empty or only contains header

**Possible Causes:**
- No matching benchmark test cases found
- All test cases have `flat%` less than threshold
- Profile file generation failed

**Solutions:**
- Check if regular expressions in configuration file are correct
- Check if binary files exist and are executable
- Try lowering the `FLAT_PCT_THRESHOLD` threshold
- Check if benchmark execution succeeded

### Issue: Some benchmark results don't match manual tests

**Possible Causes:**
- Benchmark runtime too short, insufficient profile data
- Test environment differences

**Solutions:**
- Can add `-test.benchtime` parameter in `generate-results.sh` to extend runtime
- Ensure test environment consistency

### Issue: Script execution permission error

**Solution:**
```bash
chmod +x *.sh
```
