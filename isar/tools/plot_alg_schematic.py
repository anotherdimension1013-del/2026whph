"""汇报PPT用示意图：RD、PFA、BP 三种算法各自如何处理“扇形”数据。
示意，夸大了转角与带宽，使扇形弯曲肉眼可见。
用法：python tools/plot_alg_schematic.py   输出：ppt/fig/sch_rd.png, sch_pfa.png, sch_bp.png
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ppt" / "fig"
OUT.mkdir(parents=True, exist_ok=True)
for name in ["Microsoft YaHei", "WenQuanYi Zen Hei"]:
    if any(name == f.name for f in font_manager.fontManager.ttflist):
        plt.rcParams["font.family"] = name
        break

NAVY, TEAL, RED, GREY, LIGHT = "#28578A", "#00848B", "#B03A2E", "#5A6570", "#AFBAC5"
FS = 13

# 扇形采样：频率 -> 半径 K，角度 -> 方向（以中心视角为参考，横向Kx、距离向Ky）
K = np.linspace(1.0, 1.45, 7)
th = np.deg2rad(np.linspace(-22, 22, 9))
TH, KK = np.meshgrid(th, K)
KX, KY = KK * np.sin(TH), KK * np.cos(TH)


def base(ax):
    for k in K:  # 等频率弧
        ax.plot(k * np.sin(th), k * np.cos(th), color=LIGHT, lw=0.8)
    for t in th:  # 等角度射线
        ax.plot(K * np.sin(t), K * np.cos(t), color=LIGHT, lw=0.8)
    ax.plot(KX.ravel(), KY.ravel(), "o", color=NAVY, ms=4)
    ax.set_aspect("equal"); ax.axis("off")
    ax.set_xlim(-0.75, 0.75); ax.set_ylim(0.82, 1.62)


def save(fig, name):
    fig.savefig(OUT / name, dpi=250, facecolor="white", bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)


# RD：把扇形“当成”矩形（每个采样点被放到矩形网格上）
fig, ax = plt.subplots(figsize=(3.6, 2.2))
base(ax)
kx_r = np.outer(np.ones_like(K), K[0] * th)        # RD 假设 Kx ≈ K0·θ
ky_r = np.outer(K, np.ones_like(th))               # RD 假设 Ky ≈ K
ax.plot(kx_r.ravel(), ky_r.ravel(), "s", mfc="none", mec=RED, ms=5, mew=1)
for i in [0, -1]:
    for j in [0, -1]:
        ax.annotate("", xy=(kx_r[i, j], ky_r[i, j]), xytext=(KX[i, j], KY[i, j]),
                    arrowprops=dict(arrowstyle="->", color=RED, lw=1))
ax.text(0, 1.57, "当作矩形，位置有误差", color=RED, fontsize=FS, ha="center")
save(fig, "sch_rd.png")

# PFA：按真实坐标插值到扇形内接的矩形网格
fig, ax = plt.subplots(figsize=(3.6, 2.2))
base(ax)
kx_lo, kx_hi = K[0] * np.sin(th[0]), K[0] * np.sin(th[-1])
ky_lo, ky_hi = K[0], np.sqrt(K[-1] ** 2 - kx_hi ** 2)
gx, gy = np.meshgrid(np.linspace(kx_lo, kx_hi, 7), np.linspace(ky_lo, ky_hi, 6))
ax.plot(gx.ravel(), gy.ravel(), "s", color=TEAL, ms=3.5)
ax.plot([kx_lo, kx_hi, kx_hi, kx_lo, kx_lo], [ky_lo, ky_lo, ky_hi, ky_hi, ky_lo], "--", color=TEAL, lw=1.3)
ax.text(0, 1.57, "插值到矩形网格", color=TEAL, fontsize=FS, ha="center")
save(fig, "sch_pfa.png")

# BP：在图像网格上，逐像素计算到各个雷达方向的距离
fig, ax = plt.subplots(figsize=(3.6, 2.2))
g = np.linspace(-1, 1, 6)
for v in g:
    ax.plot([v, v], [-1, 1], color=LIGHT, lw=0.8)
    ax.plot([-1, 1], [v, v], color=LIGHT, lw=0.8)
px, py = 0.6, 0.2
ax.add_patch(plt.Rectangle((0.6, 0.2), 0.4, 0.4, color=TEAL, alpha=0.85))
for a in np.deg2rad([-115, -90, -65]):  # 雷达方向（示意）
    rx, ry = 2.6 * np.cos(a), 2.6 * np.sin(a) + 0.3
    ax.plot(rx, ry, "^", color=NAVY, ms=9)
    ax.plot([rx, px + 0.2], [ry, py + 0.2], "--", color=NAVY, lw=1)
ax.text(1.15, 0.95, "像素", color=TEAL, fontsize=FS)
ax.text(0, -2.95, "各角度下的雷达", color=NAVY, fontsize=FS, ha="center", va="center")
ax.set_aspect("equal"); ax.axis("off")
ax.set_xlim(-2.6, 2.4); ax.set_ylim(-3.25, 1.25)
save(fig, "sch_bp.png")
print("已输出示意图到", OUT)
