# Gemma 4 记录

## 基本信息

- 官方底座 / 模型：`Gemma 4`
- 实际测试文件：`gemma-4-E2B-it-Q4_K_M.gguf`
- 测试硬件：`Radeon Pro W5500 / gfx1012`
- ROCm 版本：
  - `ROCm 6.3.3`
  - `ROCm 7.2.1`

## 状态

- 当前状态：`已稳定跑通`
- 当前结论：这是目前 W5500 上最强、最干净的主线基座

## 最终结果

- `ROCm 6`：
  - `C1 42.317 tok/s`
  - `TTFT 281.5 ms`
- `ROCm 7`：
  - `C1 43.890 tok/s`
  - `TTFT 258.6 ms`

## 关键问题

- `ROCm 7` 不是开箱即用，最初缺 `gfx1012` 的 `rocBLAS/Tensile` 数据
- TTFT 不算极低，但整体性能和任务能力最平衡

## 结论

- Gemma 4 是当前 W5500 主线最值得保留和继续优化的底座
