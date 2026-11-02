# 阶段2：FEKO 2025 操作步骤（RADARSAT-1 模型，RL-GO，单站扫频×扫角）

> 适用版本：Altair Feko 2025（CADFEKO / POSTFEKO v2025）。
> 界面名称以平板测试时的截图为准；标 ⚠ 的步骤是根据 Feko 帮助文档写的，还没在你的界面上核对过，找不到就截图。
> **数值输入规则**：CADFEKO 输入框是表达式，不认识单位后缀。10 GHz 写 `10e9`，不能写 `10G`。

## 0. 已验证的结论（平板测试，1 m×1 m，10 GHz）

| 项目 | 结果 |
|---|---|
| RL-GO 可用 | ✅ Face 属性中可选，求解无许可报错 |
| 单站后向散射 | ✅ θ=0° 时 RCS = 0.0139 km² ≈ 41.4 dBsm，理论值 4πA²/λ² = 41.4 dBsm |
| 速度 | 31 个角度共 5.2 s（6 进程并行），约 0.16 s/点 |

## 1. 导入模型（CADFEKO）

模型文件：`isar/model/radarsat1_m.stl`，可在 GitHub 仓库 `isar-project` 分支的 `isar/model/` 目录下载。
它来自 NASA 3D Resources 的 RADARSAT-1，已经预处理好：单位为米，翼展约 16 m，SAR 天线平板竖直（法向沿 −y、位于 y≈−2.1 m），本体中心在原点（即转台旋转中心），共 6028 个三角形。

1. 新建模型，确认右下角状态栏 **Unit: m**。**File → Save as** 保存为 `radarsat1.cfx`，放在单独的文件夹里（求解输出文件都会生成在这里）。
2. ⚠ **导入 STL**：*Home* 选项卡 → **Import** → **Mesh**，文件类型选 STL，选中 `radarsat1_m.stl`。
   - 若导入对话框里有单位或缩放选项，单位选 **Metres**，缩放比例填 **1**（STL 已经是米）
   - 导入后模型出现在左侧模型树的 *Model → Meshes* 下
3. **检查尺寸和方向**（重要）：
   - 俯视（看向 −z 方向）时，卫星沿 **x 轴**展开，总长约 16 m
   - 长条形的 SAR 天线平板在 **y ≈ −2.1 m** 处，俯视时只看到一条细线（因为它是竖直放置的）
   - 不对就截图给我，不要继续往下做
4. **材料检查**：选中导入的网格，在左下角 **Details** 面板中展开它的面（Faces 或 Labels）。每一项后面的小方块应为**橙色**（PEC）。
   不是橙色的：右键 → *Properties* → 介质选 *Perfect electric conductor*。
5. **求解方法设为 RL-GO**：在 Details 中**选中全部面**（点第一个，再 Shift+点最后一个）→ 右键 *Properties* → **Solution** 页 →
   *Solve with special solution method* 选 **Ray launching – geometrical optics (RL-GO)** → OK。之后每一项后面应显示 **RL-GO**。
6. **不需要重新划分网格**：导入的 STL 本身就是三角形网格，RL-GO 直接使用。若 CADFEKO 提示需要网格，按默认设置操作即可，不要选更细的网格。

## 2. 激励与请求

7. **频率**：*Source/Load* 选项卡 → **Frequency**
   - 下拉框选 **Linearly spaced discrete points**（⚠ 不要选 *Continuous (interpolated) range*，那会用自适应采样，频点不等间隔）
   - Start = `9.75e9`，End = `10.25e9`，Number of frequencies = `101`（步进 5 MHz，带宽 500 MHz，距离分辨率 0.3 m）
8. **平面波**：*Source/Load* 选项卡 → **Plane Wave Source**（整个模型**只建一个**平面波源）
    - 勾选 **Loop over multiple directions**
    - θ：Start = `90`，End = `90`，只取 1 个点（雷达在 xy 平面内）
    - φ：Start = `298.5`，End = `301.5`，Increment = `0.03`（共 101 个方向，总转角 3°，横向分辨率约 0.29 m）
    - Magnitude = `1`（V/m），Phase = `0`
    - 极化角 **η = `0`**：VV 极化，θ=90° 时电场沿 −z（竖直）。若要做 HH，改为 `90`
