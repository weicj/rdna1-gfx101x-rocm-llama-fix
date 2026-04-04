# Agent Runbook：让 W5500 在 ROCm 6 与 ROCm 7 上跑现代大模型的步骤

这份 runbook 不是叙述文，而是给 agent / 运维工程师 / 自动化助手执行的程序化步骤。

目标不是“讲道理”，而是**按顺序把卡拉起来，并在每一阶段知道该看什么、该判什么**。

## 目标

把 `AMD Radeon Pro W5500 (Navi14 / gfx1012)` 带进可用的 `ROCm` 现代大模型推理通路，并明确区分：

- `ROCm 6` 的稳定路径
- `ROCm 7` 的增强路径

## 适用前提

- 主机平台可能较老，例如 `X58 / Intel 5520/5500`
- 显卡是 `W5500`，PCI ID 为 `1002:7341`
- 有 `sudo`
- 可以接受重启
- 目标工作负载是 `llama.cpp` 推理，而不是先做通用 HIP 开发

## 第一阶段：先记录现状，别盲改

### 第 1 步：记录 PCIe 拓扑与显卡状态

```bash
lspci -nn | rg '7341|VGA|Display|Audio'
lspci -tv
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|7341|atomics|navi14' -i
```

### 第 2 步：记录当前实际加载的 amdgpu 微码版本

```bash
sudo cat /sys/kernel/debug/dri/0000:05:00.0/amdgpu_firmware_info
```

最关键的是看：

- `MEC`
- `MEC2`

原始失败案例里，核心问题是：

- `MEC = 123`
- 内核日志里出现：
  - `kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145`

如果你也看到这类错误，继续做固件阶段。

## 第二阶段：把 Navi14 的有效 MEC 版本抬上去

### 第 3 步：备份现有 `Navi14` 固件

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo mkdir -p /home/max/firmware-backups/navi14-$TS
sudo cp -a /lib/firmware/amdgpu/navi14_* /home/max/firmware-backups/navi14-$TS/ 2>/dev/null || true
```

### 第 4 步：安装新版上游 `linux-firmware` 的 `navi14_*.bin` 覆盖层

使用较新的上游 `linux-firmware` 中的 `navi14_*.bin`，覆盖到：

```text
/lib/firmware/amdgpu/
```

推荐做法：

- 不要粗暴删掉发行版原包
- 直接额外放未压缩 `.bin` 覆盖层
- 然后重建 `initramfs`

### 第 5 步：重建 `initramfs`

```bash
sudo update-initramfs -u -k "$(uname -r)"
```

如果你打算切到指定内核，也要对目标内核重建。

## 第三阶段：优先走稳定内核通路

### 第 6 步：优先用 `Linux 6.8` 做第一轮稳定验证

这台机器上，实际差异非常明显：

- 容易出问题的通路：`6.17`
- 首条稳定通路：`6.8`

重启后立刻验证：

```bash
uname -r
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|7341|atomics|navi14' -i
rocminfo | rg 'gfx1012|W5500|Agent'
```

成功判据：

- 出现 `kfd ... added device 1002:7341`
- `rocminfo` 里能看到 `gfx1012`
- `MEC` 不再是 `123`
- 成功实测里，`MEC` 被抬到了 `156`

## 第四阶段：先把 ROCm 6 跑稳

### 第 7 步：确认 ROCm 6 用户态路径

这台机器上第一条稳定可部署的路线是：

- `ROCm 6.3.3`
- `Linux 6.8`

建议检查：

```bash
ldd /home/max/src/llama.cpp-upstream/build-rocm-gfx1012/bin/llama-server | rg 'hip|rocblas|hsa'
rocm-smi
rocminfo | rg 'gfx1012'
```

### 第 8 步：编出专用 `gfx1012` 的 ROCm 6 `llama.cpp`

已验证的关键 cache 参数：

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=gfx1012`
- `CMAKE_HIP_ARCHITECTURES=gfx1012`
- `GGML_HIP_GRAPHS=ON`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

