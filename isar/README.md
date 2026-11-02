# 基于 FEKO 仿真数据的空间目标 ISAR 转台成像

《合成孔径雷达》课程大作业。FEKO 平面波单站扫频×扫角得到复数后向散射场 E(f, φ)，
在 MATLAB 中做距离-多普勒（RD）与极坐标格式算法（PFA）成像。

目标模型：RADARSAT-1（NASA 3D Resources，免版权，使用时注明来源），转换后的 STL 与俯视轮廓在 `model/`，转换脚本在 `tools/`（Python + trimesh/shapely）。

| 阶段 | 内容 | 文件 |
|---|---|---|
| 1 | 方案与参数设计 | `阶段1_方案与参数设计.md`、`design_params.m`、`params_table.md` |
| 2 | FEKO 2025 操作指南 | `FEKO_操作步骤.md`、`plot_rcs_360.m` |
| 3 | ISAR 成像程序（已用假数据验证） | `read_ffe.m`、`make_synthetic_ffe.m`、`ISAR_FEKO.m` |
| 4 | 汇报材料 | 待完成 |

所有图片保存在 `figures/`（PNG，300 dpi）。在 MATLAB 中把当前目录切到本文件夹后运行脚本。

## 运行顺序（MATLAB R2023a）

1. `design_params` —— 算参数，生成 `design_params.mat` 与模型俯视图
2. `make_synthetic_ffe` —— 生成点散射体假数据 `data/synthetic.ffe`（拿到 FEKO 数据前用于自检）
3. `ISAR_FEKO` —— 成像。换成 FEKO 数据时，只需改开头的 `ffe_file`，并把 `truth_file` 设为 `''`

## 坐标与正负号约定（已用假数据验证）

- FEKO 中 φ = 270° + θ：φ 增大 ⇔ 目标绕 z 轴**顺时针**转动，与 `ISAR_RD.m` 一致。
- FEKO 时间约定 e^{jωt}，单站场 E = A·exp(−j4πf(R−R0)/c)，与 `ISAR_RD.m` 的 `Phase_a` 同号：
  **数据不需要取共轭**，频率维 IFFT 得距离 y（远离雷达为正），方位维 FFT 得横向 x。
- 误取共轭 → 图像绕原点翻转 180°；方位顺序取反 → 左右镜像（见 `figures/fig06_sign_check.png`）。
- 横向定标 x = λ0·f_θ/2（f_θ 为对转角做 FFT 的“角频率”，周/rad），等价于 x = λ0·f_D/(2Ω)。
