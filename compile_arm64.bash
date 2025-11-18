#!/bin/bash
set -e

export GOOS=linux
export GOARCH=arm64
export CGO_ENABLED=0

# 创建输出目录（从命令行参数获取，如果没有则使用默认值）
OUTDIR="${1:-go_benchmarks_arm64}"
mkdir -p "$OUTDIR"
echo "Created output directory: $OUTDIR"

# JSON
echo "Building JSON benchmark..."
cd json
if go build -ldflags="-s -w" -o "../$OUTDIR/json-arm64"; then
    echo "✓ JSON benchmark compiled successfully"
else
    echo "✗ JSON benchmark compilation failed"
    exit 1
fi
cd ..

# Garbage
echo "Building Garbage benchmark..."
cd garbage
if go build -ldflags="-s -w" -o "../$OUTDIR/garbage-arm64"; then
    echo "✓ Garbage benchmark compiled successfully"
else
    echo "✗ Garbage benchmark compilation failed"
    exit 1
fi
cd ..

# GC Latency
echo "Building GC Latency benchmark..."
cd gc_latency
if go build -ldflags="-s -w" -o "../$OUTDIR/gc_latency-arm64"; then
    echo "✓ GC Latency benchmark compiled successfully"
else
    echo "✗ GC Latency benchmark compilation failed"
    exit 1
fi
cd ..

echo ""
echo "All benchmarks compiled successfully!"
echo "Output directory: $OUTDIR/"
echo "Binaries:"
ls -lh "$OUTDIR"/

# 复制运行脚本到输出目录
SCRIPT_NAME="run_arm64.bash"
if [ -f "$SCRIPT_NAME" ]; then
    echo ""
    echo "Copying $SCRIPT_NAME to $OUTDIR/..."
    if cp "$SCRIPT_NAME" "$OUTDIR/"; then
        chmod +x "$OUTDIR/$SCRIPT_NAME"
        echo "✓ $SCRIPT_NAME copied successfully"
    else
        echo "✗ Failed to copy $SCRIPT_NAME"
        exit 1
    fi
else
    echo "⚠ Warning: $SCRIPT_NAME not found, skipping copy"
fi

# 打包压缩
ARCHIVE="${OUTDIR}.tar.gz"
echo ""
echo "Creating archive: $ARCHIVE..."
if tar -czf "$ARCHIVE" "$OUTDIR"; then
    echo "✓ Archive created successfully: $ARCHIVE"
    echo "Archive size:"
    ls -lh "$ARCHIVE"
else
    echo "✗ Archive creation failed"
    exit 1
fi

echo ""
echo "Done! You can find the binaries in $OUTDIR/ and the archive at $ARCHIVE"

