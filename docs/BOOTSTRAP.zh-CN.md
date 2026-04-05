# RDNA1 ROCm Bootstrap 命令说明

这个仓库提供了一个面向 `RDNA1 / Navi1x / gfx101x` 的通用 staged bootstrap 工具：

- [tools/rdna1-rocm-bootstrap.sh](../tools/rdna1-rocm-bootstrap.sh)

对精确的 `W5500 / Navi14 / gfx1012` 已验证路线，也保留了一个兼容包装层：

- [tools/w5500-rocm-bootstrap.sh](../tools/w5500-rocm-bootstrap.sh)

仓库内已经打包了三组对应的固件覆盖层：

- [tools/assets/firmware/navi10](../tools/assets/firmware/navi10)
- [tools/assets/firmware/navi12](../tools/assets/firmware/navi12)
- [tools/assets/firmware/navi14](../tools/assets/firmware/navi14)

这不是“盲目一键成功”按钮，而是一个可审计的 staged helper。

下面凡是出现占位符的位置，都应该替换成你自己显卡对应的 `ASIC` 与 `arch`。比如 `W5700` 这一类就该用 `navi10 + gfx1010`；而本仓库最强验证样本对应的是 `navi14 + gfx1012`。

## 已支持的子命令

### 1. `doctor`

采集当前主机状态：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> doctor
```

也可以显式指定 PCI BDF：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> doctor --pci-bdf <PCI_BDF>
```

### 2. `backup-firmware`

备份当前目标 ASIC 固件：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> backup-firmware
```

也可以指定备份目录：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> backup-firmware --out /path/to/backup
```

### 3. `install-firmware-overlay`

安装目标 ASIC 的固件覆盖层并重建 `initramfs`：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay
```

如果要用外部目录：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay --from /path/to/new-firmware-dir
```

指定目标内核：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay \
  --kernel <KERNEL_VERSION>
```

只做演练：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay --dry-run
```

### 4. `link-rocm7-arch`

把目标 `gfx101x` 架构的 `rocBLAS/Tensile` 文件补进 ROCm 7 用户态：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library
```

也支持 dry-run：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library \
  --dry-run
```

对 `W5500 / gfx1012` 路线，也仍保留兼容别名：

```bash
./tools/w5500-rocm-bootstrap.sh link-rocm7-gfx1012 \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library
```

### 5. `print-build-rocm6`

打印 `ROCm 6 + gfx101x` 的 `llama.cpp` 构建命令：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> print-build-rocm6
```

### 6. `print-build-rocm7`

打印 `ROCm 7 + gfx101x` 的 `llama.cpp` 构建命令：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> print-build-rocm7
```

## 建议顺序

1. `doctor`
2. `backup-firmware`
3. `install-firmware-overlay`
4. 重启并重新 `doctor`
5. `link-rocm7-arch`
6. `print-build-rocm6` / `print-build-rocm7`

## 实际适用范围说明

现在这套工具已经参数化到：

- `navi10 / navi12 / navi14`
- `gfx1010 / gfx1011 / gfx1012`

所以像 `W5700`、`5600M` 这类同代 `RDNA1` 用户，拿到这套工具链后，至少在流程结构上可以直接复用。

但仍要强调：

- 本仓库最强的真实验证主样本，仍然是 `W5500 / Navi14 / gfx1012`
- 更大范围的 `RDNA1` 支持，在这里应被理解成“泛化后的 workflow”，而不是“逐卡等量验证过的结论”

## 这套脚本解决的是什么

它不是替代文档，而是把文档里最容易出错、又最适合标准化的动作变成命令。

真正需要人做判断的部分仍然包括：

- 你是否要覆盖固件
- 你是否已经确认目标内核
- 你的卡实际 BDF 是多少
- 你的机器是否存在 PCIe 物理链路问题

所以它更适合被理解成：

> 一个可审计的 staged bootstrap helper，而不是一个盲目的一键黑盒。
