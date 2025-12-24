#!/bin/bash

# 脚本用于上传二进制文件、制作镜像并上传到FTP服务器
# 用法: ./deploy_image.sh [架构] <镜像标识>
# 例如: ./deploy_image.sh test001              # 一个参数：镜像标识，架构默认为riscv
#       ./deploy_image.sh riscv test001        # 两个参数：架构riscv，镜像标识test001
#       ./deploy_image.sh arm64 test001        # 两个参数：架构arm64，镜像标识test001

set -e  # 遇到错误立即退出

# 解析参数
if [ -z "$1" ]; then
    echo "错误: 请提供参数"
    echo "用法: $0 [架构] <镜像标识>"
    echo "  一个参数: $0 <镜像标识>              # 架构默认为riscv"
    echo "  两个参数: $0 <架构> <镜像标识>        # 架构不含arm字样则为riscv，否则为arm"
    echo "例如:"
    echo "  $0 test001"
    echo "  $0 riscv test001"
    echo "  $0 arm64 test001"
    exit 1
fi

# 判断参数数量
if [ -z "$2" ]; then
    # 一个参数：镜像标识，架构默认为riscv
    ARCH="riscv"
    IMAGE_TAG="$1"
else
    # 两个参数：第一个是架构，第二个是镜像标识
    ARCH_PARAM="$1"
    IMAGE_TAG="$2"
    
    # 判断架构：不含arm字样则是riscv，否则是arm
    if [[ "$ARCH_PARAM" == *"arm"* ]]; then
        ARCH="arm"
    else
        ARCH="riscv"
    fi
fi

echo "架构: $ARCH"
echo "镜像标识: $IMAGE_TAG"

# 获取当前月日（MMDD格式）
DATE_TAG=$(date +%m%d)
echo "日期标签: $DATE_TAG"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    echo "请复制 config.sh.example 为 config.sh 并填写实际的服务器信息"
    exit 1
fi

# 读取配置文件
source "$CONFIG_FILE"

# 检查必需的配置项
if [ -z "$IMAGE_SERVER" ] || [ -z "$IMAGE_USER" ] || [ -z "$IMAGE_PASS" ]; then
    echo "错误: 配置文件中的镜像制作服务器信息不完整"
    echo "请检查 $CONFIG_FILE 文件"
    exit 1
fi

if [ -z "$FTP_SERVER" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ]; then
    echo "错误: 配置文件中的FTP服务器信息不完整"
    echo "请检查 $CONFIG_FILE 文件"
    exit 1
fi

# 本地目录
GO_BENCHMARKS_DIR="$SCRIPT_DIR/go_benchmarks"
BENT_TESTBIN_DIR="$SCRIPT_DIR/bent/testbin"
IMAGE_DIR="$SCRIPT_DIR/image"

# 检查本地目录是否存在
if [ ! -d "$GO_BENCHMARKS_DIR" ]; then
    echo "错误: 目录不存在 $GO_BENCHMARKS_DIR"
    echo "请先运行 build_benchmarks.sh 生成二进制文件"
    exit 1
fi

if [ ! -d "$BENT_TESTBIN_DIR" ]; then
    echo "错误: 目录不存在 $BENT_TESTBIN_DIR"
    echo "请先运行 build_benchmarks.sh 生成二进制文件"
    exit 1
fi

# 创建本地镜像目录
mkdir -p "$IMAGE_DIR"

# 检查是否安装了sshpass（用于非交互式SSH密码认证）
if ! command -v sshpass &> /dev/null; then
    echo "警告: 未找到 sshpass 命令，将尝试使用SSH密钥认证"
    echo "如果SSH密钥未配置，请安装 sshpass:"
    echo "  Ubuntu/Debian: sudo apt-get install sshpass"
    echo "  CentOS/RHEL: sudo yum install sshpass"
    USE_SSHPASS=false
else
    USE_SSHPASS=true
fi

echo "=== 第一步: 检查并等待镜像制作锁 ==="

# 锁配置
LOCK_DIR="/tmp/make_image.lock"
LOCK_INFO_FILE="${LOCK_DIR}/lock_info.txt"
MAX_WAIT_TIME=600  # 最大等待时间：10分钟（600秒）
CHECK_INTERVAL=5   # 检查间隔：5秒

