# Benchmark 热点分析工具

## 概述

本工具集用于自动化分析 Go benchmark 测试的热点函数。通过运行每个 benchmark 测试并收集 CPU profile 数据，使用 `pprof` 工具识别热点函数，并生成汇总报告。

## 功能特性

- 自动解析 TOML 配置文件，遍历所有配置的 benchmark
- 支持正则表达式匹配多个 benchmark 测试用例
- 单独运行每个 benchmark 测试，确保准确的性能分析
- 自动过滤热点函数（仅包含 `flat% > 5%` 的函数）
- 生成两个汇总报告：
  - `results.md`: 详细的测试包、测试用例和热点函数信息
  - `point.md`: 按热点函数分组的汇总信息
- 优化输出格式，提高 Markdown 可读性

## 脚本说明

### 主脚本

#### `analyze-hotspots.sh`
主入口脚本，协调整个分析流程。

**用法：**
```bash
./analyze-hotspots.sh <配置文件> <二进制文件目录>
```

**示例：**
```bash
./analyze-hotspots.sh ../tmp/picked.toml ../tmp/testbin/
```

**功能：**
1. 验证输入参数和文件存在性
2. 调用 `generate-results.sh` 生成 `results.md`
3. 调用 `generate-points.sh` 生成 `point.md`
4. 调用 `optimize-results.sh` 优化 `results.md` 格式

### 辅助脚本

#### `generate-results.sh`
生成 `results.md` 文件，包含所有测试包、测试用例和对应的热点函数。

**用法：**
```bash
./generate-results.sh <配置文件> <二进制文件目录> <结果文件> <架构后缀>
```

**功能：**
- 解析 TOML 配置文件
- 查找匹配的二进制文件（格式：`<包名>_<架构后缀>`）
- 列出所有匹配的 benchmark 测试用例
- 单独运行每个 benchmark 并收集 CPU profile
- 使用 `go tool pprof` 分析热点函数
- 过滤并记录 `flat% > 阈值` 的函数

**可配置参数：**
- `FLAT_PCT_THRESHOLD`: 热点函数阈值（默认：5.0），仅统计 `flat%` 大于此值的函数

#### `generate-points.sh`
从 `results.md` 生成 `point.md` 文件，按热点函数分组汇总。

**用法：**
```bash
./generate-points.sh <结果文件> <热点分数文件>
```

**功能：**
- 读取 `results.md` 文件
- 提取所有热点函数及其对应的测试用例和 `flat%` 值
- 按函数名排序并分组输出

#### `optimize-results.sh`
优化 `results.md` 文件格式，提高可读性。

**用法：**
```bash
./optimize-results.sh <结果文件>
```

**功能：**
- 对于相邻行中相同的测试包名或测试用例名，仅保留第一次出现
- 后续相同项留空，符合 Markdown 表格阅读习惯

## 配置文件格式

配置文件采用 TOML 格式，每个 benchmark 配置包含以下字段：

```toml
[[Benchmarks]]
  Name = "包名"
  Benchmarks = "正则表达式"
  Disabled = false  # 可选，默认为 false
```

**字段说明：**
- `Name`: 测试包名称，用于构建二进制文件名（格式：`<Name>_<架构后缀>`）
- `Benchmarks`: 正则表达式，用于匹配该包中的 benchmark 测试用例
- `Disabled`: 可选字段，设置为 `true` 时跳过该配置项

**示例：**
```toml
[[Benchmarks]]
  Name = "uber_zap"
  Benchmarks = "Benchmark"

[[Benchmarks]]
  Name = "wazero"
  Benchmarks = "BenchmarkInvocation/interpreter/fib_for_20"
```

## 输出文件

### `results.md`
包含所有测试包、测试用例和对应的热点函数信息。

**格式：**
```markdown
|测试包|测试用例|热点函数|
|------|--------|--------|
|uber_zap|BenchmarkStandardJSON-6|     0.84s 51.22% 51.22%      1.52s 92.68%  github.com/...|
|uber_zap|BenchmarkStandardJSON-6|     0.23s  5.46% 56.68%      0.25s  5.68%  runtime.allocm|
```

