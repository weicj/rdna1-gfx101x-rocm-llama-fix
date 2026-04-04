# Qwen3.5 Record

## Basic Information

- Official base / family: `Qwen3.5`
- Concrete tested files:
  - `CoPaw-flash-9B-20260330-q4.gguf`
  - `omnicoder-9b-q4_k_m.gguf`
  - `squeez-2b.i1-Q4_K_M.gguf`
- Test hardware: `Radeon Pro W5500 / gfx1012`
- ROCm versions:
  - `ROCm 6.3.3`
  - `ROCm 7.2.1`

## Status

- Current status: `working`
- Current conclusion: broadly usable, but ROCm 7 visible-TTFT behavior must be interpreted carefully on some reasoning-tuned lines

## Final Result

- `CoPaw` / `ROCm 6`:
  - `C1 20.048 tok/s`
  - `TTFT 162.1 ms`
- `OmniCoder` / `ROCm 6`:
  - `C1 18.844 tok/s`
  - `TTFT 165.9 ms`
- `CoPaw` / `ROCm 7`:
  - `C1 22.292 tok/s`
  - `TTFT 3143.8 ms`
- `CoPaw budget=0 probe` / `ROCm 7`:
  - `C1 22.102 tok/s`
  - `TTFT 332.4 ms`
- `squeez-2b` / `ROCm 7`:
  - `prompt 70.10 tok/s`
  - `decode 56.36 tok/s`

## Key Issues

- On ROCm 7, the main failure mode was not throughput collapse
- The real issue was visible-TTFT regression caused by reasoning / streaming behavior on some lines

## Conclusion

- Qwen3.5 proves that W5500 can host multiple local lines spanning both lightweight and 9B-class deployment cases
- But not all sub-lines behave the same way, so they must be interpreted separately