参考构建命令：

```bash
cmake -S /path/to/llama.cpp -B build-rocm-gfx1012 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx1012 \
  -DGPU_TARGETS=gfx1012 \
  -DCMAKE_HIP_ARCHITECTURES=gfx1012 \
  -DGGML_HIP_GRAPHS=ON \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm-gfx1012 -j
```

### 第 9 步：对 ROCm 6 路线做最小 API 冒烟

```bash
./build-rocm-gfx1012/bin/llama-server \
  -m /path/to/model.gguf \
  -dev ROCm0 \
  -ngl 999 \
  -fa on \
  -c 32768 \
  -b 256 \
  -ub 256 \
  --host 127.0.0.1 \
  --port 8101
```

然后请求：

```bash
curl -fsS http://127.0.0.1:8101/v1/models
curl -fsS http://127.0.0.1:8101/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}],"temperature":0,"max_tokens":12}'
```

这条通路稳定了，再往上加 ROCm 7。

## 第五阶段：谨慎把 ROCm 7 补上

### 第 10 步：不要假设 ROCm 7 对 `gfx1012` 开箱即用

这台机器上，`ROCm 7.2.1` 第一枪的直接失败是：

- `rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012`

翻译成人话就是：

- ROCm 7 用户态装上了
- 但它给 `gfx1012` 准备的 `rocBLAS/Tensile` 资产不完整

### 第 11 步：给 ROCm 7 做一个可写 overlay / linkroot

推荐做法：

- 准备一个可写的 ROCm 7 前缀
- 把 ROCm 6 中与 `gfx1012` 相关的 `rocBLAS/Tensile` 文件软链进去

参考命令模式：

```bash
ROCM6=/opt/rocm-6.3.3/lib/rocblas/library
ROCM7=/home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library

mkdir -p "$ROCM7"

find "$ROCM6" -maxdepth 1 -type f \
  \( -name '*gfx1012*' -o -name 'TensileLibrary*gfx1012*' -o -name '*lazy*gfx1012*' \) \
  -print0 | while IFS= read -r -d '' f; do
    ln -sf "$f" "$ROCM7/$(basename "$f")"
  done
```

实机里，这一步一共新增了 `56` 个软链。

### 第 12 步：编出专用 `gfx1012` 的 ROCm 7 二进制

这份项目的 `ROCm 7` 说明应当只围绕 `W5500 / gfx1012` 本身展开，不把其它显卡路线混进主流程。

推荐的 `gfx1012` 专用 cache 参数与 `ROCm 6` 逻辑一致，只是换成 `ROCm 7` 用户态：

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=gfx1012`
- `GPU_TARGETS=gfx1012`
- `CMAKE_HIP_ARCHITECTURES=gfx1012`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

参考构建命令：

```bash
cmake -S /path/to/llama.cpp -B build-rocm7-gfx1012 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx1012 \
  -DGPU_TARGETS=gfx1012 \
  -DCMAKE_HIP_ARCHITECTURES=gfx1012 \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm7-gfx1012 -j
