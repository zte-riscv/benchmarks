#!/bin/bash

# 脚本用于生成benchmark测试文件并上传制作镜像
# 用法: ./build_upload.sh [架构] <镜像标识>
# 例如: ./build_upload.sh test001              # 一个参数：镜像标识，架构默认为riscv64
#       ./build_upload.sh riscv64 test001        # 两个参数：架构riscv64，镜像标识test001
#       ./build_upload.sh arm64 test001        # 两个参数：架构arm64，镜像标识test001

set -e  # 遇到错误立即退出

# 解析参数
if [ -z "$1" ]; then
    echo "错误: 请提供参数"
    echo "用法: $0 [架构] <镜像标识>"
    echo "  一个参数: $0 <镜像标识>              # 架构默认为riscv64"
    echo "  两个参数: $0 <架构> <镜像标识>        # 架构不含arm字样则为riscv64，否则为arm64"
    echo "例如:"
    echo "  $0 test001"
    echo "  $0 riscv64 test001"
    echo "  $0 arm64 test001"
    exit 1
fi

# 判断参数数量
if [ -z "$2" ]; then
    # 一个参数：镜像标识，架构默认为riscv64
    ARCH_PARAM="riscv64"
    IMAGE_TAG="$1"
else
    # 两个参数：第一个是架构，第二个是镜像标识
    ARCH_PARAM="$1"
    IMAGE_TAG="$2"
fi

# 判断架构：不含arm字样则是riscv64，否则是arm64
if [[ "$ARCH_PARAM" == *"arm"* ]]; then
    ARCH="arm64"
    BUILD_ARCH_PARAM="arm64"  # 传递给build_normal_bent.sh的参数（包含arm即可）
else
    ARCH="riscv64"
    BUILD_ARCH_PARAM=""  # 传递给build_normal_bent.sh的参数（空或不包含arm即可）
fi

echo "=========================================="
echo "开始执行构建和上传流程"
echo "架构: $ARCH"
echo "镜像标识: $IMAGE_TAG"
echo "=========================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 第一步：生成benchmark测试文件
echo "=== 第一步: 生成benchmark测试文件 ==="
if [ -n "$BUILD_ARCH_PARAM" ]; then
    echo "执行: script/build_normal_bent.sh $BUILD_ARCH_PARAM"
    "$SCRIPT_DIR/script/build_normal_bent.sh" "$BUILD_ARCH_PARAM"
else
    echo "执行: script/build_normal_bent.sh"
    "$SCRIPT_DIR/script/build_normal_bent.sh"
fi

if [ $? -ne 0 ]; then
    echo "✗ benchmark测试文件生成失败"
    exit 1
fi

echo ""
echo "✓ benchmark测试文件生成成功"
echo ""

# 第二步：上传并制作镜像
echo "=== 第二步: 上传并制作镜像 ==="

# 根据参数数量调用deploy_image.sh
if [ -z "$2" ]; then
    # 一个参数：只传递镜像标识
    echo "执行: script/deploy_image.sh $IMAGE_TAG"
    "$SCRIPT_DIR/script/deploy_image.sh" "$IMAGE_TAG"
else
    # 两个参数：传递架构和镜像标识
    echo "执行: script/deploy_image.sh $ARCH_PARAM $IMAGE_TAG"
    "$SCRIPT_DIR/script/deploy_image.sh" "$ARCH_PARAM" "$IMAGE_TAG"
fi

if [ $? -ne 0 ]; then
    echo "✗ 镜像上传和制作失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ 构建和上传流程全部完成"
echo "=========================================="
echo ""
