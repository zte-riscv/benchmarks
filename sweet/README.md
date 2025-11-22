# Sweet Benchmarks for RISC-V Cross-Compilation

## Overview

This repository provides a cross-compilation workflow for running Sweet benchmarks on RISC-V targets. The workflow allows you to compile benchmarks on x86 machines and run them on RISC-V machines without requiring network access.

## How It Works

Normally, Sweet requires:
1. Running `sweet get` to download asset files from the network
2. Running `sweet run` to compile and execute benchmarks
3. Benchmarks reading asset files during execution

This repository pre-packages:
- **Asset files** in `prebuilt_assets/` directory
- **Pre-compiled RISC-V binaries** in `prebuilt_bin/riscv64/` directory

This allows you to copy the repository to a RISC-V machine and run benchmarks directly without network access.

## Usage

### Running Benchmarks

On the RISC-V machine, from the `sweet` directory:

```bash
bash run_riscv64.bash
```

Results will be generated in the `results/` directory.

### Recompiling for New Go Toolchain

To test a new Go toolchain:

1. Update the `GOROOT` path in `config_riscv64.toml`
2. Run the compilation script:

```bash
bash compile_riscv64.bash
```

The `--compile-only` flag compiles binaries without running tests, and `--compile-outdir` specifies where to save the compiled RISC-V binaries (default: `prebuilt_bin/`).

## Supported Benchmarks

The following benchmarks work well for RISC-V testing:
- `markdown`
- `gopher-lua`
- `biogo-krishna`
- `biogo-igor`

### Unsupported Benchmarks

- `etcd`, `esbuild`: Fail during cross-compilation
- `go-build`: Takes too long to execute
- `bleve-index`, `tile38`: Asset files are too large

## Adding New Benchmarks

To add a new benchmark suite:

1. **Copy asset files** to `prebuilt_assets/` directory
2. **Update scripts**:
   - Add the benchmark to `compile_riscv64.bash`
   - Add the benchmark to `run_riscv64.bash`
3. **Compile**:
   ```bash
   bash compile_riscv64.bash
   ```
   This will save the compiled binary to `prebuilt_bin/` directory.
