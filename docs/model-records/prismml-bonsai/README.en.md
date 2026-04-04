# PrismML Bonsai-8B Record

## Basic Information

- Official base / model: `PrismML Bonsai-8B`
- Concrete tested file: `Bonsai-8B.gguf`
- Test hardware: `Radeon Pro W5500 / gfx1012`
- ROCm version: `ROCm 7.2.1`
- `llama.cpp` lane: dedicated patched experimental tree

## Status

- Current status: `working`
- Current conclusion: this is a real bring-up success, but it is not upstream-ready baseline support

## Initial Failure Mode

- direct load failed with:
  - `invalid ggml type 41`
- later issues exposed:
  - incomplete `Q1_0 / Q1_0_g128` symbol coverage
  - GPU weight placement not actually selected
  - missing or incomplete `MMVQ/MMQ` fast paths

## What Was Actually Done

1. Port `Q1_0 / Q1_0_g128` into an isolated experimental source tree
2. Fix CPU-side symbol coverage and `get_rows` dispatch
3. Fix GPU weight placement so the large weight buffers move onto W5500
4. Restore a stable GPU execution path first
5. Then repair the `Q1` `MMQ/MMVQ` fast path

## Key Milestones

- early state:
  - `CPU_Mapped model buffer size = 1099.30 MiB`
  - `ROCm0 model buffer size = 1.18 MiB`
- after GPU placement repair:
  - `CPU_Mapped model buffer size = 83.31 MiB`
  - `ROCm0 model buffer size = 1015.99 MiB`

## Final Result

- after the repaired path:
  - `prompt 108.40 tok/s`
  - `decode 65.99 tok/s`

## Conclusion

- Bonsai-8B was not merely “able to start”
- it was pushed into a state where W5500 really carried the model
- its value is as a source-level engineering case for unusual low-bit formats, not as evidence of baseline upstream support
