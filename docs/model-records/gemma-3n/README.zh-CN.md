# Gemma 3n 记录

## 基本信息

- 官方底座 / 模型：`Gemma 3n`
- 实际测试文件：
  - `gemma-3n-E4B-it-UD-Q4_K_XL.gguf`
  - `gemma-3n-E4B-it-Q4_K_M.gguf`
- 测试硬件：`Radeon Pro W5500 / gfx1012`
- ROCm 版本：`ROCm 6.3.3`

## 状态

- 当前状态：`已跑通`
- 当前结论：可以稳定运行，但综合不如最强的 Gemma 4 路线

## 最终结果

- `UD-Q4_K_XL`：
  - `C1 23.341 tok/s`
  - `TTFT 416.9 ms`
- `Q4_K_M`：
  - `C1 22.794 tok/s`
  - `TTFT 419.9 ms`

## 关键问题

- 更强的那个量化版本上下文太小
- 两条线的 TTFT 都明显慢于 Gemma 4

## 结论

- Gemma 3n 这条基座已经被证明可以在 W5500 + ROCm 6 上稳定运行
- 但它更适合作为次选，而不是主线
