# Gemma 4 Record

## Basic Information

- Official base / model: `Gemma 4`
- Concrete tested file: `gemma-4-E2B-it-Q4_K_M.gguf`
- Test hardware: `Radeon Pro W5500 / gfx1012`
- ROCm versions:
  - `ROCm 6.3.3`
  - `ROCm 7.2.1`

## Status

- Current status: `stable`
- Current conclusion: this is the strongest and cleanest mainline base on W5500 so far

## Final Result

- `ROCm 6`:
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- `ROCm 7`:
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

## Key Issues

- `ROCm 7` was not drop-in; `gfx1012` `rocBLAS/Tensile` assets had to be overlaid first
- TTFT is not ultra-low, but the lane is operationally clean and strong

## Conclusion

- Gemma 4 is the best current W5500 mainline base to keep and improve further
