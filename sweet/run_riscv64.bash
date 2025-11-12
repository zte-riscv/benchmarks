#!/bin/bash

# biogo-krishna
./prebuilt_bin/riscv64/sweet run -run biogo-krishna -assets-dir ./prebuilt_assets --prebuilt-binary-dir ./prebuilt_bin/riscv64/biogo-krishna/myconfig ./config_riscv64.toml

# biogo-igor
./prebuilt_bin/riscv64/sweet run -run biogo-igor -assets-dir ./prebuilt_assets --prebuilt-binary-dir ./prebuilt_bin/riscv64/biogo-igor/myconfig ./config_riscv64.toml