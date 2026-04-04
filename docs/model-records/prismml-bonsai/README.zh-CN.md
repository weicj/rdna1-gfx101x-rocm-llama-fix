# PrismML Bonsai-8B 记录

## 基本信息

- 官方底座 / 模型：`PrismML Bonsai-8B`
- 实际测试文件：`Bonsai-8B.gguf`
- 测试硬件：`Radeon Pro W5500 / gfx1012`
- ROCm 版本：`ROCm 7.2.1`
- `llama.cpp` 路线：专用补丁版实验树

## 状态

- 当前状态：`已跑通`
- 当前结论：这是一个真实跑通的特殊格式案例，但不是 upstream 开箱即用

## 最初问题

- 直接加载时报：
  - `invalid ggml type 41`
- 后续又暴露：
  - `Q1_0 / Q1_0_g128` 路径缺符号
  - GPU weight placement 没真正选中
  - `MMVQ/MMQ` 快路径缺实现或不完整

## 我们实际做了什么

1. 在独立实验源码树中移植 `Q1_0 / Q1_0_g128`
2. 修 CPU 侧符号与 `get_rows` 分发
3. 修 GPU weight placement，让权重大头进 `W5500`
4. 先恢复稳定可回复的 GPU 路线
5. 再补 `Q1` 的 `MMQ/MMVQ` 快路径

## 关键阶段变化

- 早期状态：
  - `CPU_Mapped model buffer size = 1099.30 MiB`
  - `ROCm0 model buffer size = 1.18 MiB`
- 修复 GPU placement 后：
  - `CPU_Mapped model buffer size = 83.31 MiB`
  - `ROCm0 model buffer size = 1015.99 MiB`

## 最终结果

- 修后最小请求大约：
  - `prompt 108.40 tok/s`
  - `decode 65.99 tok/s`

## 结论

- Bonsai-8B 已经不是“理论上能启动”的状态，而是被真正推进到了 W5500 可运行状态
- 它的意义不在于代表主流支持，而在于证明特殊低比特格式也可以被单独打通
