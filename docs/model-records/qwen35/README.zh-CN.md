# Qwen3.5 记录

## 基本信息

- 官方底座 / 家族：`Qwen3.5`
- 实际测试文件：
  - `CoPaw-flash-9B-20260330-q4.gguf`
  - `omnicoder-9b-q4_k_m.gguf`
  - `squeez-2b.i1-Q4_K_M.gguf`
- 测试硬件：`Radeon Pro W5500 / gfx1012`
- ROCm 版本：
  - `ROCm 6.3.3`
  - `ROCm 7.2.1`

## 状态

- 当前状态：`已跑通`
- 当前结论：整体可用，但 ROCm 7 下需要特别关注某些 reasoning 线的可见 TTFT 异常

## 最终结果

- `CoPaw` / `ROCm 6`：
  - `C1 20.048 tok/s`
  - `TTFT 162.1 ms`
- `OmniCoder` / `ROCm 6`：
  - `C1 18.844 tok/s`
  - `TTFT 165.9 ms`
- `CoPaw` / `ROCm 7`：
  - `C1 22.292 tok/s`
  - `TTFT 3143.8 ms`
- `CoPaw budget=0 probe` / `ROCm 7`：
  - `C1 22.102 tok/s`
  - `TTFT 332.4 ms`
- `squeez-2b` / `ROCm 7`：
  - `prompt 70.10 tok/s`
  - `decode 56.36 tok/s`

## 关键问题

- ROCm 7 下主要问题不是吞吐，而是 reasoning / streaming 导致的可见首 token 过慢

## 结论

- Qwen3.5 这条基座已经证明 W5500 能承载从轻量到 9B 级的多条本地推理线
- 但其中不同子线的运行时行为差异很大，需要分开解释
