# Agent Runbook: Making W5500 Run Modern LLMs on ROCm 6 and ROCm 7

This runbook is intentionally procedural. It is written for an autonomous agent, a deployment assistant, or an operations engineer who needs an execution order instead of a narrative explanation.

## Goal

Bring `AMD Radeon Pro W5500 (Navi14 / gfx1012)` into a usable `ROCm` inference lane for modern LLM inference, validate it with `llama.cpp`, and clearly separate the `ROCm 6` path from the `ROCm 7` path.

## Scope Assumptions

- Host class: older `Intel 5520/5500/X58`-style machine or another machine where `gfx1012` is not turnkey
- GPU: `W5500`, PCI ID `1002:7341`
- You have `sudo`
- You are willing to reboot
- Your target workload is `llama.cpp`, not generic HIP development first

## Phase 1: Snapshot The Machine Before Changing Anything

### Step 1. Record PCIe topology and GPU state

```bash
lspci -nn | rg '7341|VGA|Display|Audio'
lspci -tv
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|7341|atomics|navi14' -i
```

### Step 2. Record currently loaded amdgpu firmware info

```bash
sudo cat /sys/kernel/debug/dri/0000:05:00.0/amdgpu_firmware_info
```

You are looking for the effective `MEC` and `MEC2` firmware versions. The original failing case was:

- `MEC = 123`
- kernel log:
  - `kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145`

If you see that class of error, continue to the firmware phase.

## Phase 2: Raise The Effective Navi14 MEC Firmware Level

### Step 3. Back up current `Navi14` firmware blobs

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo mkdir -p /home/max/firmware-backups/navi14-$TS
sudo cp -a /lib/firmware/amdgpu/navi14_* /home/max/firmware-backups/navi14-$TS/ 2>/dev/null || true
```

### Step 4. Install newer upstream `linux-firmware` `navi14_*.bin` overlays

Use newer upstream `linux-firmware` `navi14_*.bin` files and copy them into:

```text
/lib/firmware/amdgpu/
```

The field-tested pattern was:

- do **not** remove the distro package payload permanently
- place uncompressed `.bin` overlay files in `/lib/firmware/amdgpu/`
- rebuild initramfs afterward

### Step 5. Rebuild initramfs

```bash
sudo update-initramfs -u -k "$(uname -r)"
```

If you plan to switch kernels explicitly, rebuild for the target kernel as well.

## Phase 3: Boot The Stable Kernel Lane

### Step 6. Prefer Linux `6.8` for the first stable ROCm 6 validation

This machine had a meaningful stability difference between:

- unstable/problematic lane: `6.17`
- stable validation lane: `6.8`

After reboot, validate:

```bash
uname -r
sudo journalctl -k -b 0 | rg -n 'kfd|amdgpu|7341|atomics|navi14' -i
rocminfo | rg 'gfx1012|W5500|Agent'
```

Success criteria:

- `kfd ... added device 1002:7341`
- `rocminfo` shows `gfx1012`
- `MEC` is no longer `123`; in the successful field result it became `156`

## Phase 4: Validate ROCm 6 First

### Step 7. Confirm the ROCm 6 userland lane

The first stable deployment lane on this host was:

- `ROCm 6.3.3`
- `Linux 6.8`

Useful checks:

```bash
ldd /home/max/src/llama.cpp-upstream/build-rocm-gfx1012/bin/llama-server | rg 'hip|rocblas|hsa'
rocm-smi
rocminfo | rg 'gfx1012'
```

### Step 8. Build dedicated `gfx1012` llama.cpp for ROCm 6

Field-tested cache values from the working build:

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=gfx1012`
- `CMAKE_HIP_ARCHITECTURES=gfx1012`
- `GGML_HIP_GRAPHS=ON`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

Representative build command:

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

### Step 9. Smoke test the ROCm 6 lane

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

Then:

```bash
curl -fsS http://127.0.0.1:8101/v1/models
curl -fsS http://127.0.0.1:8101/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}],"temperature":0,"max_tokens":12}'
```

If this lane is stable, treat it as your baseline.

## Phase 5: Upgrade To ROCm 7 Carefully

### Step 10. Do not assume ROCm 7 is drop-in for `gfx1012`

The first practical `ROCm 7.2.1` failure on `W5500` was:

- `rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012`

Interpretation:

- ROCm 7 userland existed
- `gfx1012` support was still incomplete in the installed `rocBLAS/Tensile` payload

### Step 11. Create a ROCm 7 linkroot / overlay

Field-tested idea:

- keep a writable ROCm 7 userland prefix
- graft `gfx1012`-related `rocBLAS/Tensile` assets from the working ROCm 6 install

