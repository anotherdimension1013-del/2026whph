# 阶段2：FEKO 2025 操作步骤（参数化卫星，RL-GO，单站扫频×扫角）

> 适用版本：Altair Feko 2025（CADFEKO / POSTFEKO v2025）。
> 界面名称以平板测试时的截图为准；标 ⚠ 的步骤是根据 Feko 帮助文档写的，还没在你的界面上核对过，找不到就截图。
> **数值输入规则**：CADFEKO 输入框是表达式，不认识单位后缀。10 GHz 写 `10e9`，不能写 `10G`。

## 0. 已验证的结论（平板测试，1 m×1 m，10 GHz）

| 项目 | 结果 |
|---|---|
| RL-GO 可用 | ✅ Face 属性中可选，求解无许可报错 |
| 单站后向散射 | ✅ θ=0° 时 RCS = 0.0139 km² ≈ 41.4 dBsm，理论值 4πA²/λ² = 41.4 dBsm |
| 速度 | 31 个角度共 5.2 s（6 进程并行），约 0.16 s/点 |

## 1. 建模（CADFEKO）

目标：本体为 1.5 m 立方体，中心在原点；两块帆板各 2.5 m×1.2 m，位于 y=0 平面（xz 平面），贴在本体 ±x 面上。

1. 新建模型，确认右下角状态栏 **Unit: m**。先 **File → Save as**，保存为 `satellite.cfx`，放在单独的文件夹里（求解输出文件都会生成在这里）。
2. **本体**：*Construct* 选项卡 → **Cuboid**
   - 定义方式选 *Base corner, width, depth, height*（若默认是 *Base centre*，就把底面中心填成 (0, 0, −0.75)）
   - Base corner：U = `-0.75`，V = `-0.75`，N = `-0.75`
   - Width = `1.5`，Depth = `1.5`，Height = `1.5`，Label：`Bus`
3. **右帆板**：*Construct* → **Rectangle**
   - *Workplane* 页：*Predefined workplane* 选 **Global XZ**
   - *Geometry* 页：定义方式 *Base corner, width, depth*；U = `0.75`，V = `-0.6`，Width = `2.5`，Depth = `1.2`，Label：`Panel_R`
   - **检查**：3D 视图中，这块板应沿 **+x** 方向从本体侧面伸出，竖直宽 1.2 m（沿 z）。如果板沿 z 方向伸出，说明该工作平面的 U 轴是 z：把 U/V、Width/Depth 对调即可（U = `-0.6`，V = `0.75`，Width = `1.2`，Depth = `2.5`）。
4. **左帆板**：同上，Base corner 的 U = `-3.25`（其余相同），Label：`Panel_L`。检查它沿 −x 方向伸出。
5. **合并**：在模型树中按住 Ctrl 选中 `Bus`、`Panel_R`、`Panel_L` → *Construct* 选项卡 → **Union**。
   合并后帆板与本体共享棱线，网格连续，二面角的棱线也被正确识别。
6. **材料检查**：选中合并后的几何体，在左下角 **Details → Faces** 中，每个面后面的小方块应为**橙色**（PEC，默认值）。
   不是橙色的面：右键 → *Properties* → 介质选 *Perfect electric conductor*。
7. **求解方法设为 RL-GO**：在 Details → Faces 中**选中全部面**（点第一个，再 Shift+点最后一个）→ 右键 *Properties* → **Solution** 页 →
   *Solve with special solution method* 选 **Ray launching – geometrical optics (RL-GO)** → OK。
   之后每个面后面应显示 **RL-GO**。
8. **网格**：*Mesh* 选项卡 → *Create mesh*，网格尺寸选 *Coarse*。RL-GO 只要求三角形描述平面形状，不需要按 λ/8 剖分，所以几十到几百个三角形即可。

## 2. 激励与请求

9. **频率**：*Source/Load* 选项卡 → **Frequency**
   - 下拉框选 **Linearly spaced discrete points**（⚠ 不要选 *Continuous (interpolated) range*，那会用自适应采样，频点不等间隔）
   - Start = `9.5e9`，End = `10.5e9`，Number of frequencies = `101`（步进 10 MHz）
