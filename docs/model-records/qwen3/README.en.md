# Qwen 3 Record

## Basic Information

- Official base / family: `Qwen 3`
- Concrete tested file: `MiniCPM-o-4_5-Q4_K_M.gguf`
- Test hardware: `Radeon Pro W5500 / gfx1012`
- ROCm version: `ROCm 6.3.3`

## Status

- Current status: `working`
- Current conclusion: low-TTFT sample exists, but it is not the strongest mainline deployment base

## Final Result

- `C1 23.444 tok/s`
- `TTFT 54.3 ms`

## Key Issues

- As a pure local text-agent line, quality did not pull far enough ahead to replace the Gemma mainline

## Conclusion

- This base was proven to run on W5500
- It is more useful as a low-TTFT reference sample than as the strongest long-term deployment choice
