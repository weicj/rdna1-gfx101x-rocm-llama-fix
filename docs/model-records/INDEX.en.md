# W5500 Model Run Record Index

This directory is designed to grow over time.

Its purpose is simple:

- show which models were tested on `W5500 / Navi14 / gfx1012`
- show under which `ROCm` version they ran
- show whether they really worked
- show what broke
- show the final operational conclusion

Whenever a new model is validated, add one short record file and one new row here.

## Current Index

| Record file | Official base / model | Concrete tested file | ROCm lane | Current status | Notes |
|---|---|---|---|---|---|
| [gemma-4/README.en.md](./gemma-4/README.en.md) | Gemma 4 | `gemma-4-E2B-it-Q4_K_M.gguf` | ROCm 6 / ROCm 7 | Stable | Current main W5500 baseline |
| [gemma-3n/README.en.md](./gemma-3n/README.en.md) | Gemma 3n | `UD-Q4_K_XL` / `Q4_K_M` | ROCm 6 | Working | Context and TTFT are weaker than Gemma 4 |
| [qwen35/README.en.md](./qwen35/README.en.md) | Qwen3.5 | `CoPaw` / `OmniCoder` / `squeez-2b` | ROCm 6 / ROCm 7 | Working | ROCm 7 exposed visible-TTFT anomalies on the reasoning path |
| [qwen3/README.en.md](./qwen3/README.en.md) | Qwen 3 | `MiniCPM-o-4_5-Q4_K_M.gguf` | ROCm 6 | Working | Very low TTFT, but weaker as a pure text agent |
| [prismml-bonsai/README.en.md](./prismml-bonsai/README.en.md) | PrismML Bonsai-8B | `Bonsai-8B.gguf` | ROCm 7 + patched `llama.cpp` | Working | Special-case format; required dedicated `Q1_0/Q1_0_g128` support |

## Template

- [TEMPLATE.en.md](./TEMPLATE.en.md)