10. **平面波**：*Source/Load* 选项卡 → **Plane Wave Source**（整个模型**只建一个**平面波源）
    - 勾选 **Loop over multiple directions**
    - θ：Start = `90`，End = `90`，只取 1 个点（雷达在 xy 平面内）
    - φ：Start = `297`，End = `303`，Increment = `0.08`（共 76 个方向）
    - Magnitude = `1`（V/m），Phase = `0`
    - 极化角 **η = `0`**：VV 极化，θ=90° 时电场沿 −z（竖直）。若要做 HH，改为 `90`
11. **单站远场请求**：*Request* 选项卡 → **Far Fields**
    - 勾选 **Calculate fields in plane wave incident direction**（平板测试已验证）
    - ⚠ **Advanced** 页：勾选 **Export fields to ASCII file (\*.ffe)**。这样求解时会直接生成 MATLAB 要读的 .ffe 文件
    - Label：`Monostatic`
12. ⚠ **RL-GO 反射次数**：*Solve/Run* 选项卡 → **Solver Settings**，找到 RL-GO 相关设置，确认最大反射次数（ray interactions）**≥ 2**。
    帆板-本体二面角是两次反射，反射次数为 1 时会漏掉最强的散射中心。默认值通常已满足；拿不准就截图给我。
13. 右上角 *Model Status* 应显示 **Model is valid**。

## 3. 试算 → 正式求解

14. **试算（建议先做）**：把第 9 步临时改为 *Single frequency* `10e9`，只算 76 个角度。
    *Solve/Run* → **Feko Solver**，记下 Out 文件末尾的 *total times*。
    完整求解时间 ≈ 试算时间 × 101（另有少量固定开销）。
15. **正式求解**：频率改回第 9 步的 101 个频点，保存，**Feko Solver**。预计约 2–4 小时，可以放到晚上算。
16. 求解结束后，模型文件夹里应出现 **`satellite_Monostatic.ffe`**（文件名可能略有不同，扩展名一定是 `.ffe`）。

## 4. 检查结果并导出（POSTFEKO）

17. *Solve/Run* → **POSTFEKO**。新建 **Cartesian** 图，把 `Monostatic` 拖进图中：
    - 横轴 *Plane Wave Phi*，固定 Frequency = 10 GHz，Quantity 选 **Radar cross section (RCS)**，勾 **dB**：得到 RCS 随方位角变化的曲线
    - 横轴改为 *Frequency*：得到 RCS 随频率变化的曲线
    - 截图保存，汇报时会用到
18. 若第 16 步没有生成 .ffe：⚠ 在 POSTFEKO 中选中 `Monostatic` → *Home* → **Export** → *Data*，格式选 Feko far field (\*.ffe)。
19. 把 `.ffe` 文件复制到 `isar/data/` 目录，在 `ISAR_FEKO.m` 开头修改：
    ```matlab
    ffe_file = 'data/satellite_Monostatic.ffe';
    truth_file = '';   % 真实数据没有“真实散射点”
    ```
    运行 `ISAR_FEKO` 即可出图。

## 5. 附加：全方位 RCS 曲线（汇报用，可选）

20. **File → Save as** 另存为 `satellite_rcs360.cfx`，只改两处：
    - 频率：*Single frequency* `10e9`
    - 平面波 φ：Start = `0`，End = `359.5`，Increment = `0.5`（720 个方向）
21. 求解后把 .ffe 复制到 `isar/data/`，运行 `plot_rcs_360.m`，画出 0°~360° 的 RCS 曲线。
    预期：φ=90°/270° 时帆板和本体 ±y 面同时正对雷达，出现最强的镜面峰；φ=0°/180° 时本体 ±x 面正对雷达，出现较弱的镜面峰；
    φ 在 180°~360° 之间（雷达在帆板下方一侧）有二面角贡献，RCS 起伏的平均水平较高。

## 常见问题

| 现象 | 原因与处理 |
|---|---|
| 输入框变红，提示 *Error in expression* | 用了单位后缀，改成科学计数法，如 `9.5e9` |
| *Only a single plane wave source with multiple incident directions is allowed* | 建了两个平面波源。在 *Configuration* 页删掉多余的一个，远场请求也只留一个 |
| 打开了 *Far Field Source* 对话框 | 那是"远场源"（激励）。远场**请求**在 *Request* 选项卡 |
| ISAR 图整体转了 180° 或左右镜像 | 先确认 φ 是从小到大扫描；`read_ffe.m` 会自动按 φ 升序排列。仍不对就对照 `figures/fig06_sign_check.png` 找我 |