# 检查锁状态的函数
check_lock_status() {
    local lock_exists=false
    local lock_valid=false
    
    # 检查锁目录是否存在
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "test -d $LOCK_DIR" 2>/dev/null && lock_exists=true || lock_exists=false
    else
        ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "test -d $LOCK_DIR" 2>/dev/null && lock_exists=true || lock_exists=false
    fi
    
    if [ "$lock_exists" = false ]; then
        return 1  # 锁不存在，可以执行
    fi
    
    # 锁存在，检查锁对应的进程是否还在运行
    local lock_pid=""
    if [ "$USE_SSHPASS" = true ]; then
        lock_pid=$(sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "grep '进程ID:' $LOCK_INFO_FILE 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "")
    else
        lock_pid=$(ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "grep '进程ID:' $LOCK_INFO_FILE 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "")
    fi
    
    if [ -n "$lock_pid" ]; then
        # 检查进程是否存在
        if [ "$USE_SSHPASS" = true ]; then
            sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "kill -0 $lock_pid 2>/dev/null" && lock_valid=true || lock_valid=false
        else
            ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "kill -0 $lock_pid 2>/dev/null" && lock_valid=true || lock_valid=false
        fi
    fi
    
    if [ "$lock_valid" = true ]; then
        return 0  # 锁有效，需要等待
    else
        return 1  # 锁无效（进程不存在），可以执行
    fi
}

# 获取锁信息
get_lock_info() {
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "cat $LOCK_INFO_FILE 2>/dev/null || echo '未知'"
    else
        ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "cat $LOCK_INFO_FILE 2>/dev/null || echo '未知'"
    fi
}

# 等待锁释放的函数
wait_for_lock() {
    local elapsed_time=0
    local start_time=$(date +%s)
    
    echo "检查镜像制作锁状态..."
    
    while [ $elapsed_time -lt $MAX_WAIT_TIME ]; do
        # 临时禁用set -e以检查锁状态
        set +e
        check_lock_status
        local lock_status=$?
        set -e
        
        if [ $lock_status -eq 1 ]; then
            # 锁不存在或无效，可以执行
            echo "✓ 锁已释放，可以执行镜像制作"
            return 0
        fi
        
        # 锁仍被占用，显示锁信息并等待
        if [ $elapsed_time -eq 0 ]; then
            echo "锁正在被使用，等待释放..."
            echo "当前锁信息:"
            echo "----------------------------------------"
            get_lock_info
            echo "----------------------------------------"
        fi
        
        # 计算剩余时间
        local remaining_time=$((MAX_WAIT_TIME - elapsed_time))
        local remaining_min=$((remaining_time / 60))
        local remaining_sec=$((remaining_time % 60))
        
        echo "等待中... (剩余时间: ${remaining_min}分${remaining_sec}秒)"
        
        # 等待检查间隔
        sleep $CHECK_INTERVAL
        
        # 更新已等待时间
        local current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
    done
    
    # 超时
    echo ""
    echo "✗ 错误: 等待锁超时（超过 $((MAX_WAIT_TIME / 60)) 分钟）"
    echo "当前锁信息:"
    echo "----------------------------------------"
    get_lock_info
    echo "----------------------------------------"
    echo "请等待当前任务完成后再试，或联系管理员检查。"
    return 1
}

# 等待锁释放
if ! wait_for_lock; then
    exit 1
fi

echo ""
echo "=== 第二步: 上传二进制文件到镜像制作服务器 ==="
echo "（已获取锁，可以安全上传文件）"

# 上传go_benchmarks目录
echo "上传 go_benchmarks 目录..."
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" scp -o StrictHostKeyChecking=no -r "$GO_BENCHMARKS_DIR"/* "$IMAGE_USER@$IMAGE_SERVER:/root/ctk/zf_go_test/normal/go_benchmarks/"
else
    scp -o StrictHostKeyChecking=no -r "$GO_BENCHMARKS_DIR"/* "$IMAGE_USER@$IMAGE_SERVER:/root/ctk/zf_go_test/normal/go_benchmarks/"
fi
if [ $? -eq 0 ]; then
    echo "✓ go_benchmarks 上传成功"
else
    echo "✗ go_benchmarks 上传失败"
    exit 1
fi

# 上传bent/testbin目录
echo "上传 bent/testbin 目录..."
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" scp -o StrictHostKeyChecking=no -r "$BENT_TESTBIN_DIR"/* "$IMAGE_USER@$IMAGE_SERVER:/root/ctk/zf_go_test/bent/testbin/"
else
    scp -o StrictHostKeyChecking=no -r "$BENT_TESTBIN_DIR"/* "$IMAGE_USER@$IMAGE_SERVER:/root/ctk/zf_go_test/bent/testbin/"
fi
if [ $? -eq 0 ]; then
    echo "✓ bent/testbin 上传成功"
else
    echo "✗ bent/testbin 上传失败"
    exit 1
fi

echo ""
echo "=== 第三步: 在镜像制作服务器上运行镜像制作脚本 ==="

# 在远程服务器上执行make.sh脚本（make.sh使用方式：./make.sh 架构 镜像标识）
echo "执行远程命令: cd $IMAGE_SERVER_PATH && ./make.sh $ARCH $IMAGE_TAG"
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "cd $IMAGE_SERVER_PATH && ./make.sh $ARCH $IMAGE_TAG"
else
    ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "cd $IMAGE_SERVER_PATH && ./make.sh $ARCH $IMAGE_TAG"
fi

if [ $? -ne 0 ]; then
    echo "✗ 镜像制作脚本执行失败"
    exit 1
fi

echo "✓ 镜像制作脚本执行完成"

# 检查镜像文件是否存在（根据架构生成文件名，使用当前月日）
IMAGE_FILE="Image_${ARCH}_${DATE_TAG}_${IMAGE_TAG}.txt"
REMOTE_IMAGE_FILE="$IMAGE_SERVER_PATH/$IMAGE_FILE"

echo "检查镜像文件是否存在: $REMOTE_IMAGE_FILE"

# 先列出目录中的文件，帮助调试
echo "列出 $IMAGE_SERVER_PATH 目录中的镜像文件:"
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "ls -la $IMAGE_SERVER_PATH/Image_*.txt 2>/dev/null || echo '未找到匹配的镜像文件'" || true
else
    ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "ls -la $IMAGE_SERVER_PATH/Image_*.txt 2>/dev/null || echo '未找到匹配的镜像文件'" || true
fi

# 检查文件是否存在（临时禁用set -e以避免test命令失败导致脚本退出）
set +e
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "test -f $REMOTE_IMAGE_FILE"
    CHECK_RESULT=$?
else
    ssh -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER" "test -f $REMOTE_IMAGE_FILE"
    CHECK_RESULT=$?
fi
set -e

if [ $CHECK_RESULT -eq 0 ]; then
    echo "✓ 镜像文件已生成: $IMAGE_FILE"
else
    echo "✗ 镜像文件不存在: $REMOTE_IMAGE_FILE"
    echo "请检查服务器上的文件路径和文件名是否正确"
    exit 1
fi

echo ""
echo "=== 第四步: 下载镜像文件到本地 ==="

LOCAL_IMAGE_FILE="$IMAGE_DIR/$IMAGE_FILE"

echo "下载镜像文件: $REMOTE_IMAGE_FILE -> $LOCAL_IMAGE_FILE"
if [ "$USE_SSHPASS" = true ]; then
    sshpass -p "$IMAGE_PASS" scp -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER:$REMOTE_IMAGE_FILE" "$LOCAL_IMAGE_FILE"
else
    scp -o StrictHostKeyChecking=no "$IMAGE_USER@$IMAGE_SERVER:$REMOTE_IMAGE_FILE" "$LOCAL_IMAGE_FILE"
fi

if [ $? -eq 0 ]; then
    echo "✓ 镜像文件下载成功: $LOCAL_IMAGE_FILE"
else
    echo "✗ 镜像文件下载失败"
    exit 1
fi

echo ""
echo "=== 第五步: 上传镜像文件到FTP服务器 ==="

# 检查是否安装了lftp（更好的FTP客户端）
if command -v lftp &> /dev/null; then
    echo "使用 lftp 上传文件..."
    lftp -u "$FTP_USER,$FTP_PASS" "$FTP_SERVER" <<EOF
cd $FTP_REMOTE_DIR
put $LOCAL_IMAGE_FILE
bye
EOF
    if [ $? -eq 0 ]; then
        echo "✓ 镜像文件上传到FTP服务器成功"
    else
        echo "✗ 镜像文件上传到FTP服务器失败"
        exit 1
    fi
elif command -v ftp &> /dev/null; then
    echo "使用 ftp 上传文件..."
    ftp -n "$FTP_SERVER" <<EOF
user $FTP_USER $FTP_PASS
binary
cd $FTP_REMOTE_DIR
put $LOCAL_IMAGE_FILE
quit
EOF
    if [ $? -eq 0 ]; then
        echo "✓ 镜像文件上传到FTP服务器成功"
    else
        echo "✗ 镜像文件上传到FTP服务器失败"
        exit 1
    fi
else
    echo "错误: 未找到 lftp 或 ftp 命令"
    echo "请安装其中一个FTP客户端:"
    echo "  Ubuntu/Debian: sudo apt-get install lftp"
    echo "  CentOS/RHEL: sudo yum install lftp"
    exit 1
fi

echo ""
echo "=== 完成 ==="
echo "镜像文件位置:"
echo "  本地: $LOCAL_IMAGE_FILE"
echo "  FTP服务器: $FTP_SERVER$FTP_REMOTE_DIR/$IMAGE_FILE"
echo ""

