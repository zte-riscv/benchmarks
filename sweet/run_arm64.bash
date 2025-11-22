#!/bin/bash

# markdown
./prebuilt_bin/arm64/sweet run \
    -run markdown \
    -assets-dir ./prebuilt_assets \
    --prebuilt-binary-dir ./prebuilt_bin/arm64/markdown/myconfig \
    ./config_arm64.toml

# gopher-lua
./prebuilt_bin/arm64/sweet run \
    -run gopher-lua \
    -assets-dir ./prebuilt_assets \
    --prebuilt-binary-dir ./prebuilt_bin/arm64/gopher-lua/myconfig \
    ./config_arm64.toml

# biogo-krishna
./prebuilt_bin/arm64/sweet run \
    -run biogo-krishna \
    -assets-dir ./prebuilt_assets \
    --prebuilt-binary-dir ./prebuilt_bin/arm64/biogo-krishna/myconfig \
    ./config_arm64.toml

# biogo-igor
./prebuilt_bin/arm64/sweet run \
    -run biogo-igor \
    -assets-dir ./prebuilt_assets \
    --prebuilt-binary-dir ./prebuilt_bin/arm64/biogo-igor/myconfig \
    ./config_arm64.toml

