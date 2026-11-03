"""生成 SAR 笔记 2-1（合成孔径原理概述）的示意图。

用法：python3 scripts/figures/sar_2_1.py
输出：src/assets/figures/sar/*.svg
"""
from pathlib import Path
import math

OUT = Path(__file__).resolve().parents[2] / "src/assets/figures/sar"
OUT.mkdir(parents=True, exist_ok=True)

GREEN, ORANGE, DARK, AXIS, TEXT, MUTED = "#4f7560", "#c0714c", "#2f4235", "#9aa093", "#3d4a40", "#8b947d"


def svg(w, h, body, title):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" role="img" aria-label="{title}">
<title>{title}</title>
<defs>
  <marker id="arr21" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{DARK}"/></marker>
  <marker id="arr21o" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{ORANGE}"/></marker>
</defs>
<style>
  text {{ font-family: inherit; fill: {TEXT}; font-size: 17px; }}
  .t {{ font-weight: 700; font-size: 18px; }}
  .m {{ fill: {MUTED}; font-size: 15px; }}
  .o {{ fill: {ORANGE}; font-weight: 700; }}
  .g {{ fill: {GREEN}; font-weight: 700; }}
</style>
{body}
</svg>
'''


def line(p, q, color=DARK, w=1.4, dash=None, marker=None, opacity=1):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    m = f' marker-end="url(#{marker})"' if marker else ""
    return (f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{color}"'
            f' stroke-width="{w}" opacity="{opacity}"{d}{m}/>')


def text(p, s, cls="", anchor="start", dy=0):
    c = f' class="{cls}"' if cls else ""
    return f'<text x="{p[0]:.1f}" y="{p[1] + dy:.1f}" text-anchor="{anchor}"{c}>{s}</text>'


def poly(pts, fill, stroke="none", opacity=1, w=1.2):
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return f'<polygon points="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{opacity}"/>'


# ---------------------------------------------------------------- 图 2-1-a：正侧视几何
def fig_geometry():
    # 斜投影：x 沿航向，y 地距（远离航迹），z 高度
    def P(x, y, z):
        return (40 + 1.0 * x + 0.62 * y, 250 - 1.0 * z + 0.42 * y)

    H, xr = 170, 150          # 平台高度、雷达当前位置
    y_near, y_far = 150, 330  # 测绘带近端、远端地距
    half = lambda y: 0.22 * y  # 方位向半宽随距离增大（波束张角 β）

    b = []
    # 测绘带（条带）
    b.append(poly([P(0, y_near, 0), P(420, y_near, 0), P(420, y_far, 0), P(0, y_far, 0)], "#e3eadf"))
    b.append(text(P(330, y_far, 0), "测绘带（条带）", "g", "middle", dy=26))
    # 星下点航迹
    b.append(line(P(0, 0, 0), P(470, 0, 0), AXIS, 1, "5 4"))
    b.append(text(P(0, 0, 0), "星下点航迹", "m", dy=20))
    # 当前波束足迹（梯形）
    foot = [P(xr - half(y_near), y_near, 0), P(xr + half(y_near), y_near, 0),
            P(xr + half(y_far), y_far, 0), P(xr - half(y_far), y_far, 0)]
    b.append(poly(foot, "#c9d7c4", GREEN, 1, 1.4))
    # 平台航迹与速度
    radar = P(xr, 0, H)
    b.append(line(P(0, 0, H), P(470, 0, H), DARK, 1.4))
    b.append(line(P(360, 0, H), P(470, 0, H), DARK, 2, marker="arr21"))
    b.append(text(P(470, 0, H), "飞行方向 x，速度 vₐ", "t", "end", dy=-12))
    # 波束边缘线
    for q in foot:
        b.append(line(radar, q, GREEN, 1, opacity=.7))
    # 斜距 R（到足迹中心）
    yc = (y_near + y_far) / 2
    b.append(line(radar, P(xr, yc, 0), ORANGE, 1.8, "6 4"))
    mid = P(xr, yc * 0.55, H * 0.45)
    b.append(text(mid, "R", "o", dy=0))
    # 竖线（高度）
    b.append(line(radar, P(xr, 0, 0), AXIS, 1, "3 3"))
    # 雷达
    b.append(f'<circle cx="{radar[0]:.1f}" cy="{radar[1]:.1f}" r="6" fill="{DARK}"/>')
    b.append(text(radar, "雷达", "t", "end", dy=-10))
    # β 与 φ 标注
    fa, fb = P(xr - half(y_far), y_far, 0), P(xr + half(y_far), y_far, 0)
    b.append(text(((fa[0] + fb[0]) / 2, (fa[1] + fb[1]) / 2), "方位向张角 β（水平宽度）", "g", "middle", dy=28))
    pn = P(xr - half(y_near), y_near, 0)
    b.append(text(pn, "俯仰向张角 φ（垂直宽度）", "m", "end", dy=4))
    b.append(text((radar[0] - 6, radar[1] + 210), "", "m"))
    b.insert(0, text((20, 30), "侧视：波束斜向一侧照射地面，随飞行扫出一条测绘带", "t"))
    return svg(700, 470, "\n".join(b), "正侧视雷达几何：雷达沿 x 方向匀速飞行，波束照射地面形成条带测绘带")


# ---------------------------------------------------------------- 图 2-1-b：合成孔径的形成（俯视）
def fig_synthetic():
    ty = 130                 # 航迹 y
    tgt = (340, 390)        # 点目标
    R = tgt[1] - ty
    beta = 0.9              # 真实波束张角（示意，夸大）
    hb = beta / 2
    Ls = 2 * R * math.tan(hb)
    A, B = (tgt[0] - Ls / 2, ty), (tgt[0] + Ls / 2, ty)

    def beam(origin, color, opacity, dash=None):
        L = R / math.cos(hb) + 30
        l = (origin[0] - L * math.sin(hb), origin[1] + L * math.cos(hb))
        r = (origin[0] + L * math.sin(hb), origin[1] + L * math.cos(hb))
        out = [poly([origin, l, r], color, opacity=opacity)]
        out += [line(origin, l, GREEN, 1, dash), line(origin, r, GREEN, 1, dash)]
        return out

    b = [text((20, 30), "俯视：P 从进入波束到离开波束，雷达飞过的距离就是合成孔径长度", "t")]
    b += beam(A, "#dfe8da", .55)
    b += beam(B, "#dfe8da", .55)
    # 航迹
    b.append(line((20, ty), (640, ty), DARK, 1.4))
    b.append(line((550, ty - 30), (640, ty - 30), DARK, 2, marker="arr21"))
    b.append(text((550, ty - 40), "vₐ", "t"))
    # 合成阵列阵元
    n = 13
    for i in range(n):
        x = A[0] + Ls * i / (n - 1)
        b.append(f'<circle cx="{x:.1f}" cy="{ty}" r="4" fill="{ORANGE}"/>')
    b.append(text((A[0], ty), "A（P 进入波束）", "t", "middle", dy=-14))
    b.append(text((B[0], ty), "B（P 离开波束）", "t", "middle", dy=-14))
    # L_s 标注
    yb = ty - 50
    b.append(line((A[0], yb), (B[0], yb), ORANGE, 1.4, marker="arr21o"))
    b.append(line((B[0], yb), (A[0], yb), ORANGE, 1.4, marker="arr21o"))
    b.append(text(((A[0] + B[0]) / 2, yb), "合成孔径长度 Lₛ = βR", "o", "middle", dy=-8))
    # 目标与距离
    b.append(f'<circle cx="{tgt[0]}" cy="{tgt[1]}" r="7" fill="{DARK}"/>')
    b.append(text(tgt, "点目标 P", "t", "start", dy=30))
    b.append(line((tgt[0], ty), tgt, AXIS, 1, "4 4"))
    b.append(text((tgt[0] + 8, ty + R * 0.55), "R", "t"))
    # 真实波束角 β 标注（在 A 处）
    b.append(text((A[0] - 4, ty + 70), "β", "g", "middle"))
    # 合成波束（窄）
    hs = 0.035
    L2 = R + 10
    cl = (tgt[0] - L2 * math.tan(hs), ty + L2)
    cr = (tgt[0] + L2 * math.tan(hs), ty + L2)
    b.append(poly([(tgt[0], ty), cl, cr], ORANGE, opacity=.35))
    b.append(line((tgt[0], ty), cl, ORANGE, 1.2))
    b.append(line((tgt[0], ty), cr, ORANGE, 1.2))
    b.append(text((tgt[0] + 30, ty + R * 0.3), "合成波束 βₛ（很窄）", "o"))
    # 底部说明
    b.append(text((20, 475), "真实天线：波束宽 β = λ/D，在距离 R 处照亮 βR，方位分辨率差", "m"))
    b.append(text((20, 502), "合成阵列：长度 Lₛ = βR ≫ D，波束 βₛ 很窄，方位分辨率 ≈ D/2", "m"))
    return svg(660, 520, "\n".join(b), "合成孔径的形成：雷达在 A、B 之间飞过的距离 Ls 构成等效长天线阵列")


for name, fn in [("side-looking-geometry", fig_geometry), ("synthetic-aperture", fig_synthetic)]:
    (OUT / f"{name}.svg").write_text(fn(), encoding="utf-8")
    print("wrote", OUT / f"{name}.svg")
