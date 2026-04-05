# RDNA1 ROCm Bootstrap 命令说明

这个仓库现在提供了一个通用入口脚本：

- [tools/rdna1-rocm-bootstrap.sh](../tools/rdna1-rocm-bootstrap.sh)

同时也保留了对 `W5500 / Navi14 / gfx1012` 这条精确路线的兼容包装：

- [tools/w5500-rocm-bootstrap.sh](../tools/w5500-rocm-bootstrap.sh)

并且已经把 `RDNA1` 相关的固件覆盖层一起打包进仓库：

- [tools/assets/firmware/navi10](../tools/assets/firmware/navi10)
- [tools/assets/firmware/navi12](../tools/assets/firmware/navi12)
- [tools/assets/firmware/navi14](../tools/assets/firmware/navi14)

它的目标不是提供一个不透明的“魔法一键成功”按钮，而是把真正能自动化的步骤标准化下来。

## 为什么不做成完全黑盒的一键命令

原因很简单：

- 固件覆盖是高风险步骤
- `initramfs` 重建和重启需要人为判断
- 某些机器的 PCIe 枚举问题并不是纯软件能保证修好

所以更专业的做法，是做成**一个入口、多个阶段子命令**：

- 既能帮助别人少走弯路
- 又不会把风险伪装成“随便按一下就行”

## 已支持的子命令

### 1. `doctor`

用于采集当前机器的关键状态：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi14 doctor
```

它会检查：

- 内核版本
- PCIe 拓扑
- `kfd/amdgpu` 日志
- 指定 BDF 的 `amdgpu_firmware_info`
- `rocminfo`
- `rocm-smi`

也可以指定你的卡的 BDF：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi10 doctor --pci-bdf 0000:05:00.0
```

### 2. `backup-firmware`

备份当前 `Navi14` 固件：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi14 backup-firmware
```

也可以指定备份目录：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi10 backup-firmware --out /path/to/backup
```

### 3. `install-firmware-overlay`

把目标 ASIC 的新版固件覆盖到 `/lib/firmware/amdgpu/`，并重建 `initramfs`。

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi14 install-firmware-overlay
```

默认情况下，它会直接使用仓库内置的目标 ASIC 固件目录：

- `tools/assets/firmware/navi10/`
- `tools/assets/firmware/navi12/`
- `tools/assets/firmware/navi14/`

如果你要换成自己准备的固件目录，再显式指定：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi12 install-firmware-overlay --from /path/to/new-firmware-dir
```

指定目标内核：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi14 install-firmware-overlay \
  --from /path/to/new-firmware-dir \
  --kernel 6.8.0-107-generic
```

先只演练不真正写入：

```bash
./tools/rdna1-rocm-bootstrap.sh --asic navi10 install-firmware-overlay \
  --from /path/to/new-firmware-dir \
  --dry-run
```

### 4. `link-rocm7-arch`

给 `ROCm 7` 用户态补目标 `gfx101x` 架构的 `rocBLAS/Tensile` 文件：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch gfx1012 link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library
```

也支持先 dry-run：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch gfx1010 link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library \
  --dry-run
```

### 5. `print-build-rocm6`

打印这份项目里已经验证过的 `ROCm 6 + gfx101x` 构建命令：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch gfx1012 print-build-rocm6
```

### 6. `print-build-rocm7`

打印这份项目里已经验证过的 `ROCm 7 + gfx101x` 构建命令：

```bash
./tools/rdna1-rocm-bootstrap.sh --arch gfx1010 print-build-rocm7
```

对 `W5500 / gfx1012` 精确路线，也仍保留兼容别名：

```bash
./tools/w5500-rocm-bootstrap.sh link-rocm7-gfx1012 \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library
```

## 适合的使用顺序

建议顺序：

1. `doctor`
2. `backup-firmware`
3. `install-firmware-overlay`
4. 重启并重新 `doctor`
5. `link-rocm7-arch`
6. `print-build-rocm6` / `print-build-rocm7`

## 这套脚本解决的是什么

它不是替代文档，而是把文档里最容易出错、又最适合标准化的动作变成命令。

真正需要人做判断的部分仍然包括：

- 你是否要覆盖固件
- 你是否已经确认目标内核
- 你的卡实际 BDF 是多少
- 你的机器是否存在 PCIe 物理链路问题

所以这套脚本更适合被理解成：

> 一个可审计的 staged bootstrap helper，而不是一个盲目的一键黑盒。
