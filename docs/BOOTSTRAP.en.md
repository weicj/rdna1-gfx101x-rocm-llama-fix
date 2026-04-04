# W5500 ROCm Bootstrap Command Guide

This repository now includes a single entrypoint helper script:

- [tools/w5500-rocm-bootstrap.sh](../tools/w5500-rocm-bootstrap.sh)

The repository also bundles the `Navi14` firmware overlay files used by the documented bring-up path:

- [tools/assets/firmware/navi14](../tools/assets/firmware/navi14)

Its purpose is not to pretend that W5500 ROCm bring-up can be solved by a blind magic button.

Its purpose is to standardize the parts that really can be automated.

## Why this is not a fake “one-click success” button

Because some steps still require judgment:

- firmware overlay is a high-impact operation
- `initramfs` rebuild and reboot need operator awareness
- some PCIe enumeration failures are not purely software problems

So the more professional approach is:

- one script entrypoint
- several auditable subcommands
- clear separation between diagnostics, firmware work, ROCm 7 overlay, and build steps

## Supported Subcommands

### 1. `doctor`

Collect current host state:

```bash
./tools/w5500-rocm-bootstrap.sh doctor
```

This checks:

- kernel version
- PCIe topology
- `kfd/amdgpu` logs
- `amdgpu_firmware_info` for the selected BDF
- `rocminfo`
- `rocm-smi`

You can also specify the PCI BDF explicitly:

```bash
./tools/w5500-rocm-bootstrap.sh doctor --pci-bdf 0000:05:00.0
```

### 2. `backup-firmware`

Back up the current `Navi14` firmware blobs:

```bash
./tools/w5500-rocm-bootstrap.sh backup-firmware
```

Or choose the output directory explicitly:

```bash
./tools/w5500-rocm-bootstrap.sh backup-firmware --out /path/to/backup
```

### 3. `install-firmware-overlay`

Install newer `navi14_*.bin` overlays into `/lib/firmware/amdgpu/` and rebuild `initramfs`:

```bash
./tools/w5500-rocm-bootstrap.sh install-firmware-overlay
```

By default, this uses the bundled repository firmware in:

- `tools/assets/firmware/navi14/`

If you want to use a different directory explicitly:

```bash
./tools/w5500-rocm-bootstrap.sh install-firmware-overlay --from /path/to/new-firmware-dir
```

Target a specific kernel:

```bash
./tools/w5500-rocm-bootstrap.sh install-firmware-overlay \
  --from /path/to/new-firmware-dir \
  --kernel 6.8.0-107-generic
```

Dry-run only:

```bash
./tools/w5500-rocm-bootstrap.sh install-firmware-overlay \
  --from /path/to/new-firmware-dir \
  --dry-run
```

### 4. `link-rocm7-gfx1012`

Overlay `gfx1012` `rocBLAS/Tensile` assets from the working ROCm 6 tree into a ROCm 7 userland prefix:

```bash
./tools/w5500-rocm-bootstrap.sh link-rocm7-gfx1012 \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library
```

Dry-run version:

```bash
./tools/w5500-rocm-bootstrap.sh link-rocm7-gfx1012 \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /home/max/rocm-7.2.1-linkroot/rocm-7.2.1/lib/rocblas/library \
  --dry-run
```

### 5. `print-build-rocm6`

Print the validated `ROCm 6 + gfx1012` `llama.cpp` build command:

```bash
./tools/w5500-rocm-bootstrap.sh print-build-rocm6
```

### 6. `print-build-rocm7`

Print the validated `ROCm 7 + gfx1012` `llama.cpp` build command:

```bash
./tools/w5500-rocm-bootstrap.sh print-build-rocm7
```

## Recommended Order

1. `doctor`
2. `backup-firmware`
3. `install-firmware-overlay`
4. reboot and run `doctor` again
5. `link-rocm7-gfx1012`
6. `print-build-rocm6` / `print-build-rocm7`

## What this script actually solves

It does not replace the documentation.

It turns the most error-prone but standardizable steps into an executable interface.

Human judgment is still required for:

- deciding whether firmware overlay is appropriate
- selecting the correct kernel lane
- identifying the real PCI BDF
- deciding whether the machine has a physical PCIe problem

So the right way to describe this helper is:

> a staged bootstrap helper, not a blind one-click black box.
