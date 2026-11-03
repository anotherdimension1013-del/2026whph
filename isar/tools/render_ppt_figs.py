"""汇报PPT用图：读取 ISAR_experiments.m 保存的 results_images<tag>.mat，
按深色背景、大字号、无标题（标题写在PPT里）重新绘制各张ISAR图像。

用法：python tools/render_ppt_figs.py [tag]   tag 缺省为 _po（简化PO预览数据）；FEKO数据用空字符串 ""
输出：ppt/fig/*.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]
TAG = sys.argv[1] if len(sys.argv) > 1 else "_po"
OUT = ROOT / "ppt" / "fig"
OUT.mkdir(parents=True, exist_ok=True)

# 中文字体：优先微软雅黑，其次文泉驿
for name in ["Microsoft YaHei", "WenQuanYi Zen Hei"]:
    if any(name == f.name for f in font_manager.fontManager.ttflist):
        plt.rcParams["font.family"] = name
        break
plt.rcParams["axes.unicode_minus"] = False

BG = "#0B1220"      # 与PPT背景一致
FG = "#C9D3E0"      # 坐标轴文字
CYAN = "#4DD9FF"    # 模型轮廓
GREEN = "#7CFF9B"   # 散射中心标注
DR = 25             # 显示动态范围，dB

D = loadmat(ROOT / f"results_images{TAG}.mat", squeeze_me=True, struct_as_record=False)
lims = D["lims"]


def axes_style(ax, show_y=True):
    ax.set_facecolor("black")
    ax.tick_params(colors=FG, labelsize=13, length=3)
    for s in ax.spines.values():
        s.set_color("#3A4A60")
    ax.set_xlabel("x / m", color=FG, fontsize=13)
    if show_y:
        ax.set_ylabel("y / m", color=FG, fontsize=13)


def show(img, x, y, outline, fname, lim=lims, size=(7.0, 3.3), marks=None, cbar=False):
    """一张ISAR图像：hot色图，-25~0 dB，叠加模型轮廓"""
    fig, ax = plt.subplots(figsize=size, facecolor=BG)
    im = ax.imshow(np.clip(img, -DR, 0), extent=[x[0], x[-1], y[0], y[-1]], origin="lower",
                   cmap="hot", vmin=-DR, vmax=0, interpolation="bilinear", aspect="equal")
    ax.plot(outline[:, 0], outline[:, 1], color=CYAN, lw=0.8, alpha=0.9)
    if marks is not None:
        for k, (px, py) in enumerate(marks, 1):
            ax.plot(px, py, "o", mfc="none", mec=GREEN, ms=13, mew=1.8)
            ax.text(px + 0.28, py + 0.22, str(k), color=GREEN, fontsize=15, fontweight="bold")
    ax.set_xlim(lim[0], lim[1]); ax.set_ylim(lim[2], lim[3])
    axes_style(ax)
    if cbar:
        cb = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.02)
        cb.ax.tick_params(colors=FG, labelsize=12)
        cb.set_label("dB", color=FG, fontsize=12)
        cb.outline.set_edgecolor("#3A4A60")
    fig.savefig(OUT / fname, dpi=250, facecolor=BG, bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)


xa, ya = D["x_axis"], D["y_axis"]
xc, yc = D["x_coh"], D["y_coh"]
xf, yf = D["x_fine"], D["y_fine"]
o0, o30 = D["outline_0"], D["outline_30"]

# 封面：几何平均融合图
show(D["Image_Afu"], xa, ya, o30, "cover_fusion.png", size=(10, 4.6))
# 第7页：俯仰角对比
show(D["Image_E0"], xa, ya, o0, "eps0.png")
show(D["Image_Ac"], xa, ya, o30, "eps30.png")
# 第8页：四种处理方式
show(D["Image_Ac"], xa, ya, o30, "fu_single.png", size=(5.4, 2.6))
show(D["Image_Acoh"], xc, yc, o30, "fu_coh.png", size=(5.4, 2.6))
show(D["Image_Amean"], xa, ya, o30, "fu_mean.png", size=(5.4, 2.6))
show(D["Image_Afu"], xa, ya, o30, "fu_geo.png", size=(5.4, 2.6))
# 第9页：分辨率（全图 + 最强点局部放大）
show(D["Image_Ac"], xa, ya, o30, "res_030.png")
show(D["Image_B"], xf, yf, o30, "res_015.png")
pk = np.atleast_1d(D["pk_A"])
zl = [pk[0] - 0.8, pk[0] + 0.8, pk[1] - 0.8, pk[1] + 0.8]
show(D["Image_Ac"], xa, ya, o30, "zoom_030.png", lim=zl, size=(3.2, 3.2))
show(D["Image_B"], xf, yf, o30, "zoom_015.png", lim=zl, size=(3.2, 3.2))
# 第10页：散射中心标注
pks = np.atleast_2d(D["pk"])
show(D["Image_Afu"], xa, ya, o30, "scatter.png", size=(8.2, 3.8), marks=pks[:, :2], cbar=True)

# 色标单独一张（各页共用）
fig = plt.figure(figsize=(0.9, 3.0), facecolor=BG)
cax = fig.add_axes([0.15, 0.05, 0.25, 0.9])
cb = matplotlib.colorbar.ColorbarBase(cax, cmap="hot", norm=matplotlib.colors.Normalize(-DR, 0))
cb.ax.tick_params(colors=FG, labelsize=12); cb.outline.set_edgecolor("#3A4A60")
cb.set_label("dB", color=FG, fontsize=12)
fig.savefig(OUT / "colorbar.png", dpi=250, facecolor=BG)
plt.close(fig)
print("已输出到", OUT)

# 第6页：同一份B数据上RD、PFA、BP三种算法的局部放大（ISAR_FEKO.m 保存 results_algo<tag>_B.mat）
algo_file = ROOT / f"results_algo{TAG}_B.mat"
if algo_file.exists():
    G = loadmat(algo_file, squeeze_me=True, struct_as_record=False)
    zc, zw = np.atleast_1d(G["zoom_c"]), float(G["zoom_w"])
    zl = [zc[0] - zw, zc[0] + zw, zc[1] - zw, zc[1] + zw]
    for img, name in zip(G["img_list"], ["alg_rd.png", "alg_pfa.png", "alg_bp.png"]):
        show(img, G["x_image"], G["y_image"], G["outline_rot"], name, lim=zl, size=(3.4, 3.4))
    print("算法对比：光斑面积", G["spot_alg"], "用时", G["t_alg"])
