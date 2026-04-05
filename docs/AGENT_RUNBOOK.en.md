# Agent Runbook: Making RDNA1 / Navi1x / gfx101x GPUs Run Modern LLMs on ROCm 6 and ROCm 7

This runbook is intentionally procedural. It is written for autonomous agents, operator assistants, and engineers who need an execution order rather than a narrative explanation.

The strongest real-world validation in this repository still comes from `Radeon Pro W5500 / Navi14 / gfx1012`, but the workflow below is parameterized for the wider `RDNA1 / Navi1x / gfx101x` family.

## Goal

Bring a target `RDNA1 / Navi1x / gfx101x` GPU into a usable `ROCm` inference lane for modern LLM inference through `llama.cpp`, and clearly separate the `ROCm 6` path from the `ROCm 7` path.

## Scope Assumptions

- host class: older `Intel 5520/5500/X58`-style machine or another machine where RDNA1 ROCm support is not turnkey
- GPU: target `navi10`, `navi12`, or `navi14`
- arch: target `gfx1010`, `gfx1011`, or `gfx1012`
- you have `sudo`
- you are willing to reboot
- the workload target is `llama.cpp`, not general HIP development first

## Phase 1: Snapshot the Machine

### Step 1. Record PCIe topology and GPU state

```bash
lspci -nn | rg 'VGA|Display|Audio'
lspci -tv
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|atomics|navi1' -i
```

### Step 2. Record currently loaded amdgpu firmware info

```bash
sudo cat /sys/kernel/debug/dri/<PCI_BDF>/amdgpu_firmware_info
```

Focus on:

- `MEC`
- `MEC2`

In the strongest validated `navi14` case, the original blocker was:

- `MEC = 123`
- kernel log:
  - `kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145`

If your target ASIC shows the same class of failure, continue to the firmware phase.

## Phase 2: Raise the Effective Navi1x MEC Level

### Step 3. Back up current target-ASIC firmware blobs

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo mkdir -p /home/max/firmware-backups/<asic>-$TS
sudo cp -a /lib/firmware/amdgpu/<asic>_* /home/max/firmware-backups/<asic>-$TS/ 2>/dev/null || true
```

### Step 4. Install newer upstream `linux-firmware` overlays for the target ASIC

Use newer upstream `linux-firmware` blobs for your target ASIC (`navi10`, `navi12`, or `navi14`) and copy them into:

```text
/lib/firmware/amdgpu/
```

The field-tested pattern is:

- do **not** blindly destroy the distro payload
- place uncompressed `.bin` overlay files into `/lib/firmware/amdgpu/`
- rebuild initramfs afterward

### Step 5. Rebuild initramfs

```bash
sudo update-initramfs -u -k "$(uname -r)"
```

If you are targeting a specific kernel lane, rebuild for that kernel explicitly.

## Phase 3: Boot the Stable Kernel Lane

### Step 6. Prefer Linux `6.8` for the first stable ROCm 6 validation

On the strongest validated host, the meaningful split was:

- unstable/problematic lane: `6.17`
- first stable inference lane: `6.8`

After reboot, validate:

```bash
uname -r
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|atomics|navi1' -i
rocminfo | rg 'gfx101[0-2]|Agent'
```

Success criteria:

- `kfd ... added device ...`
- `rocminfo` shows the expected `gfx101x` arch
- `MEC` is no longer the rejected old value
- in the strongest validated `navi14` case, this value became `156`

## Phase 4: Validate ROCm 6 First

### Step 7. Confirm the ROCm 6 userland lane

On the strongest validated host, the first stable deployment lane was:

- `ROCm 6.3.3`
- `Linux 6.8`

Useful checks:

```bash
ldd /path/to/llama.cpp/build-rocm-<gfx101x>/bin/llama-server | rg 'hip|rocblas|hsa'
rocm-smi
rocminfo | rg 'gfx101[0-2]'
```

### Step 8. Build dedicated `gfx101x` llama.cpp for ROCm 6

Use the same flag structure for the whole `gfx101x` family and substitute your exact target arch:

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=<gfx101x>`
- `GPU_TARGETS=<gfx101x>`
- `CMAKE_HIP_ARCHITECTURES=<gfx101x>`
- `GGML_HIP_GRAPHS=ON`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

