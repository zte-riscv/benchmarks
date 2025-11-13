# Benchmark Scripts Usage Guide

This guide explains how to use the benchmark compilation, execution, and analysis scripts for cross-compiling and running Go benchmarks on RISC-V targets.

## Overview

The benchmark suite consists of four main scripts:

1. **`compile.bash`** - Cross-compiles benchmark binaries for RISC-V
2. **`run.bash`** - Executes benchmarks and collects results
3. **`stats.bash`** - Compares benchmark results using `benchstat`
4. **`convert_gc_latency.sh`** - Converts `gc_latency` output to `benchstat` format

## Workflow

The typical workflow is:

```
1. Compile benchmarks (on x86) → 2. Run benchmarks (on RISC-V) → 3. Analyze results
```

---

## 1. Compiling Benchmarks (`compile.bash`)

### Purpose

Cross-compiles Go benchmark programs for RISC-V architecture. The script compiles three benchmarks:
- `json` - JSON encoding/decoding benchmarks
- `garbage` - Garbage collection benchmarks
- `gc_latency` - GC latency measurement benchmarks

### Prerequisites

- Go toolchain installed
- Cross-compilation environment variables will be set automatically

### Usage

```bash
./compile.bash [output_directory]
```

**Parameters:**
- `output_directory` (optional): Directory to store compiled binaries (default: `go_benchmarks`)

**Example:**
```bash
./compile.bash go_benchmarks
```

### What It Does

1. Sets cross-compilation environment variables:
   - `GOOS=linux`
   - `GOARCH=riscv64`
   - `GORISCV64=rva23u64`
   - `CGO_ENABLED=0`

2. Compiles each benchmark with optimization flags (`-ldflags="-s -w"`)

3. Creates output directory and copies binaries:
   - `json-riscv64`
   - `garbage-riscv64`
   - `gc_latency-riscv64`

4. Copies `run.bash` script to output directory

5. Creates a compressed archive (`output_directory.tar.gz`)

### Output

```
go_benchmarks/
├── json-riscv64
├── garbage-riscv64
├── gc_latency-riscv64
└── run.bash
```

---

## 2. Running Benchmarks (`run.bash`)

### Purpose

Executes the compiled benchmark binaries and collects results. Output is displayed on screen and saved to result files simultaneously.

### Usage

```bash
./run.bash [benchmark_dir] [results_dir] [benchnum] [benchtime]
```

**Parameters:**
- `benchmark_dir` (optional): Directory containing benchmark binaries (default: `go_benchmarks`)
- `results_dir` (optional): Directory to save results (default: `results`)
- `benchnum` (optional): Number of benchmark runs (default: `10`)
- `benchtime` (optional): Duration per run (default: `5s`)

**Examples:**
```bash
# Use all defaults
./run.bash

# Specify custom directories and parameters
./run.bash go_benchmarks my_results 20 10s
```

### What It Does

1. Checks for benchmark binaries in the specified directory

2. Runs each benchmark:
   - **JSON**: Runs with `-benchnum` and `-benchtime` parameters
   - **Garbage**: Runs with `-benchnum` and `-benchtime` parameters
   - **GC Latency**: Runs without parameters (does not support `-benchnum`/`-benchtime`)

3. Uses `tee` to display output on screen while saving to files

4. Creates result files:
   - `json-results.txt`
   - `garbage-results.txt`
   - `gc_latency-results.txt`

5. Moves results directory to parent directory (overwrites if exists)

### Output

Results are saved in the `results/` directory (moved to parent directory after completion):

```
results/
├── json-results.txt
├── garbage-results.txt
└── gc_latency-results.txt
```

### Notes

- **GC Latency**: This benchmark does not use the standard driver package and only supports its own parameters (`-how`, `-fluff`, `-trace`). The script runs it without `-benchnum` and `-benchtime`.
- All output is displayed in real-time using `tee` for monitoring progress.

---

## 3. Analyzing Results (`stats.bash`)

### Purpose

Compares benchmark results using `benchstat` to analyze performance differences between baseline and experimental runs.

### Prerequisites

Install `benchstat`:
```bash
go install golang.org/x/perf/cmd/benchstat@latest
```

Or ensure `benchstat` is in your PATH or specify the path as the third argument.

### Usage

#### Compare Two Directories Explicitly

```bash
./stats.bash <baseline_dir> <new_dir> [benchstat_path]
```

