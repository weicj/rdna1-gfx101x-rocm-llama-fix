# Agent Runbook：让 RDNA1 / Navi1x / gfx101x 在 ROCm 6 与 ROCm 7 上跑现代大模型的步骤

这份 runbook 不是叙述文，而是给 agent / 运维工程师 / 自动化助手执行的程序化步骤。

它面向的是 `RDNA1 / Navi1x / gfx101x` 整个家族，但当前最强的真实验证主样本仍然是 `Radeon Pro W5500 / Navi14 / gfx1012`。

## 目标

把一张目标 `RDNA1 / Navi1x / gfx101x` 显卡带进可用的 `ROCm` 现代大模型推理通路，并明确区分：

- `ROCm 6` 的稳定路径
- `ROCm 7` 的增强路径

## 适用前提

- 主机平台可能较老，例如 `X58 / Intel 5520/5500`
- 显卡是目标 `navi10`、`navi12` 或 `navi14`
- 架构是目标 `gfx1010`、`gfx1011` 或 `gfx1012`
- 有 `sudo`
- 可以接受重启
- 目标工作负载是 `llama.cpp` 推理，而不是先做通用 HIP 开发

## 第一阶段：先记录现状，别盲改

### 第 1 步：记录 PCIe 拓扑与显卡状态

```bash
lspci -nn | rg 'VGA|Display|Audio'
lspci -tv
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|atomics|navi1' -i
```

### 第 2 步：记录当前实际加载的 amdgpu 微码版本

```bash
sudo cat /sys/kernel/debug/dri/<PCI_BDF>/amdgpu_firmware_info
```

重点看：

- `MEC`
- `MEC2`

在最强验证样本 `navi14` 上，原始失败案例是：

- `MEC = 123`
- 内核日志：
  - `kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145`

如果你在目标 ASIC 上也看到这类错误，就继续做固件阶段。

## 第二阶段：把目标 Navi1x ASIC 的有效 MEC 版本抬上去

### 第 3 步：备份现有目标 ASIC 固件

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo mkdir -p /home/max/firmware-backups/<asic>-$TS
sudo cp -a /lib/firmware/amdgpu/<asic>_* /home/max/firmware-backups/<asic>-$TS/ 2>/dev/null || true
```

### 第 4 步：安装目标 ASIC 的新版上游 `linux-firmware` 覆盖层

使用较新的上游 `linux-firmware` 中与你目标 ASIC 对应的固件（`navi10` / `navi12` / `navi14`），覆盖到：

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

在最强验证主机上，实际差异非常明显：

- 容易出问题的通路：`6.17`
- 首条稳定通路：`6.8`

重启后立刻验证：

```bash
uname -r
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|atomics|navi1' -i
rocminfo | rg 'gfx101[0-2]|Agent'
```

成功判据：

- 出现 `kfd ... added device ...`
- `rocminfo` 里能看到目标 `gfx101x`
- `MEC` 不再是被拒绝的旧值
- 在最强验证样本 `navi14` 上，这个值被抬到了 `156`

## 第四阶段：先把 ROCm 6 跑稳

### 第 7 步：确认 ROCm 6 用户态路径

在最强验证主机上，第一条稳定可部署路线是：

- `ROCm 6.3.3`
- `Linux 6.8`

建议检查：

```bash
ldd /path/to/llama.cpp/build-rocm-<gfx101x>/bin/llama-server | rg 'hip|rocblas|hsa'
rocm-smi
rocminfo | rg 'gfx101[0-2]'
```

### 第 8 步：编出专用 `gfx101x` 的 ROCm 6 `llama.cpp`

整个 `gfx101x` 家族都建议沿用同一套参数结构，只把目标架构替换成你自己的值：

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=<gfx101x>`
- `GPU_TARGETS=<gfx101x>`
- `CMAKE_HIP_ARCHITECTURES=<gfx101x>`
- `GGML_HIP_GRAPHS=ON`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

在本仓库最强验证样本里，`<gfx101x>` 对应的是 `gfx1012`。

参考构建命令：

```bash
cmake -S /path/to/llama.cpp -B build-rocm-<gfx101x> \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=<gfx101x> \
  -DGPU_TARGETS=<gfx101x> \
  -DCMAKE_HIP_ARCHITECTURES=<gfx101x> \
  -DGGML_HIP_GRAPHS=ON \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm-<gfx101x> -j
```

### 第 9 步：对 ROCm 6 路线做最小 API 冒烟

