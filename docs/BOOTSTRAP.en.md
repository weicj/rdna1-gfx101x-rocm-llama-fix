# RDNA1 ROCm Bootstrap Command Guide

This repository provides a generic staged bootstrap helper for the broader `RDNA1 / Navi1x / gfx101x` family:

- [tools/rdna1-rocm-bootstrap.sh](../tools/rdna1-rocm-bootstrap.sh)

For the exact validated `W5500 / Navi14 / gfx1012` lane, a compatibility wrapper is also kept:

- [tools/w5500-rocm-bootstrap.sh](../tools/w5500-rocm-bootstrap.sh)

The repository bundles firmware overlays for the three ASIC groups covered by this project:

- [tools/assets/firmware/navi10](../tools/assets/firmware/navi10)
- [tools/assets/firmware/navi12](../tools/assets/firmware/navi12)
- [tools/assets/firmware/navi14](../tools/assets/firmware/navi14)

This is not a blind one-click installer. It is a staged helper intended to standardize the parts that can reasonably be automated.

Where placeholders appear below, replace them with the exact `ASIC` and `arch` of your own card. For example, a `W5700`-class path would use `navi10` and `gfx1010`, while the strongest validated sample in this repository used `navi14` and `gfx1012`.

## Supported Subcommands

### 1. `doctor`

Collect current host state:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> doctor
```

Optional explicit PCI BDF:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> doctor --pci-bdf <PCI_BDF>
```

### 2. `backup-firmware`

Back up the current target-ASIC firmware blobs:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> backup-firmware
```

Or specify the output directory:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> backup-firmware --out /path/to/backup
```

### 3. `install-firmware-overlay`

Install the bundled or externally provided firmware overlay for the selected ASIC and rebuild `initramfs`:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay
```

Use an external firmware directory explicitly:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay --from /path/to/new-firmware-dir
```

Target a specific kernel:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay \
  --kernel <KERNEL_VERSION>
```

Dry-run only:

```bash
./tools/rdna1-rocm-bootstrap.sh --asic <navi10|navi12|navi14> install-firmware-overlay --dry-run
```

### 4. `link-rocm7-arch`

Overlay the matching `gfx101x` `rocBLAS/Tensile` assets from the working ROCm 6 tree into a ROCm 7 userland prefix:

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library
```

Dry-run:

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> link-rocm7-arch \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library \
  --dry-run
```

Compatibility alias for the exact validated `W5500` path:

```bash
./tools/w5500-rocm-bootstrap.sh link-rocm7-gfx1012 \
  --rocm6-lib /opt/rocm-6.3.3/lib/rocblas/library \
  --rocm7-lib /path/to/rocm-7/lib/rocblas/library
```

### 5. `print-build-rocm6`

Print the validated `ROCm 6 + gfx101x` `llama.cpp` build command:

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> print-build-rocm6
```

### 6. `print-build-rocm7`

Print the validated `ROCm 7 + gfx101x` `llama.cpp` build command:

```bash
./tools/rdna1-rocm-bootstrap.sh --arch <gfx1010|gfx1011|gfx1012> print-build-rocm7
```

## Recommended Order

1. `doctor`
2. `backup-firmware`
3. `install-firmware-overlay`
4. reboot and run `doctor` again
5. `link-rocm7-arch`
6. `print-build-rocm6` / `print-build-rocm7`

## Practical Scope Note

This workflow is parameterized for:

- `navi10 / navi12 / navi14`
- `gfx1010 / gfx1011 / gfx1012`

So a `W5700` or `5600M` user can reuse the same staged structure.

What does not change is the evidence level:

- `W5500 / Navi14 / gfx1012` is still the strongest real validation sample in this repository
- the wider `RDNA1` family support here should be read as a generalized workflow, not as equal per-board proof

## What the Script Actually Solves

It does not replace the documentation.

It turns the most error-prone but standardizable steps into an executable interface.

Human judgment is still required for:

- deciding whether firmware overlay is appropriate
- selecting the correct kernel lane
- identifying the real PCI BDF
- deciding whether the machine has a physical PCIe problem

So the right description is:

> a staged bootstrap helper, not a blind one-click black box.
