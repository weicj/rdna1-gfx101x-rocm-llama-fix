[English](./README.md) | [简体中文](./README.zh-CN.md)

# RDNA1 / Navi14 / gfx101x Modern LLM Inference on ROCm with llama.cpp

![RDNA1-gfx101x](https://img.shields.io/badge/RDNA1-gfx101x-blue)
![ROCm-6.3%2B%20%7C%207%2B](https://img.shields.io/badge/ROCm-6.3%2B%20%7C%207%2B-red)
![LLM-llama.cpp](https://img.shields.io/badge/LLM-llama.cpp-orange)
![License-Apache%202.0](https://img.shields.io/badge/License-Apache%202.0-green)

This repository documents a practical engineering goal:

make `RDNA1 / Navi14 / gfx101x` GPUs run modern large language models on `ROCm 6` and `ROCm 7` through `llama.cpp`, even on a host platform that is not a clean vendor-supported reference system.

This is not a generic ROCm tutorial. It is a field-tested record of what had to be fixed, what actually worked, what still breaks, and what performance level was realistically achieved.

Real-world validation in this repository was performed primarily on `Radeon Pro W5500`, i.e. `Navi14 / gfx1012`. So while the project scope is broader than a single SKU, the concrete validation data is anchored in a real `W5500` deployment.

## Target Hardware Family

The method documented here is meant for the `RDNA1 / Navi14 / gfx101x` discrete GPU family.

The strongest confidence is on the exact tested lane, namely `Radeon Pro W5500 / Navi14 / gfx1012`.

The broader family scope is summarized here:

| ASIC / arch | Typical cards this project is most relevant to | Confidence level |
|---|---|---|
| `gfx1010 / Navi10` | `Radeon RX 5600 XT`, `Radeon RX 5700`, `Radeon RX 5700 XT`, `Radeon Pro W5700`, `Radeon Pro W5700X`, `Radeon Pro V520`, some `5600M/5700M` mobile derivatives | theoretical family relevance; not validated here |
| `gfx1011 / Navi12` | `Radeon Pro 5600M` and closely related Navi12 derivatives | theoretical family relevance; not validated here |
| `gfx1012 / Navi14` | `Radeon RX 5300`, `Radeon RX 5500`, `Radeon RX 5500 XT`, `Radeon Pro W5500`, `Radeon Pro W5500X`, `Radeon Pro 5300M`, `Radeon Pro 5500M`, `Radeon RX 5300M`, `Radeon RX 5500M` | closest match; real project validation was done on `W5500 / gfx1012` |

If you are not on `Navi14 / gfx1012`, treat this repository as an architectural reference rather than a guarantee.

## Validation Scope and Risk Statement

This is a personal field project, not a vendor support statement.

The real validation environment behind the documented results was primarily:

- `Mac Pro 5,1`
- `OpenCore`
- `Ubuntu`
- `Radeon Pro W5500`

That is why the project may be useful to other people fighting similar `RDNA1 / Navi14 / gfx101x` bring-up problems.

It is also why the right reading is:

- tested in a real but highly specific environment
- likely relevant to similar cards in the same architectural family
- not guaranteed across every board, firmware, bridge, kernel, or PCIe topology

Use it as a strong field reference, not as a blanket certification. Use at your own risk.

## Entry Tooling

This project is no longer just a stack of notes.

It now includes a staged local bootstrap toolkit that standardizes the highest-risk parts of the bring-up flow:

- Bootstrap script: [`tools/w5500-rocm-bootstrap.sh`](./tools/w5500-rocm-bootstrap.sh)
- Tool layout notes: [tools/README.md](./tools/README.md)
- Bundled firmware assets: [`tools/assets/firmware/navi14`](./tools/assets/firmware/navi14)
- English bootstrap guide: [docs/BOOTSTRAP.en.md](./docs/BOOTSTRAP.en.md)

This tooling is intentionally not a reckless “one-click miracle”.

It is a staged, auditable interface with commands such as:

- `doctor`
- `backup-firmware`
- `install-firmware-overlay`
- `link-rocm7-gfx1012`
- `print-build-rocm6`
- `print-build-rocm7`

The critical `Navi14` firmware overlay files are now bundled in the repository, so the firmware portion of the flow can be completed locally without requiring a network fetch during the bring-up itself.

## Documents

- Agent runbook: [docs/AGENT_RUNBOOK.en.md](./docs/AGENT_RUNBOOK.en.md)
- Bootstrap guide: [docs/BOOTSTRAP.en.md](./docs/BOOTSTRAP.en.md)
- Per-model run records: [docs/model-records/INDEX.en.md](./docs/model-records/INDEX.en.md)
- Hardware scope and tested environment: [docs/HARDWARE_SCOPE.en.md](./docs/HARDWARE_SCOPE.en.md)
- License: [LICENSE](./LICENSE)

## Agent-Readable Workflow

This repository also includes agent-readable workflow documents for CLI agents and operator assistants, including tools such as:

- `Claude Code`
- `Codex`
- `Gemini CLI`

The main machine-readable / agent-readable entrypoints are:

- [docs/AGENT_RUNBOOK.en.md](./docs/AGENT_RUNBOOK.en.md)
- [docs/BOOTSTRAP.en.md](./docs/BOOTSTRAP.en.md)
- [docs/model-records/INDEX.en.md](./docs/model-records/INDEX.en.md)

## Project Goal

The point of this project was not “getting ROCm to print `gfx1012` once”.

The point was to move a real `RDNA1 / Navi14 / gfx101x` card, validated primarily on `W5500`, through the following stages:

1. From unsupported or effectively unusable state
2. Into a real `KFD/ROCm` inference lane
3. Into a stable `llama.cpp` deployment path
4. Into a state where recent model families could actually be served, measured, compared, and judged for real deployment

## Core Findings

- The critical gate was not model support first. It was getting the card accepted by `KFD`.
- On this host, the decisive firmware change was raising the effective `Navi14 WKS MEC` version from `123` to `156`.
- `ROCm 6.3.3 + Linux 6.8` was the first stable inference lane for this machine.
- `ROCm 7.2.1` also worked, but not out of the box: `gfx1012`-related `rocBLAS/Tensile` assets had to be grafted from the ROCm 6 tree into the ROCm 7 userland prefix.
- After bring-up, the real validation host `W5500` was able to run multiple modern model families with repeatable deployment-grade results.

## What Had To Be Solved

### 1. `KFD` admission

The original blocker on this legacy non-atomics platform was:

```text
kfd kfd: amdgpu: skipped device 1002:7341, PCI rejects atomics 123<145
```

The decisive fix was not a userspace package change. It was making sure the card actually loaded newer `Navi14` firmware so that the effective `MEC` level crossed the kernel-side threshold.

### 2. Stable kernel lane

On this host, kernel choice mattered.

- `Linux 6.17` was not the stable lane for `W5500`
- `Linux 6.8` was the first kernel line that yielded a stable ROCm 6 inference path

### 3. ROCm 7 compatibility gap

The first ROCm 7 failure on `W5500` was not a performance regression. It was an incomplete `gfx1012` userspace stack:

```text
rocBLAS error: Cannot read ... TensileLibrary.dat ... GPU arch : gfx1012
```

This was solved by overlaying `gfx1012` `rocBLAS/Tensile` assets from the working ROCm 6 installation into the ROCm 7 userland prefix.

### 4. `llama.cpp` validation

After the firmware, kernel, and userspace path were stable, `llama.cpp` became the practical validation target. Both ROCm 6 and ROCm 7 were used to verify whether `W5500` could serve real models rather than simply enumerate in system tooling.

## Verified Base Families on Real W5500 Hardware

| Official base / family | ROCm lane(s) validated | Current status | Short conclusion |
|---|---|---|---|
| Gemma 4 | ROCm 6 / ROCm 7 | stable | strongest clean W5500 baseline so far |
| Gemma 3n | ROCm 6 | stable | works cleanly, but weaker than the best Gemma 4 path |
| Qwen3.5 | ROCm 6 / ROCm 7 | stable with caveats | broad family runs, but ROCm 7 visible-TTFT behavior must be interpreted carefully |
| Qwen 3 | ROCm 6 | stable | low-TTFT text-only sample exists, but it is not the strongest deployment line |
| PrismML Bonsai-8B | ROCm 7 + patched `llama.cpp` | special-case success | validated only after dedicated source-level bring-up |

## Validated Files by Base

### Gemma 4

- `gemma-4-E2B-it-Q4_K_M.gguf`

### Gemma 3n

- `gemma-3n-E4B-it-UD-Q4_K_XL.gguf`
- `gemma-3n-E4B-it-Q4_K_M.gguf`

### Qwen3.5

- `CoPaw-flash-9B-20260330-q4.gguf`
- `omnicoder-9b-q4_k_m.gguf`
- `squeez-2b.i1-Q4_K_M.gguf`

### Qwen 3

- `MiniCPM-o-4_5-Q4_K_M.gguf`

### PrismML Bonsai-8B

- `Bonsai-8B.gguf`

## Model Behavior Analysis

Some of the most important findings in this project were not simple pass/fail results, but model-specific behavior that had to be interpreted correctly.

### 1. Why Gemma-family TTFT could still look slow

`Gemma 3n` and `Gemma 4` often showed higher TTFT than smaller Qwen-derived lines, but the strongest observed reason was not raw HIP underperformance.

The logs repeatedly showed prompt-cache reuse limits around:

- `forcing full prompt re-processing due to lack of cache data`
- references to `SWA`
- references to `hybrid` or `recurrent memory`

That is a runtime behavior issue, not simply a backend issue. In practice it means Gemma can remain excellent on structured tasks and overall throughput while still not being the best absolute first-token-latency line.

### 2. Why a Qwen3.5-derived 9B line showed visible-TTFT anomalies on ROCm 7

The ROCm 7 `CoPaw` result was the clearest example of why user-visible TTFT must be interpreted carefully.

The data looked like this:

- default reasoning path:
  - `C1 22.292 tok/s`
  - `TTFT 3143.8 ms`
- `budget=0` probe:
  - `C1 22.102 tok/s`
  - `TTFT 332.4 ms`

The conclusion is straightforward:

- throughput improved
- visible TTFT regressed
- the regression came from reasoning/stream semantics, not from raw ROCm 7 compute collapse

### 3. How Bonsai-8B was brought up despite its unusual format

This is a separate case because it was not just “another model”.

`Bonsai-8B.gguf` used an unusual low-bit format that upstream `llama.cpp` did not treat as a normal production-ready path. The early state was not “slow but working”; the early state was “cannot load cleanly, or loads into a mostly useless path”.

Representative failure class:

- `invalid ggml type 41`

What was actually required was a dedicated source tree and a staged repair:

1. Port `Q1_0 / Q1_0_g128` support into an isolated `llama.cpp` tree
2. Fix CPU-side symbol coverage and dispatch
3. Fix GPU weight placement so the model was no longer mostly left in `CPU_Mapped`
4. First restore a stable GPU execution path
5. Then restore the `Q1` `MMQ/MMVQ` fast path properly

Those steps mattered in sequence:

- first the model had to be recognized
- then backend dispatch had to stop failing
- then the weight buffers had to move onto the GPU
- then the runtime had to become stable
- only after that did it make sense to recover the fast quantized path

The important public conclusion is not “upstream supports this format now”. The important conclusion is:

- an unusual low-bit 8B quantization format was successfully brought onto W5500
- and after the GPU path was repaired, minimal-request performance reached approximately:
  - `prompt 108.40 tok/s`
  - `decode 65.99 tok/s`

That makes it a valuable engineering case study, even though it should still be treated as a special-format case rather than baseline support.