```bash
./build-rocm-<gfx101x>/bin/llama-server \
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

### 第 10 步：不要假设 ROCm 7 对 `gfx101x` 开箱即用

在最强验证主机上，`ROCm 7.2.1` 的第一枪失败是：

- `rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012`

翻译成人话就是：

- ROCm 7 用户态装上了
- 但它给目标 `gfx101x` 准备的 `rocBLAS/Tensile` 资产不完整

### 第 11 步：给 ROCm 7 做一个可写 overlay / linkroot

推荐做法：

- 准备一个可写的 ROCm 7 前缀
- 把 ROCm 6 中与目标 `gfx101x` 对应的 `rocBLAS/Tensile` 文件软链进去

参考命令模式：

```bash
ROCM6=/opt/rocm-6.3.3/lib/rocblas/library
ROCM7=/path/to/rocm-7/lib/rocblas/library

mkdir -p "$ROCM7"

find "$ROCM6" -maxdepth 1 -type f \
  \( -name '*<gfx101x>*' -o -name 'TensileLibrary*<gfx101x>*' -o -name '*lazy*<gfx101x>*' \) \
  -print0 | while IFS= read -r -d '' f; do
    ln -sf "$f" "$ROCM7/$(basename "$f")"
  done
```

在最强验证样本 `gfx1012` 上，这一步一共新增了 `56` 个软链。

### 第 12 步：编出专用 `gfx101x` 的 ROCm 7 二进制

这里继续沿用 `ROCm 6` 那套 `gfx101x` 占位参数结构，只是把构建所用的用户态切换到 `ROCm 7`，并替换成你自己的目标架构。

在本仓库最强验证样本里，`<gfx101x>` 对应的是 `gfx1012`。

```bash
cmake -S /path/to/llama.cpp -B build-rocm7-<gfx101x> \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=<gfx101x> \
  -DGPU_TARGETS=<gfx101x> \
  -DCMAKE_HIP_ARCHITECTURES=<gfx101x> \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm7-<gfx101x> -j
```

### 第 13 步：先拿一只最干净的模型验证 ROCm 7

最强验证主机上的正样本是：

- `Gemma 4 E2B Q4`

已验证方向：

- ROCm 6：
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- ROCm 7：
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

如果你的 ROCm 7 路线没有至少接近这个方向，就优先怀疑：

- 用错了用户态前缀
- 没补齐目标架构的 Tensile 文件
- 运行时链接路径不对

## 第六阶段：正确理解 TTFT

### 第 14 步：区分“后端慢”和“可见首 token 慢”

如果某个 reasoning 模型在 ROCm 7 上 TTFT 很差：

- 不要立刻下结论说 HIP 退化了
- 先把 reasoning 关掉，或者把 budget 打成 0

### 第 15 步：把 W5500 样本当成最强验证参考，而不是所有 RDNA1 的等量证明

这套 workflow 现在已经扩展到了：

- `navi10 / navi12 / navi14`
- `gfx1010 / gfx1011 / gfx1012`

所以像 `W5700`、`5600M` 这样的用户，至少在流程结构上已经可以直接复用。

但仍然要明确：

- 最强真实验证样本还是 `W5500 / Navi14 / gfx1012`
- 更大范围的 `RDNA1` 支持，在这里应被理解成“泛化后的 workflow”，不是“逐卡等量验证过的结论”

## 故障树

### 情况 A：目标 RDNA1 显卡还是没有出现在 `rocminfo` 里

检查：

1. `lspci -nn`
2. `journalctl -k -b | rg -n 'kfd|atomics|navi1' -i`
3. `amdgpu_firmware_info`

### 情况 B：ROCm 7 一启动就炸

优先看：

- `rocBLAS error`
- `TensileLibrary.dat`
- 目标 `gfx101x` 架构没有对应资产

### 情况 C：吞吐不差，但 TTFT 很差

优先看：

- reasoning 行为
- 首个可见 token 的定义
- cache reuse
- prompt 长度

### 情况 D：重启后卡消失

先当成 PCIe / 链路问题，而不是先当成 ROCm 问题。

## 最终建议

- 先稳稳走通 `ROCm 6.3.3 + Linux 6.8`
- 再叠 `ROCm 7`
- 把 `W5500 / Navi14 / gfx1012` 当成最强验证样本
- 把更大范围的 `RDNA1 / Navi1x / gfx101x` 当成已经可以复用的通用 workflow
