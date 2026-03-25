# FPGA-Based Spectrum Analyzer with CZT

本项目是一个基于 **FPGA** 的实时频谱分析仪设计，核心算法采用了 **线性调频 Z 变换（Chirp-Z Transform, CZT）**。相比于传统的 FFT，CZT 能够提供更灵活的频谱分辨率，适用于需要对特定频率段进行高精度细分的场景。

## 📂 项目结构
```text
├── src/                    # verilog 源码文件夹
│   ├── sim/                # 仿真文件夹
│   │   ├── cosfile_coe_gen.m   # coe 文件生成脚本
│   │   ├── sin_wave_2048x8.coe # coe 文件（仿真用）
│   │   └── testbench.sv        # 项目仿真测试平台
│   ├── constraints/        # 约束文件夹
│   │   ├── pin.xdc             # 管脚分配约束
│   │   └── timing.xdc          # 时序约束
│   ├── top_design.v        # 顶层模块
│   ├── thinning_czt.v      # czt 频谱细化模块（由矩阵键盘单次触发）
│   ├── rough_calc.v        # 频谱粗测模块（实时运行）
│   ├── chirp_gen_1.v       # chirp 信号生成模块1，根据传入的相位增量和相位便宜输出对应的 chirp 信号值
│   ├── chirp_gen_2.v       # chirp 信号生成模块2
│   ├── key_board.v         # 4*4 矩阵键盘模块
│   ├── param_calc.v        # czt 初相及相位增量计算模块
│   ├── results_waterfall.v # 结果显示模块
│   └── ...                 # lcd 驱动和配置相关的模块
└── README.md               # 项目指南
```

## 🛠 如何使用

### 1. 工程部署步骤
**创建 Vivado 工程**:
*   打开 Vivado，新建一个工程。
*   将 `src/` 目录下的所有 `.v` 及 `.xci` 文件添加进工程。

### 2. 代码存在不足
**目前尚未提供可配置的 CZT 模块的参数接口。**
