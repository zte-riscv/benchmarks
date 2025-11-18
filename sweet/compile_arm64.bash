#!/bin/bash

set -euo pipefail

go build ./cmd/sweet/

# markdown
./sweet run -run markdown \
    --assets-dir ./prebuilt_assets/ \
    --compile-only \
    --compile-outdir ./prebuilt_bin/arm64/ \
    ./config_arm64.toml

# gopher-lua
./sweet run -run gopher-lua \
    --assets-dir ./prebuilt_assets/ \
    --compile-only \
    --compile-outdir ./prebuilt_bin/arm64/ \
    ./config_arm64.toml

# biogo-krishna
./sweet run -run biogo-krishna \
    --assets-dir ./prebuilt_assets/ \
    --compile-only \
    --compile-outdir ./prebuilt_bin/arm64/ \
    ./config_arm64.toml

# biogo-igor
./sweet run -run biogo-igor \
    --assets-dir ./prebuilt_assets/ \
    --compile-only \
    --compile-outdir ./prebuilt_bin/arm64/ \
    ./config_arm64.toml