9. **单站远场请求**：*Request* 选项卡 → **Far Fields**
    - 勾选 **Calculate fields in plane wave incident direction**（平板测试已验证）
    - ⚠ **Advanced** 页：勾选 **Export fields to ASCII file (\*.ffe)**。这样求解时会直接生成 MATLAB 要读的 .ffe 文件
    - Label：`Monostatic`
10. ⚠ **RL-GO 反射次数**：*Solve/Run* 选项卡 → **Solver Settings**，找到 RL-GO 相关设置，确认最大反射次数（ray interactions）**≥ 2**。
    天线背面的桁架、太阳翼与本体之间会形成二面角（两次反射），反射次数为 1 时会漏掉这些散射中心。默认值通常已满足；拿不准就截图给我。
11. 右上角 *Model Status* 应显示 **Model is valid**。

## 3. 试算 → 正式求解

12. **试算（建议先做）**：把第 7 步临时改为 *Single frequency* `10e9`，只算 101 个角度。
    *Solve/Run* → **Feko Solver**，记下 Out 文件末尾的 *total times*。
    完整求解时间 ≈ 试算时间 × 101（另有少量固定开销）。
13. **正式求解**：频率改回第 7 步的 101 个频点，保存，**Feko Solver**。共 10201 个单站解，预计 3–8 小时（以试算结果为准），可以放到晚上算。
14. 求解结束后，模型文件夹里应出现 **`radarsat1_Monostatic.ffe`**（文件名可能略有不同，扩展名一定是 `.ffe`）。

## 4. 检查结果并导出（POSTFEKO）

15. *Solve/Run* → **POSTFEKO**。新建 **Cartesian** 图，把 `Monostatic` 拖进图中：
    - 横轴 *Plane Wave Phi*，固定 Frequency = 10 GHz，Quantity 选 **Radar cross section (RCS)**，勾 **dB**：得到 RCS 随方位角变化的曲线
    - 横轴改为 *Frequency*：得到 RCS 随频率变化的曲线
    - 截图保存，汇报时会用到
16. 若第 14 步没有生成 .ffe：⚠ 在 POSTFEKO 中选中 `Monostatic` → *Home* → **Export** → *Data*，格式选 Feko far field (\*.ffe)。
17. 把 `.ffe` 文件复制到 `isar/data/` 目录，在 `ISAR_FEKO.m` 开头修改：
    ```matlab
    ffe_file = 'data/radarsat1_Monostatic.ffe';
    truth_file = '';   % 真实数据没有“真实散射点”
    ```
    运行 `ISAR_FEKO` 即可出图。

## 5. 附加：全方位 RCS 曲线（汇报用，可选）

18. **File → Save as** 另存为 `radarsat1_rcs360.cfx`，只改两处：
    - 频率：*Single frequency* `10e9`
    - 平面波 φ：Start = `0`，End = `359.5`，Increment = `0.5`（720 个方向）
19. 求解后把 .ffe 复制到 `isar/data/`，运行 `plot_rcs_360.m`，画出 0°~360° 的 RCS 曲线。
    预期：φ=270° 时 SAR 天线平板（约 14 m×2 m）正对雷达，出现全方位最强的镜面峰（理论上可达 70 dBsm 量级）；
    φ=90° 时雷达从背面看，会看到天线背面的桁架和本体；太阳翼接近水平，雷达在 xy 平面内只能看到它的侧棱，回波较弱。

## 常见问题

| 现象 | 原因与处理 |
|---|---|
| 输入框变红，提示 *Error in expression* | 用了单位后缀，改成科学计数法，如 `9.5e9` |
| *Only a single plane wave source with multiple incident directions is allowed* | 建了两个平面波源。在 *Configuration* 页删掉多余的一个，远场请求也只留一个 |
| 打开了 *Far Field Source* 对话框 | 那是"远场源"（激励）。远场**请求**在 *Request* 选项卡 |
| ISAR 图整体转了 180° 或左右镜像 | 先确认 φ 是从小到大扫描；`read_ffe.m` 会自动按 φ 升序排列。仍不对就对照 `figures/fig06_sign_check.png` 找我 |
