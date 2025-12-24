# Benchmark 构建和部署脚本使用说明

本目录包含用于生成 Go benchmark 测试文件、制作镜像并上传到服务器的自动化脚本。

## 目录结构

```
benchmarks-master/
├── build_upload.sh                 # 总脚本：一键执行构建和上传流程
└── script/
    ├── README.md                   # 本文件
    ├── build_normal_bent.sh        # 生成 benchmark 测试文件脚本
    ├── deploy_image.sh              # 上传并制作镜像脚本
    ├── config.sh.example            # 服务器配置模板文件
    ├── config.sh                    # 服务器配置文件（需自行创建，包含敏感信息）
    └── configurations.toml         # bent 配置文件（需配置 Root 路径）
```

## 使用前的必备条件

### 1. 安装 bent 命令

bent 是用于自动化下载、编译和运行 Go 测试和基准测试的工具。

```bash
go install golang.org/x/benchmarks/cmd/bent@latest
```

安装完成后，确保 `bent` 命令在 PATH 中可用。可以通过以下命令验证：

```bash
bent -h
```

### 2. 安装 lftp 工具

lftp 用于将镜像文件上传到 FTP 服务器。

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install lftp
```

**CentOS/RHEL:**
```bash
sudo yum install lftp
```

**macOS:**
```bash
brew install lftp
```

### 3. 安装 sshpass（可选但推荐）

sshpass 用于非交互式 SSH 密码认证。如果未安装，脚本会尝试使用 SSH 密钥认证。

**Ubuntu/Debian:**
```bash
sudo apt-get install sshpass
```

**CentOS/RHEL:**
```bash
sudo yum install sshpass
```

**macOS:**
```bash
brew install hudochenkov/sshpass/sshpass
```

### 4. 配置服务器信息

**重要：** 使用前必须配置服务器连接信息。

复制配置文件模板并填写实际的服务器信息：

```bash
cd script
cp config.sh.example config.sh
```

编辑 `script/config.sh`，填写以下信息：

```bash
# 镜像制作服务器配置
IMAGE_SERVER="your-image-server-ip"      # 镜像制作服务器IP地址
IMAGE_USER="root"                         # 镜像制作服务器用户名
IMAGE_PASS="your-password"                # 镜像制作服务器密码
IMAGE_SERVER_PATH="/root/ctk"             # 镜像制作服务器工作路径

# FTP服务器配置
FTP_SERVER="your-ftp-server-ip"           # FTP服务器IP地址
FTP_USER="your-ftp-username"                # FTP服务器用户名
FTP_PASS="your-ftp-password"               # FTP服务器密码
FTP_REMOTE_DIR="/ctk"                     # FTP服务器远程目录
```

**注意：** `config.sh` 文件包含敏感信息，已被添加到 `.gitignore` 中，不会被提交到版本控制系统。

### 5. 配置 configurations.toml

**重要：** 使用前必须修改 `script/configurations.toml` 文件中的 `Root` 配置项，指向用于编译的 GOROOT 路径。

编辑 `script/configurations.toml`：

```toml
[[Configurations]]
  Name = "RISC-V-Static"
  Root = "$HOME/YOUR/GOROOT/PATH"  # 修改为实际的 GOROOT 路径
  GcEnv = [
    "GOOS=linux",
    "GOARCH=riscv64",
    "CGO_ENABLED=0"
  ]
```

将 `Root = "$HOME/YOUR/GOROOT/PATH"` 修改为实际的 GOROOT 路径，例如：
- `Root = "/usr/local/go"`
- `Root = "$HOME/go/go1.22"`
- `Root = "/opt/go/riscv64"`

**注意：** 路径可以使用环境变量（如 `$HOME`），脚本会自动展开。

### 6. 确保 Go 环境已配置

确保已安装 Go 并正确配置环境变量。脚本需要 Go 1.22 或更高版本。

## 使用方式

### 方式一：使用总脚本（推荐）

在项目根目录下使用 `build_upload.sh`，该脚本会自动执行构建和上传的完整流程。

#### 参数说明

脚本支持两种参数模式：

**1. 一个参数（架构默认为 riscv64）**
```bash
./build_upload.sh <镜像标识>
```

示例：
```bash
./build_upload.sh test001
# 架构默认为 riscv64，镜像标识为 test001
```

**2. 两个参数（指定架构和镜像标识）**
```bash
./build_upload.sh <架构> <镜像标识>
```

示例：
```bash
./build_upload.sh riscv64 test001
# 架构为 riscv64，镜像标识为 test001

./build_upload.sh arm64 test001
# 架构为 arm64，镜像标识为 test001
```

**架构判断规则：**
- 如果架构参数包含 "arm" 字样（如 `arm64`、`arm`），则使用 arm64 架构
- 否则，使用 riscv64 架构（默认）

#### 执行内容

1. 生成 benchmark 测试文件（编译 `garbage`、`gc_latency`、`json` 和 bent 测试二进制文件）
2. 上传并制作镜像（检查锁、上传文件、执行镜像制作、下载镜像、上传到 FTP）

### 方式二：单独使用脚本

如果需要分步执行，可以单独使用各个脚本。

#### 1. 生成 benchmark 测试文件

```bash
cd script
./build_normal_bent.sh [架构]
```

**参数说明：**
- 无参数：生成 riscv64 架构文件（默认）
- 参数包含 "arm"：生成 arm64 架构文件
- 参数不包含 "arm"：生成 riscv64 架构文件

**示例：**
```bash
# 生成 riscv64 架构文件
./build_normal_bent.sh

