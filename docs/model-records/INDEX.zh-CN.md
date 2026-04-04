# W5500 模型运行记录索引

这个目录是给后续持续追加用的。

目的不是写成长报告，而是让人一眼看懂：

- 我们在 `W5500 / Navi14 / gfx1012` 上试过哪些模型
- 这些模型在哪个 `ROCm` 版本下跑
- 是否真正跑通
- 遇到了什么问题
- 最后结论是什么

以后每新增一个模型，只要照着同目录里的模板新建一份简短记录即可。

## 当前索引

| 记录文件 | 官方底座 / 模型 | 具体测试文件 | ROCm 通路 | 当前状态 | 备注 |
|---|---|---|---|---|---|
| [gemma-4/README.zh-CN.md](./gemma-4/README.zh-CN.md) | Gemma 4 | `gemma-4-E2B-it-Q4_K_M.gguf` | ROCm 6 / ROCm 7 | 已稳定跑通 | 当前 W5500 主基线 |
| [gemma-3n/README.zh-CN.md](./gemma-3n/README.zh-CN.md) | Gemma 3n | `UD-Q4_K_XL` / `Q4_K_M` | ROCm 6 | 已跑通 | 上下文与 TTFT 不如 Gemma 4 |
| [qwen35/README.zh-CN.md](./qwen35/README.zh-CN.md) | Qwen3.5 | `CoPaw` / `OmniCoder` / `squeez-2b` | ROCm 6 / ROCm 7 | 已跑通 | ROCm 7 下 reasoning 可见 TTFT 有异常 |
| [qwen3/README.zh-CN.md](./qwen3/README.zh-CN.md) | Qwen 3 | `MiniCPM-o-4_5-Q4_K_M.gguf` | ROCm 6 | 已跑通 | TTFT 很低，但纯文本 agent 质量一般 |
| [prismml-bonsai/README.zh-CN.md](./prismml-bonsai/README.zh-CN.md) | PrismML Bonsai-8B | `Bonsai-8B.gguf` | ROCm 7 + 专用补丁版 `llama.cpp` | 已跑通 | 特殊格式，单独修过 `Q1_0/Q1_0_g128` 路径 |

## 追加模板

- [TEMPLATE.zh-CN.md](./TEMPLATE.zh-CN.md)
