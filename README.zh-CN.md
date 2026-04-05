[English](./README.md) | [简体中文](./README.zh-CN.md)

# RDNA1 / Navi1x / gfx101x 现代大模型推理适配：利用 ROCm 运行 llama.cpp

![RDNA1-gfx101x](https://img.shields.io/badge/RDNA1-gfx101x-blue)
![ROCm-6.3%2B%20%7C%207%2B](https://img.shields.io/badge/ROCm-6.3%2B%20%7C%207%2B-red)
![LLM-llama.cpp](https://img.shields.io/badge/LLM-llama.cpp-orange)
![License-Apache%202.0](https://img.shields.io/badge/License-Apache%202.0-green)

这份仓库记录的不是“ROCm 装好了”这种表面结果，而是一条更实际的工程目标：

让 `RDNA1 / Navi1x / gfx101x` 这类显卡，通过 `ROCm 6 / 7 + llama.cpp` 真正跑起近几代值得部署的大语言模型。

它不是泛化教程，也不是资料搬运。它是一份基于真实 bring-up、真实踩坑、真实回归和真实跑分整理出来的实战记录。

但同时必须明确，这份仓库里的**真实实机验证**主要是基于 `Radeon Pro W5500`，也就是 `Navi14 / gfx1012`。所以项目概念上是更通用的 `RDNA1 / Navi1x / gfx101x` 方案，但性能和部署结论来自真实 `W5500` 机器，而不是空泛外推。

## 面向的显卡家族

这份项目的方法论，面向的是 `RDNA1 / Navi1x / gfx101x` 这整个离散显卡家族。

但最强的置信度仍然集中在真正实测过的这条线上，也就是 `Radeon Pro W5500 / Navi14 / gfx1012`。

更广义的目标卡系可以概括为：

| ASIC / 架构 | 理论适用的主要型号 | 说明 |
|---|---|---|
| `gfx1010 / Navi10` | `Radeon RX 5600 XT`、`Radeon RX 5700`、`Radeon RX 5700 XT`、`Radeon Pro W5700`、`Radeon Pro W5700X`、`Radeon Pro V520`、以及部分 `5600M / 5700M` 移动衍生型号 | 属于同代 RDNA1 家族，理论上有参考意义，但本仓库未直接逐卡验证 |
| `gfx1011 / Navi12` | `Radeon Pro 5600M` 及其近似 Navi12 衍生型号 | 理论上有参考意义，但本仓库未直接逐卡验证 |
| `gfx1012 / Navi14` | `Radeon RX 5300`、`Radeon RX 5500`、`Radeon RX 5500 XT`、`Radeon Pro W5500`、`Radeon Pro W5500X`、`Radeon Pro 5300M`、`Radeon Pro 5500M`、`Radeon RX 5300M`、`Radeon RX 5500M` | 和本项目最接近；真实验证主样本就是 `W5500 / gfx1012` |

如果你的卡不是 `Navi14 / gfx1012`，更合理的理解方式是：

- 把这份仓库当作同架构家族的工程参考
- 不要把它理解成对你那张卡的无条件保证

## 在真实 W5500 硬件上已经测试过的底座

| 官方底座 / 家族 | 已测试的 ROCm 通路 | 当前状态 | 简短结论 |
|---|---|---|---|
| Gemma 4 | ROCm 6 / ROCm 7 | stable | 当前最强、最干净的 W5500 主线基座 |
| Gemma 3n | ROCm 6 | stable | 已验证，但综合明显落后于最强 Gemma 4 线 |
| Qwen3.5 | ROCm 6 / ROCm 7 | stable with caveats | 多条线都能跑，但 ROCm 7 下某些 reasoning 线的可见 TTFT 要特别解释 |
| Qwen 3 | ROCm 6 | stable | 已有可用文本子线样本，但不是当前最强部署位 |
| PrismML Bonsai-8B | ROCm 7 + 专用补丁版 `llama.cpp` | special-case success | 特殊格式案例，依赖源码层 bring-up |

## 验证范围与风险说明

这首先是一个**个人实验项目**，不是厂商认证，也不是官方支持声明。

这份仓库背后的真实验证环境，主要是：

- 主机平台：`Mac Pro 5,1`
- 启动栈：`OpenCore`
- 系统：`Ubuntu`
- 显卡：`Radeon Pro W5500`

也正因为如此，它对遇到类似 `RDNA1 / Navi1x / gfx101x` 问题的人可能很有参考价值。

但正确的理解方式应该是：

- 它是在一个真实、具体、反复试出来的环境里完成验证的
- 对同架构家族的卡理论上有较高参考意义
- 但并不保证对所有板卡、固件、桥接、内核与 PCIe 拓扑都必然成立

所以这份项目更适合被理解成一份强参考的实战经验。使用风险自担。

## 入口工具

这个工程现在已经不是只有文档。

它内置了一套可在 Linux 本地执行的 staged bootstrap 工具，用来把最关键、最容易出错的步骤标准化下来：

- 通用 bootstrap 脚本：[`tools/rdna1-rocm-bootstrap.sh`](./tools/rdna1-rocm-bootstrap.sh)
- W5500 兼容包装层：[`tools/w5500-rocm-bootstrap.sh`](./tools/w5500-rocm-bootstrap.sh)
- Tool 布局说明：[tools/README.md](./tools/README.md)
- 固件资源目录：
  - [`tools/assets/firmware/navi10`](./tools/assets/firmware/navi10)
  - [`tools/assets/firmware/navi12`](./tools/assets/firmware/navi12)
  - [`tools/assets/firmware/navi14`](./tools/assets/firmware/navi14)
- 中文 bootstrap 说明：[docs/BOOTSTRAP.zh-CN.md](./docs/BOOTSTRAP.zh-CN.md)

这套工具不是那种危险的“盲目一键成功”按钮，而是一个可审计、分阶段的入口：

- `doctor`
- `backup-firmware`
- `install-firmware-overlay`
- `link-rocm7-arch`
- `print-build-rocm6`
- `print-build-rocm7`

其中 `Navi10 / Navi12 / Navi14` 对应的固件覆盖层已经被直接打包进仓库，所以在**本地不联网**的情况下，固件这一步本身可以闭环完成。

## 文档与 Agent 工作流入口

这个工程不只是给人类读的说明文档，也附带了一套明确面向 agent 的工作流文档，适合被这些 CLI 工具直接读取和调用：

- `Claude Code`
- `Codex`
- `Gemini CLI`

人类与 agent 共用的主要入口是：

- [docs/AGENT_RUNBOOK.zh-CN.md](./docs/AGENT_RUNBOOK.zh-CN.md)
- [docs/BOOTSTRAP.zh-CN.md](./docs/BOOTSTRAP.zh-CN.md)
- [docs/model-records/INDEX.zh-CN.md](./docs/model-records/INDEX.zh-CN.md)
- [docs/HARDWARE_SCOPE.zh-CN.md](./docs/HARDWARE_SCOPE.zh-CN.md)
- [LICENSE](./LICENSE)

## 这份项目的目标

这份项目真正要解决的问题，不是让系统工具里偶尔出现一次 `gfx101x`，而是把一张真实的 `RDNA1 / Navi1x / gfx101x` 显卡，当前主要验证对象是 `W5500`，推到下面这个状态：

1. 能被 `KFD/ROCm` 接纳
2. 能成为一条稳定的 `llama.cpp` 推理通路
3. 能真实运行现代模型底座
4. 能给出可复现的性能边界、限制条件和部署结论

## 核心结论

- 最关键的第一关不是模型，而是 `KFD` 放不放行这张卡。
- 这台机器上，决定性变化是把实际加载的 `Navi14 WKS MEC` 从 `123` 提升到 `156`。
- `ROCm 6.3.3 + Linux 6.8` 是这台机器上第一条真正稳定的 `W5500` 推理通路。
- `ROCm 7.2.1` 也可以跑，但不是开箱即用；必须把 `ROCm 6` 里的 `gfx1012` `rocBLAS/Tensile` 资产补进 `ROCm 7` 用户态前缀。
- 经过这些修补之后，真实验证对象 `W5500` 已经能跑多条现代模型底座，并拿到足够有参考价值的性能结果。

## 真正解决了哪些问题

### 1. `KFD` 放行问题

原始阻塞是：

```text
kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145
```

这说明问题并不只是“驱动认不认识型号”，而是：

- 所在 PCIe 链路没有完整 atomics routing
- 同时这张卡实际加载到的 `MEC` 微码版本又太低

真正把这一步打通的，不是换某个 Python 包，而是让 `Navi14` 实际加载到更新后的微码。

### 2. 稳定内核通路

在这台机器上，内核版本差异不是小问题。

- `Linux 6.17` 并不是 `W5500` 的稳定通路
- `Linux 6.8` 才是第一条真正稳定的 `ROCm 6` 推理通路

### 3. ROCm 7 的 `gfx1012` 用户态缺口

`ROCm 7` 的第一枪并不是“性能差”，而是直接缺资产：

```text
rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012
```

这意味着：

- ROCm 7 用户态并不完整覆盖 `gfx1012`
- 需要把 `ROCm 6` 中与 `gfx1012` 相关的 `rocBLAS/Tensile` 文件补到 `ROCm 7` 用户态前缀里

### 4. `llama.cpp` 验证通路

固件、内核、用户态都稳定之后，真正的验证目标才轮到 `llama.cpp`：

- 不是“系统认卡”
- 而是“模型能不能真的启动、推理、回包、测出性能”

## 各基座下已验证的具体测试文件

这里需要特别说明：`TTFT` 只有在**输入规模接近、测试口径接近**时才有严格可比性。因此下面不只写模型文件和吞吐，还同时标注使用的上下文、测试口径，以及引用结果时对应的 `prompt_tokens` 规模。统一 formal 的短 prompt 结果彼此最可比；最小请求 probe 和临时吞吐探针更适合作为工程参考，而不是严格横比。

### Gemma 4

- `gemma-4-E2B-it-Q4_K_M.gguf`
  - 近似文件大小：`3.11 GB`
  - 使用上下文：`131072`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 63`
  - `ROCm 6`：`C1 42.317 tok/s`，`TTFT 281.5 ms`
  - `ROCm 7`：`C1 43.890 tok/s`，`TTFT 258.6 ms`

### Gemma 3n

- `gemma-3n-E4B-it-UD-Q4_K_XL.gguf`
  - 近似文件大小：`5.39 GB`
  - 使用上下文：`16384`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 59`
  - `ROCm 6`：`C1 23.341 tok/s`，`TTFT 416.9 ms`
- `gemma-3n-E4B-it-Q4_K_M.gguf`
  - 近似文件大小：`4.54 GB`
  - 使用上下文：`32768`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 59`
  - `ROCm 6`：`C1 22.794 tok/s`，`TTFT 419.9 ms`

### Qwen3.5

- `CoPaw-flash-9B-20260330-q4.gguf`
  - 近似文件大小：`5.63 GB`
  - 使用上下文：`65536`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 161`
  - `ROCm 6`：`C1 20.048 tok/s`，`TTFT 162.1 ms`
  - `ROCm 7`：`C1 22.292 tok/s`，`TTFT 3143.8 ms`
  - `ROCm 7 budget=0 probe`：`C1 22.102 tok/s`，`TTFT 332.4 ms`
- `omnicoder-9b-q4_k_m.gguf`
  - 量化：`Q4_K_M`
  - 使用上下文：`65536`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 161`
  - `ROCm 6`：`C1 18.844 tok/s`，`TTFT 165.9 ms`
- `squeez-2b.i1-Q4_K_M.gguf`
  - 近似文件大小：`1.27 GB`
  - 使用上下文：`65536`
  - 测试口径：本地吞吐探针
  - 输入规模：`prompt_tokens ≈ 1497`
  - `ROCm 7`：`prompt 70.10 tok/s`，`decode 56.36 tok/s`

### Qwen 3

- `MiniCPM-o-4_5-Q4_K_M.gguf`
  - 量化：`Q4_K_M`
  - 使用上下文：`40960`
  - 测试口径：formal 短 prompt 部署口径
  - 输入规模：`prompt_tokens = 160`
  - `ROCm 6`：`C1 23.444 tok/s`，`TTFT 54.3 ms`

### PrismML Bonsai-8B

- `Bonsai-8B.gguf`
  - 近似文件大小：`1.16 GB`
  - 使用上下文：`16384`
  - 测试口径：专用补丁版 `llama.cpp` 的最小请求 probe
  - 输入规模：`prompt_tokens ≈ 26`
  - `ROCm 7` + 专用补丁版 `llama.cpp`：`prompt 108.40 tok/s`，`decode 65.99 tok/s`（最小请求）

## 模型问题解析

这里不只关心“模型能不能跑”，还要单独解释那些在真实部署里必须看懂的问题。

### 1. 为什么 Gemma 系的 TTFT 会偏慢

Gemma 系 TTFT 慢，不能简单理解成“ROCm 慢”或者“W5500 慢”。从实测日志和运行行为看，核心原因首先来自模型自身的运行时特征。

在新上游 `llama.cpp` 的日志里，Gemma 相关模型反复出现：

- `forcing full prompt re-processing due to lack of cache data`
- 并且提示与 `SWA`
- `hybrid memory`
- `recurrent memory`
  有关

这说明：

- Gemma 这类模型的 prompt cache 复用行为，和更简单的 Qwen 系不完全一样
- 即使底层 HIP kernel 没退化，首 token 之前的准备工作也可能更重

同时，我们的实际部署参数也放大了这一点：

- `Gemma 4 E2B` 明确跑到了 `131072 ctx`
- batch / ubatch 也不是刻意为了压极限 TTFT 而缩到很小

所以 Gemma 的真实特征更接近：

- 吞吐强
- 任务能力强
- 但不一定是最低首字延迟

### 2. 为什么 Qwen3.5 衍生 9B 线在 ROCm 7 下会出现“可见 TTFT 异常”

这又是另一类问题，不能和 Gemma 的情况混为一谈。

在那条 Qwen3.5 衍生 9B reasoning 线上，我们看到：

- 默认口径：`C1 22.292 tok/s`，`TTFT 3143.8 ms`
- `budget=0` 探针：`C1 22.102 tok/s`，`TTFT 332.4 ms`

这说明：

- 吞吐其实是升的
- 真正炸掉的是“用户看见首 token 的时间”
- 根因主要是 reasoning / streaming 语义，而不是 ROCm 7 算子本身崩了

### 3. Bonsai-8B 这种特殊格式是怎么被跑起来的

这一条也必须单独写，因为它不是“又一只普通模型”，而是一类会直接逼出源码层修补工作的特殊格式案例。

`Bonsai-8B.gguf` 使用的是一种非常规低比特量化布局。最初的问题不是“速度慢”，而是更前面的：

- upstream `llama.cpp` 根本不能把它当成正常生产量化路径
- 典型报错就是：

```text
invalid ggml type 41
```

真正把它推进到“可以在 W5500 上跑”的过程，是一条单独的源码工程路线。我们实际做的事情可以简化成下面五步：

1. 在独立实验源码树里移植 `Q1_0 / Q1_0_g128`
2. 修 CPU 侧缺失的符号与分发
3. 修 GPU weight placement，让模型不再几乎全留在 `CPU_Mapped`
4. 先让 GPU 路线稳定可回复
5. 再把 `Q1` 的 `MMQ/MMVQ` 快路径补回来

这五步分别解决的是：

- “模型根本认不出来”
- “认出来但后端 dispatch 不完整”
- “能跑但权重大头没真正进 GPU”
- “能启动但只是在弱 GPU / CPU 路径上苟活”
- “真正恢复到量化快路径”

它最终的价值不在于“upstream 已支持”，而在于：

- 我们已经把一种非常规低比特 8B 量化格式，从起不来推进到了真正吃上 W5500 GPU
- 并且在修复 GPU placement 与 `Q1 MMQ/MMVQ` 之后，最小请求已经大约能到：
  - `prompt 108.40 tok/s`
  - `decode 65.99 tok/s`

所以，Bonsai-8B 不是主线成功案例，而是一条非常有价值的特殊格式 bring-up 案例。