# 或
./build_normal_bent.sh riscv64

# 生成 arm64 架构文件
./build_normal_bent.sh arm64
```

**生成的文件：**
- `script/go_benchmarks/` - benchmark 二进制文件
- `script/bent/testbin/` - bent 测试二进制文件

#### 2. 上传并制作镜像

```bash
cd script
./deploy_image.sh [架构] <镜像标识>
```

**参数说明：**

**一个参数模式：**
```bash
./deploy_image.sh <镜像标识>
```
- 架构默认为 riscv
- 镜像标识用于生成镜像文件名

**两个参数模式：**
```bash
./deploy_image.sh <架构> <镜像标识>
```
- 架构参数：如果包含 "arm" 字样则为 arm，否则为 riscv
- 镜像标识：用于生成镜像文件名

**示例：**
```bash
# 一个参数：架构默认为 riscv
./deploy_image.sh test001

# 两个参数：指定架构
./deploy_image.sh riscv test001
./deploy_image.sh arm64 test001
```

## 输出目录说明

脚本执行后会在 `script/` 目录下创建以下目录：

- `script/go_benchmarks/` - benchmark 二进制文件
- `script/bent/` - bent 工作目录
  - `script/bent/testbin/` - bent 生成的测试二进制文件
- `script/image/` - 下载的镜像文件

## 镜像文件命名规则

生成的镜像文件命名格式为：
```
Image_<架构>_<月日>_<镜像标识>.txt
```

例如：
- `Image_riscv_1223_test001.txt` - riscv 架构，12月23日，镜像标识 test001
- `Image_arm_1223_test001.txt` - arm 架构，12月23日，镜像标识 test001

其中 `<月日>` 为运行脚本时的当前日期（MMDD 格式）。

## 镜像制作锁机制

`deploy_image.sh` 脚本实现了镜像制作锁机制，确保同一时间只有一个任务在制作镜像：

- **锁检查**：在开始上传文件前，会检查镜像制作锁状态
- **等待机制**：如果锁被占用，每 5 秒检查一次，最多等待 10 分钟
- **超时处理**：如果 10 分钟内锁未释放，脚本会退出并显示错误信息
- **安全上传**：只有在确认锁已释放后，才会上传文件，避免干扰正在进行的镜像制作

## 故障排查

### 1. bent 命令未找到

**错误信息：** `command not found: bent`

**解决方法：**
```bash
go install golang.org/x/benchmarks/cmd/bent@latest
```

确保 `$GOPATH/bin` 或 `$GOBIN` 在 PATH 中。

### 2. lftp 未安装

**错误信息：** `未找到 lftp 或 ftp 命令`

**解决方法：** 按照前置要求中的说明安装 lftp。

### 3. SSH 连接失败

**错误信息：** SSH 连接超时或认证失败

**解决方法：**
- 检查网络连接
- 确认服务器地址和凭据正确
- 如果使用 SSH 密钥，确保密钥已正确配置
- 或者安装 sshpass 以使用密码认证

### 4. 镜像制作锁超时

**错误信息：** `等待锁超时（超过 10 分钟）`

**解决方法：**
- 等待当前正在执行的镜像制作任务完成
- 检查服务器上的锁状态：`/tmp/make_image.lock`
- 如果确认没有任务在运行，可以手动清理锁目录（需谨慎）

### 5. 镜像文件未生成

**错误信息：** `镜像文件不存在`

**解决方法：**
- 检查服务器上的 `make.sh` 脚本是否正常执行
- 查看服务器日志确认镜像制作过程是否有错误
- 检查镜像文件路径和命名是否正确

### 6. 配置文件不存在

**错误信息：** `配置文件不存在: script/config.sh`

**解决方法：**
```bash
cd script
cp config.sh.example config.sh
# 然后编辑 config.sh 填写实际的服务器信息
```

### 7. 编译失败

**错误信息：** Go 编译错误

**解决方法：**
- 检查 `configurations.toml` 中的 `Root` 路径是否正确
- 确认 GOROOT 路径存在且包含完整的 Go 工具链
- 检查环境变量配置是否正确

## 注意事项

1. **服务器配置**：使用前必须配置 `config.sh` 文件中的服务器信息（复制 `config.sh.example` 为 `config.sh` 并填写）
2. **配置文件**：使用前必须修改 `configurations.toml` 中的 `Root` 路径
3. **环境变量**：脚本会设置 `GOOS`、`GOARCH`、`CGO_ENABLED` 等环境变量，确保交叉编译正确
4. **网络要求**：需要能够访问镜像制作服务器和 FTP 服务器
5. **权限要求**：确保对输出目录有写权限
6. **并发限制**：由于锁机制，同一时间只能有一个镜像制作任务运行
7. **文件清理**：脚本不会自动清理之前生成的文件，如需清理请手动删除
8. **敏感信息**：`config.sh` 文件包含敏感信息，已被添加到 `.gitignore`，请勿提交到版本控制系统

## 完整使用示例

```bash
# 方式一：使用总脚本（推荐）
cd /path/to/benchmarks-master
./build_upload.sh test001

# 方式二：分步执行
cd /path/to/benchmarks-master/script

# 步骤1：生成测试文件
./build_normal_bent.sh

# 步骤2：上传并制作镜像
./deploy_image.sh test001
```

## 相关链接

- [bent 工具文档](https://pkg.go.dev/golang.org/x/benchmarks/cmd/bent)
- [Go 交叉编译文档](https://go.dev/doc/install/source#environment)