**Example:**
```bash
./stats.bash results-go1.21 results-go1.22
./stats.bash results-go1.21 results-go1.22 ./benchstat
```

#### Auto-detect Mode (Single Directory)

```bash
./stats.bash [results_dir]
```

If no directory is specified, defaults to `results/`.

**Example:**
```bash
./stats.bash results
```

### What It Does

1. **Explicit Comparison Mode** (two directories):
   - Compares matching result files from both directories
   - Automatically converts `gc_latency` results if needed
   - Uses `benchstat` to generate comparison statistics

2. **Auto-detect Mode** (single directory):
   - Finds all `*-results.txt` files
   - Groups by benchmark name
   - Attempts smart pairing for comparison:
     - Single file: Shows summary statistics
     - Two files: Compares them directly
     - Multiple files: Attempts to pair baseline/experiment files

3. **Cross-directory Comparison**:
   - If version directories are found (e.g., `results-go1.21/`, `results-go1.22/`), compares across directories

4. **GC Latency Handling**:
   - Automatically converts `gc_latency` output using `convert_gc_latency.sh` before comparison

### Output

The script outputs:
- Comparison statistics for each benchmark
- Performance deltas (improvements/regressions)
- Statistical significance indicators

**Example output:**
```
=== json ===
  Baseline: json-results.txt
  New:      json-results.txt

  Comparison results:
  ──────────────────────────────────────────────────────────
  name        old time/op    new time/op    delta
  BenchmarkJSON-4    1.23ms ± 2%    1.20ms ± 1%  -2.44% (p=0.000)
  ──────────────────────────────────────────────────────────
```

---

## 4. Converting GC Latency Results (`convert_gc_latency.sh`)

### Purpose

Converts `gc_latency` benchmark output (non-standard format) to the standard Go benchmark format that `benchstat` can understand.

### Usage

```bash
./convert_gc_latency.sh <input_file> [output_file]
```

**Parameters:**
- `input_file`: Path to `gc_latency-results.txt`
- `output_file` (optional): Output file path (default: stdout)

**Examples:**
```bash
# Output to stdout
./convert_gc_latency.sh gc_latency-results.txt

# Save to file
./convert_gc_latency.sh gc_latency-results.txt gc_latency-converted.txt
```

### What It Does

1. Parses `gc_latency` output to extract:
   - Configuration (`how`, `fluff`)
   - Latency metrics (average, median, percentiles, worst)

2. Converts time units to nanoseconds:
   - Supports: `ns`, `µs` (or `us`), `ms`, `s`

3. Generates standard Go benchmark format:
   ```
   pkg: golang.org/x/benchmarks
   goos: linux
   goarch: riscv64
   BenchmarkGCLatency/how=stack-20    1    4233 avg-latency-ns/op
   BenchmarkGCLatency/how=stack-20    1    1980 median-latency-ns/op
   ...
   ```

### When to Use

This script is automatically called by `stats.bash` when comparing `gc_latency` results. You typically don't need to run it manually unless you want to inspect the converted format.

---

## Complete Example Workflow

### Step 1: Compile on x86 Machine

```bash
# Cross-compile benchmarks for RISC-V
./compile.bash go_benchmarks

# Transfer to RISC-V machine
scp go_benchmarks.tar.gz riscv-machine:/path/to/benchmarks/
```

### Step 2: Run on RISC-V Machine

```bash
# Extract archive
tar -xzf go_benchmarks.tar.gz
cd go_benchmarks

# Run benchmarks
./run.bash go_benchmarks results 10 5s
```

### Step 3: Analyze Results

```bash
# Compare two runs
./stats.bash results-baseline results-experiment

# Or analyze single directory
./stats.bash results
```

---

## Tips

1. **Compilation**: Run `compile.bash` on an x86 machine with Go toolchain installed. The output can be transferred to RISC-V machines.

2. **Execution**: Run `run.bash` on the target RISC-V machine. Ensure binaries are executable (`chmod +x`).

3. **Analysis**: Use `stats.bash` to compare results. For meaningful comparisons, ensure both runs use the same parameters.

4. **GC Latency**: Remember that `gc_latency` has different parameters and output format. The conversion script handles this automatically.

5. **Result Management**: Results are automatically moved to the parent directory after execution. Keep organized by using descriptive directory names (e.g., `results-go1.21`, `results-go1.22`).

---