**说明：**
- 测试包名和测试用例名在相邻行相同时会被优化为空（仅保留第一次出现）
- 热点函数列包含完整的 `pprof top` 输出行信息

### `point.md`
按热点函数分组，列出所有相关的测试用例及其 `flat%` 值。

**格式：**
```markdown
|热点函数|热点值|
|--------|------|
|runtime.mallocgc|BenchmarkStandardJSON-6             51.22%|
||BenchmarkFastTest2KB             35.47%|
|go.uber.org/zap/zapcore.(*BufferedWriteSyncer).Write|BenchmarkStandardJSON-6             5.46%|
```

**说明：**
- 同一函数的多个测试用例使用空单元格表示函数名
- 热点值格式：`<测试用例名>             <flat%>%`

## 可配置参数

### `analyze-hotspots.sh`
- `ARCH_SUFFIX`: 二进制文件的架构后缀（默认：`"Amd64-Static"`）

### `generate-results.sh`
- `FLAT_PCT_THRESHOLD`: 热点函数阈值（默认：`5.0`），仅统计 `flat%` 大于此值的函数

## 使用示例

### 基本使用

```bash
# 在 tools 目录下执行
cd tools
./analyze-hotspots.sh ../tmp/picked.toml ../tmp/testbin/
```

### 修改架构后缀

编辑 `analyze-hotspots.sh`，修改 `ARCH_SUFFIX` 变量：
```bash
ARCH_SUFFIX="RISC-V-Static"  # 或其他架构后缀
```

### 修改热点阈值

编辑 `generate-results.sh`，修改 `FLAT_PCT_THRESHOLD` 变量：
```bash
FLAT_PCT_THRESHOLD=10.0  # 仅统计 flat% > 10% 的函数
```

## 工作原理

1. **解析配置**：使用 `awk` 解析 TOML 配置文件，提取所有启用的 benchmark 配置
2. **查找二进制文件**：根据配置中的 `Name` 和 `ARCH_SUFFIX` 构建二进制文件路径
3. **列出测试用例**：运行 benchmark 一次（不收集 profile）以获取所有匹配的测试用例列表
4. **单独运行测试**：对每个测试用例单独运行，使用 `-test.cpuprofile` 收集 CPU profile
5. **分析热点**：使用 `go tool pprof` 的 `top 30` 命令分析 profile，提取 `flat% > 阈值` 的函数
6. **生成报告**：汇总所有结果到 `results.md`，然后生成 `point.md` 和优化后的 `results.md`

## 注意事项

1. **二进制文件格式**：二进制文件必须命名为 `<包名>_<架构后缀>` 格式，且必须可执行
2. **Go 工具链**：需要安装 Go 工具链，确保 `go tool pprof` 命令可用
3. **Profile 文件**：每次运行会覆盖 `cpu.out` profile 文件，但结果已记录后才覆盖
4. **Benchmark 名称**：保留完整的 benchmark 名称，包括迭代次数后缀（如 `-6`）
5. **正则表达式**：`Benchmarks` 字段支持正则表达式，可以匹配多个测试用例
6. **执行时间**：每个 benchmark 单独运行，大型测试集可能需要较长时间

## 故障排除

### 问题：`results.md` 为空或只有表头

**可能原因：**
- 没有找到匹配的 benchmark 测试用例
- 所有测试用例的 `flat%` 都小于阈值
- Profile 文件生成失败

**解决方法：**
- 检查配置文件中的正则表达式是否正确
- 检查二进制文件是否存在且可执行
- 尝试降低 `FLAT_PCT_THRESHOLD` 阈值
- 检查 benchmark 执行是否成功

### 问题：某些 benchmark 的结果与手动测试不一致

**可能原因：**
- Benchmark 运行时间过短，profile 数据不足
- 测试环境差异

**解决方法：**
- 可以在 `generate-results.sh` 中添加 `-test.benchtime` 参数延长运行时间
- 确保测试环境一致

### 问题：脚本执行权限错误

**解决方法：**
```bash
chmod +x *.sh
```
