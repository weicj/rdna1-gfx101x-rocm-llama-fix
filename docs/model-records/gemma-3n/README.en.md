# Gemma 3n Record

## Basic Information

- Official base / model: `Gemma 3n`
- Concrete tested files:
  - `gemma-3n-E4B-it-UD-Q4_K_XL.gguf`
  - `gemma-3n-E4B-it-Q4_K_M.gguf`
- Test hardware: `Radeon Pro W5500 / gfx1012`
- ROCm version: `ROCm 6.3.3`

## Status

- Current status: `working`
- Current conclusion: stable, but not as strong as the best Gemma 4 lane

## Final Result

- `UD-Q4_K_XL`:
  - `C1 23.341 tok/s`
  - `TTFT 416.9 ms`
- `Q4_K_M`:
  - `C1 22.794 tok/s`
  - `TTFT 419.9 ms`

## Key Issues

- The stronger variant was constrained by short context
- Both lines had meaningfully slower TTFT than the strongest Gemma 4 path

## Conclusion

- Gemma 3n was proven to run cleanly on W5500 + ROCm 6
- It is a valid base, but not the strongest final deployment choice
