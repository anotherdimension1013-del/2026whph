"""生成 SAR 笔记 2-2（回波信号的多普勒历史）的示意图。

用法：python3 scripts/figures/sar_2_2.py
输出：src/assets/figures/sar/doppler-history.svg

四个面板共用同一条时间轴：几何 → 斜距 r(t) → 多普勒频率 f_d(t) → 降频后的回波。
"""
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[2] / "src/assets/figures/sar"
GREEN, ORANGE, DARK, AXIS, TEXT, MUTED = "#4f7560", "#c0714c", "#2f4235", "#9aa093", "#3d4a40", "#8b947d"

X0, X1 = 150, 620          # 绘图区横向范围
T1, T0, T3 = 0.1, 0.5, 0.9  # 位置 1、2、3 对应的时刻（t0 为波束中心）


def px(t):
    return X0 + (np.asarray(t)) * (X1 - X0)


def path(xs, ys, color, w=1.8, dash=None):
    d = "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in zip(xs, ys))
    da = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linejoin="round"{da}/>'


def line(x1, y1, x2, y2, color=AXIS, w=1, dash=None, marker=None):
    da = f' stroke-dasharray="{dash}"' if dash else ""
    m = f' marker-end="url(#{marker})"' if marker else ""
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{color}" stroke-width="{w}"{da}{m}/>'


def text(x, y, s, cls="", anchor="start"):
    c = f' class="{cls}"' if cls else ""
    return f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}"{c}>{s}</text>'


def axis(y, label="t"):
    return line(X0 - 10, y, X1 + 18, y, AXIS, 1, marker="arr22") + text(X1 + 22, y + 5, label, "m")


def build():
    t = np.linspace(0, 1, 1200)
    b = []
    # 竖直参考线：位置 1、2、3
    for tt in (T1, T0, T3):
        b.append(line(px(tt), 40, px(tt), 690, "#d8d6c8", 1, "4 4"))

    # ---- 面板 A：几何（俯视斜距平面）
    ty, py = 60, 150
    b.append(text(20, ty + 5, "① 几何", "t"))
    b.append(line(X0 - 10, ty, X1 + 18, ty, DARK, 1.4, marker="arr22d"))
    b.append(text(X1 + 22, ty + 5, "x", "m"))
    pxp = px(T0)
    for tt, lab in ((T1, "1 进入"), (T0, "2 中心"), (T3, "3 离开")):
        b.append(f'<circle cx="{px(tt):.1f}" cy="{ty}" r="5" fill="{ORANGE}"/>')
        b.append(text(px(tt), ty - 12, lab, "s", "middle"))
    b.append(f'<circle cx="{pxp:.1f}" cy="{py}" r="6" fill="{DARK}"/>')
    b.append(text(pxp + 12, py + 5, "点目标 P（x = X）", "s"))
    b.append(line(px(T1), ty, pxp, py, GREEN, 1.3, "5 4"))
    b.append(line(px(T3), ty, pxp, py, GREEN, 1.3, "5 4"))
    b.append(line(pxp, ty, pxp, py, ORANGE, 1.6))
    b.append(text(pxp - 8, (ty + py) / 2 + 5, "R", "o", "end"))
    b.append(text((px(T1) + pxp) / 2 - 14, (ty + py) / 2 + 2, "r(t)", "g", "end"))

    # ---- 面板 B：斜距 r(t)（抛物线，最小值 R 在 t0）
    yb0, hb = 270, 70
    r = (t - T0) ** 2
    rn = r / r.max()
    b.append(text(20, yb0 - 25, "② 斜距 r(t)", "t"))
    b.append(axis(yb0))
    b.append(path(px(t), yb0 - 12 - (1 - rn) * 0 - rn * hb, GREEN))
    b.append(text(px(T0), yb0 + 20, "t₀ 时最小，等于 R", "s", "middle"))
    b.append(text(px(T0), yb0 - hb + 8, "r ≈ R + (vₐt − X)²/(2R)", "m", "middle"))

    # ---- 面板 C：多普勒频率 f_d(t)（直线，负斜率）
    yc0, hc = 420, 55
    fd = -(t - T0) / (T3 - T0)  # 位置 1 处 +1，位置 3 处 −1
    b.append(text(20, yc0 - hc - 12, "③ 多普勒频率", "t"))
    b.append(text(20, yc0 - hc + 10, 'f<tspan baseline-shift="sub" font-size="11">d</tspan>(t)', "m"))
    b.append(axis(yc0))
    mask = (t >= T1) & (t <= T3)
    b.append(path(px(t[mask]), yc0 - fd[mask] * hc, ORANGE, 2.4))
    b.append(text(px(T1) - 8, yc0 - hc + 5, '+Δf<tspan baseline-shift="sub" font-size="11">d</tspan>/2', "o", "end"))
    b.append(text(px(T3) + 8, yc0 + hc + 5, '−Δf<tspan baseline-shift="sub" font-size="11">d</tspan>/2', "o"))
    b.append(text(px(T0) + 8, yc0 - 8, "0", "s"))
    b.append(text(px(0.18), yc0 + hc - 2, '靠近：f<tspan baseline-shift="sub" font-size="11">d</tspan> &gt; 0', "m"))
    b.append(text(px(0.64), yc0 - hc + 6, '远离：f<tspan baseline-shift="sub" font-size="11">d</tspan> &lt; 0', "m"))
    # T_s 标注
    yt = yc0 + hc + 30
    b.append(line(px(T1), yt, px(T3), yt, DARK, 1.2, marker="arr22d"))
    b.append(line(px(T3), yt, px(T1), yt, DARK, 1.2, marker="arr22d"))
    b.append(text(px(T0), yt + 20, "合成孔径时间 Tₛ = Lₛ / vₐ", "t", "middle"))

    # ---- 面板 D：降频后的回波（线性调频，频率由高到低）
    yd0, hd = 620, 34
    tau = (t - T0)
    phase = 2 * np.pi * (11 * tau - 0.5 * 22 * tau ** 2)  # 中心频率 f0，负斜率
    sig = np.where(mask, np.cos(phase), 0.0)
    b.append(text(20, yd0 - hd - 12, "④ 回波（降频后）", "t"))
    b.append(axis(yd0))
    b.append(path(px(t), yd0 - sig * hd, GREEN, 1.3))
    b.append(text(px(T0), yd0 + hd + 26, "频率由高到低：方位向回波是线性调频信号（斜率 kₐ &lt; 0）", "g", "middle"))

    body = "\n".join(b)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 700" role="img" aria-label="多普勒历史：斜距随时间呈抛物线，多普勒频率随时间线性下降，回波为线性调频信号">
<title>多普勒历史示意图</title>
<defs>
  <marker id="arr22" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{AXIS}"/></marker>
  <marker id="arr22d" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{DARK}"/></marker>
</defs>
<style>
  text {{ font-family: inherit; fill: {TEXT}; font-size: 16px; }}
  .t {{ font-weight: 700; font-size: 17px; }}
  .s {{ font-size: 14px; }}
  .m {{ fill: {MUTED}; font-size: 14px; }}
  .o {{ fill: {ORANGE}; font-weight: 700; font-size: 15px; }}
  .g {{ fill: {GREEN}; font-weight: 700; font-size: 15px; }}
</style>
{body}
</svg>
'''


(OUT / "doppler-history.svg").write_text(build(), encoding="utf-8")
print("wrote", OUT / "doppler-history.svg")