On the strongest validated sample in this repository, `<gfx101x>` resolved to `gfx1012`.

Representative command:

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

### Step 9. Smoke test the ROCm 6 lane

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

Then:

```bash
curl -fsS http://127.0.0.1:8101/v1/models
curl -fsS http://127.0.0.1:8101/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}],"temperature":0,"max_tokens":12}'
```

If this lane is stable, treat it as your baseline.

## Phase 5: Upgrade to ROCm 7 Carefully

### Step 10. Do not assume ROCm 7 is drop-in for `gfx101x`

On the strongest validated host, the first practical `ROCm 7.2.1` failure was:

- `rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012`

Interpretation:

- ROCm 7 userland existed
- the target `gfx101x` support was still incomplete in the installed `rocBLAS/Tensile` payload

### Step 11. Create a ROCm 7 linkroot / overlay

Recommended pattern:

- keep a writable ROCm 7 userland prefix
- graft the target-arch `gfx101x` `rocBLAS/Tensile` assets from the working ROCm 6 install

Representative command:

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

In the strongest validated `gfx1012` field run, `56` new symlinks were added.

### Step 12. Build a dedicated ROCm 7 binary for the target `gfx101x` ASIC

Use the same `gfx101x` placeholder structure as the ROCm 6 lane, but point the build at the ROCm 7 userland/toolchain for your exact target arch.

On the strongest validated sample in this repository, `<gfx101x>` again resolved to `gfx1012`.

Representative command:

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

### Step 13. Validate the ROCm 7 lane with a clean model first

Use a clean official base model first. `Gemma 4 E2B Q4` was the best positive sample on the strongest validated host.

Expected direction from the strongest validated field result:

- ROCm 6:
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- ROCm 7:
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

If your ROCm 7 lane does not at least land in that direction, inspect:

- wrong userland prefix
- missing target-arch Tensile files
- wrong runtime linker search path

## Phase 6: Interpret TTFT Correctly

### Step 14. Separate backend latency from visible-token latency

If a reasoning-capable model shows bad TTFT on ROCm 7:

- do **not** immediately conclude that HIP became slower
- rerun with reasoning disabled or budget forced to zero

### Step 15. Treat validated `gfx1012` samples as reference points, not universal guarantees

The repository's strongest performance and deployment conclusions still come from:

- `W5500`
- `Navi14`
- `gfx1012`

That does **not** invalidate the broader `RDNA1` workflow.

It only means:

- the workflow is generalized
- the evidence level is still strongest on the exact validated lane

## Troubleshooting Tree

### Case A. the target RDNA1 card still does not appear in `rocminfo`

Check:

1. `lspci -nn`
2. `journalctl -k -b | rg -n 'kfd|atomics|navi1' -i`
3. `amdgpu_firmware_info`

### Case B. ROCm 7 fails immediately

Look for:

- `rocBLAS error`
- missing `TensileLibrary.dat`
- target `gfx101x` arch not found

### Case C. Throughput is fine but TTFT is bad

Check:

- reasoning behavior
- visible token behavior
- cache reuse behavior
- prompt length

### Case D. Card vanishes after reboot

Treat it as a PCIe/topology problem first, not as a pure ROCm problem first.

## Final Recommendation

- First bring up `ROCm 6.3.3 + Linux 6.8`
- Then layer `ROCm 7`
- Treat `W5500 / Navi14 / gfx1012` as the strongest validated sample
- Treat the wider `RDNA1 / Navi1x / gfx101x` support as a generalized workflow with uneven evidence depth