Representative command pattern:

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

In the field run, `56` new symlinks were added.

### Step 12. Build a dedicated ROCm 7 binary for `gfx1012`

For this repository, keep the ROCm 7 instructions focused on `W5500 / gfx1012` only.

Field-tested cache values for the dedicated `gfx1012` lane should mirror the ROCm 6 logic, but use the ROCm 7 userland/toolchain:

- `GGML_HIP=ON`
- `CMAKE_BUILD_TYPE=Release`
- `AMDGPU_TARGETS=gfx1012`
- `GPU_TARGETS=gfx1012`
- `CMAKE_HIP_ARCHITECTURES=gfx1012`
- `GGML_HIP_MMQ_MFMA=ON`
- `GGML_HIP_NO_VMM=ON`
- `GGML_HIP_ROCWMMA_FATTN=OFF`

Representative command:

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

### Step 13. Validate the ROCm 7 lane with a clean model first

Use a clean official base model first. `Gemma 4 E2B Q4` was the best positive sample on this host.

Expected direction from the field result:

- ROCm 6:
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- ROCm 7:
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

If your ROCm 7 lane does not at least land in that direction, inspect:

- wrong userland prefix
- missing `gfx1012` Tensile files
- wrong runtime linker search path

## Phase 6: Interpret TTFT Correctly

### Step 14. Separate backend latency from visible-token latency

If a reasoning-capable model shows bad TTFT on ROCm 7:

- do **not** immediately conclude that HIP became slower
- rerun with reasoning disabled or budget forced to zero

This was mandatory for a `Qwen3.5-derived 9B` reasoning-capable fine-tune line:

- default ROCm 7: `C1 22.292 tok/s`, `TTFT 3143.8 ms`
- `budget=0` probe: `C1 22.102 tok/s`, `TTFT 332.4 ms`

Interpretation:

- throughput improved
- visible-TTFT regression came from reasoning/stream behavior

### Step 15. Expect Gemma-family cache behavior to differ

If logs show:

- `forcing full prompt re-processing due to lack of cache data`

and the message references:

- `SWA`
- `hybrid memory`
- `recurrent memory`

then TTFT is being influenced by model/runtime cache behavior, not just by the GPU backend.

## Phase 7: Troubleshooting Tree

### Case A. `W5500` still does not appear in `rocminfo`

Check:

1. `lspci -nn | rg 7341`
2. `journalctl -k -b | rg -n '7341|kfd|atomics' -i`
3. `amdgpu_firmware_info`

Likely causes:

- card not enumerated at PCIe level
- old `MEC` version still loaded
- wrong kernel lane

### Case B. HIP / llama.cpp launches but ROCm 7 fails immediately

Check logs for:

- `rocBLAS error`
- missing `TensileLibrary.dat`
- `GPU arch : gfx1012`

Likely cause:

- ROCm 7 userland missing `gfx1012` rocBLAS/Tensile assets

### Case C. Throughput is fine but TTFT is absurd

Check:

- reasoning budget
- visible token behavior
- cache reuse behavior
- whether your prompt has already ballooned into a very long session context

### Case D. Card vanishes after reboot

Treat it as a PCIe/topology problem first, not a ROCm problem first.

Check:

- cold boot versus warm reboot
- reseat / contact
- link retraining
- whether the link has fallen back to `2.5 GT/s x4`

## Final Recommendation

- First bring up `ROCm 6.3.3 + Linux 6.8`
- Only then layer `ROCm 7`
- Treat `ROCm 7` as a second-stage compatibility and performance project, not as the first bring-up lane
- Publish the field guide as a standalone repository first
- Only open a `llama.cpp` fork later if the source patch delta becomes large and durable

## Appendix: Experimental Quantization Path

If the target model uses an unusual low-bit layout such as `Q1_0 / Q1_0_g128`, do **not** treat it as part of the baseline ROCm bring-up.

Treat it as a separate engineering track.

Recommended execution order:

1. Confirm the standard ROCm lane already works with a clean official base model.
2. Move the custom quantization work into an isolated experimental source tree.
3. Fix load-time type recognition first.
4. Fix CPU-side symbol coverage and dispatch next.
5. Fix GPU weight placement next.
6. Only after the model runs stably, restore or implement the relevant `MMQ/MMVQ` fast paths.
7. Measure again and explicitly distinguish:
   - “starts but mostly CPU-mapped”
   - “really runs on GPU”

This distinction mattered in practice. The experimental `Q1` 8B line only became interesting after GPU placement and fast-path recovery, at which point minimal-request performance reached roughly:

- `prompt 108.40 tok/s`
- `decode 65.99 tok/s`