```

### 第 13 步：先拿一只最干净的模型验证 ROCm 7

这台机器上最干净的正样本，是一只官方底座模型：

- `Gemma 4 E2B Q4`

已验证结果方向：

- ROCm 6：
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- ROCm 7：
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

如果你的 ROCm 7 路线没有至少接近这个方向，就优先怀疑：

- 用错了用户态前缀
- `gfx1012` Tensile 文件没补齐
- 运行时链接路径没指到你自己的 ROCm 7 overlay

## 第六阶段：正确理解 TTFT

### 第 14 步：把“后端慢”和“可见首 token 慢”分开看

如果某个带 reasoning 的模型在 ROCm 7 上 TTFT 很差：

- 不要立刻下结论说 HIP kernel 退化了
- 先把 reasoning 关掉，或者把 `budget` 打成 `0`

一条 `Qwen3.5` 衍生的 9B reasoning 微调线的典型例子：

- 默认 ROCm 7：`C1 22.292 tok/s`，`TTFT 3143.8 ms`
- `budget=0` 探针：`C1 22.102 tok/s`，`TTFT 332.4 ms`

这说明：

- 吞吐其实是升的
- 真正炸掉的是“用户看见首 token 的时间”
- 根因在 reasoning / streaming 语义，而不是算子本身变慢

### 第 15 步：Gemma 的 TTFT 要看缓存行为，不要只看 GPU

如果日志里反复出现：

- `forcing full prompt re-processing due to lack of cache data`

并且同时提到：

- `SWA`
- `hybrid memory`
- `recurrent memory`

那就说明：

- 这个模型的 prompt cache 复用行为和更简单的 Qwen 系不一样
- TTFT 会被模型运行时特征影响，而不是只被 GPU 后端影响

## 第七阶段：故障树

### 情况 A：`rocminfo` 还是看不到 W5500

检查：

```bash
lspci -nn | rg 7341
journalctl -k -b | rg -n '7341|kfd|atomics' -i
sudo cat /sys/kernel/debug/dri/0000:05:00.0/amdgpu_firmware_info
```

优先怀疑：

1. PCIe 层根本没枚举出来
2. 旧 MEC 版本还在
3. 还在错误内核 lane 上

### 情况 B：ROCm 7 一启动就炸

优先看日志里有没有：

- `rocBLAS error`
- `TensileLibrary.dat`
- `GPU arch : gfx1012`

如果有，优先怀疑：

- ROCm 7 用户态缺 `gfx1012` 的 `rocBLAS/Tensile` 资产

### 情况 C：吞吐没问题，但 TTFT 奇慢

排查顺序：

1. `reasoning-budget`
2. streaming / visible token 语义
3. prompt cache 是否复用失败
4. 当前会话是否已经膨胀成超长上下文

### 情况 D：重启后卡又没了

先当成 PCIe / 物理链路问题，而不是先当成 ROCm 问题。

重点看：

- 冷启动 vs 热重启
- 插槽接触 / 重新插拔
- 链路训练
- 是否掉到 `2.5 GT/s x4`

## 最终建议

- 第一阶段先稳稳走通 `ROCm 6.3.3 + Linux 6.8`
- 第二阶段再上 `ROCm 7`
- `ROCm 7` 应被视为增强路线，而不是最初 bring-up 路线
- 项目发布上，先发独立仓库，不急着开 `llama.cpp` fork
- 等真正有长期维护的源码 patch 链时，再考虑 fork

## 附录：实验性量化格式单独处理

如果目标模型使用的是 `Q1_0 / Q1_0_g128` 这类非常规低比特布局，不要把它混进主线 ROCm bring-up。

应当把它视为一条独立工程路线。

建议顺序：

1. 先确认标准 ROCm 通路已经能稳定跑官方底座模型。
2. 把这类自定义量化工作挪到独立实验源码树。
3. 先修“类型能不能被正确识别和加载”。
4. 再修 CPU 侧缺失的符号和分发。
5. 再修 GPU weight placement，让模型不再大头都留在 `CPU_Mapped`。
6. 只有在模型稳定可回复之后，才去恢复或实现对应的 `MMQ/MMVQ` 快路径。
7. 重新测时，必须明确区分：
   - “技术上能启动，但大头还在 CPU/弱 GPU 路径”
   - “真正已经进 GPU 并开始吃快路径”

这一区别在实战里非常关键。那条实验性 `Q1` 8B 路线，只有在 GPU placement 与快路径恢复之后，才真正变得有意义；恢复后的最小请求已经大约能到：

- `prompt 108.40 tok/s`
- `decode 65.99 tok/s`
