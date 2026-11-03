"""生成 SAR 笔记 1-2（脉冲压缩原理）的示意图。

用法：python3 scripts/figures/sar_1_2.py
输出：src/assets/figures/sar/*.svg（直接内联进页面，文字随页面字体）

只追求“示意”：τ = 1、带宽 B = 10（时宽带宽积 10），线性调频起始频率 f0 = 2。
"""
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[2] / "src/assets/figures/sar"
OUT.mkdir(parents=True, exist_ok=True)

GREEN, ORANGE, DARK, AXIS, TEXT, MUTED, FILL = (
    "#4f7560", "#c0714c", "#2f4235", "#9aa093", "#3d4a40", "#8b947d", "#e3eadf")

TAU, B, F0 = 1.0, 10.0, 2.0
K = B / TAU  # 调频斜率


def chirp(t, down=False):
    """矩形包络的线性调频信号（实部），t ∈ [0, τ] 外为 0。"""
    tt = (TAU - t) if down else t
    s = np.cos(2 * np.pi * (F0 * tt + 0.5 * K * tt**2))
    return np.where((t >= 0) & (t <= TAU), s, 0.0)


class Panel:
    """一个带时间轴的小坐标区。"""

    def __init__(self, x, y, w, h, t0, t1, amp=1.0):
        self.x, self.y, self.w, self.h, self.t0, self.t1, self.amp = x, y, w, h, t0, t1, amp

    def px(self, t):
        return self.x + (np.asarray(t) - self.t0) / (self.t1 - self.t0) * self.w

    def py(self, v):
        return self.y + self.h / 2 - np.asarray(v) / self.amp * (self.h / 2)

    def path(self, t, v, color, width=1.6, fill=None, dash=None, opacity=1):
        xs, ys = self.px(t), self.py(v)
        d = "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in zip(xs, ys))
        if fill:
            d += f" L{xs[-1]:.1f},{self.py(0):.1f} L{xs[0]:.1f},{self.py(0):.1f} Z"
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        return (f'<path d="{d}" fill="{fill or "none"}" stroke="{color}" stroke-width="{width}"'
                f' stroke-linejoin="round" opacity="{opacity}"{extra}/>')

    def axis(self, label="t", ticks=(), vaxis_at=None):
        y0 = self.py(0)
        s = [f'<line x1="{self.x}" y1="{y0:.1f}" x2="{self.x + self.w + 8}" y2="{y0:.1f}" stroke="{AXIS}" stroke-width="1" marker-end="url(#arr)"/>',
             f'<text x="{self.x + self.w + 14}" y="{y0 + 5:.1f}" class="m">{label}</text>']
        if vaxis_at is not None:
            xv = self.px(vaxis_at)
            s.append(f'<line x1="{xv:.1f}" y1="{self.y + self.h + 4}" x2="{xv:.1f}" y2="{self.y - 6}" stroke="{AXIS}" stroke-width="1" marker-end="url(#arr)"/>')
        for t, txt in ticks:
            xt = self.px(t)
            s.append(f'<line x1="{xt:.1f}" y1="{y0 - 4:.1f}" x2="{xt:.1f}" y2="{y0 + 4:.1f}" stroke="{AXIS}"/>')
            s.append(f'<text x="{xt:.1f}" y="{self.y + self.h + 20:.1f}" class="m" text-anchor="middle">{txt}</text>')
        return "\n".join(s)


def svg(w, h, body, title):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" role="img" aria-label="{title}">
<title>{title}</title>
<defs>
  <marker id="arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{AXIS}"/></marker>
  <marker id="arrd" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{DARK}"/></marker>
</defs>
<style>
  text {{ font-family: inherit; fill: {TEXT}; font-size: 17px; }}
  .t {{ font-weight: 700; font-size: 18px; }}
  .m {{ fill: {MUTED}; font-size: 15px; }}
  .o {{ fill: {ORANGE}; font-weight: 700; }}
</style>
{body}
</svg>
'''


def bracket(x1, x2, y, label, color=ORANGE):
    return (f'<path d="M{x1:.1f},{y - 5} L{x1:.1f},{y} L{x2:.1f},{y} L{x2:.1f},{y - 5}" fill="none" stroke="{color}" stroke-width="1.4"/>'
            f'<text x="{(x1 + x2) / 2:.1f}" y="{y + 20}" text-anchor="middle" class="o">{label}</text>')


# ---------------------------------------------------------------- 图 1：整体过程
def fig_overview():
    t = np.linspace(-0.25, 2.25, 1400)
    W, X = 560, 40
    top = Panel(X, 50, W, 90, -0.25, 2.25)
    bot = Panel(X, 368, W, 90, -0.25, 2.25)

    # 输出：复包络 u(t)=e^{jπKt²} 的自相关（数值计算），峰值在 t0 = τ
    ts = np.linspace(0, TAU, 2000)
    u = np.exp(1j * np.pi * K * ts**2)
    dt = ts[1] - ts[0]
    lags = t - TAU
    env = np.array([abs(np.sum(u[(ts - l >= 0) & (ts - l <= TAU)] *
                               np.conj(np.exp(1j * np.pi * K * (ts[(ts - l >= 0) & (ts - l <= TAU)] - l) ** 2)))) * dt
                    for l in lags])
    env /= env.max()
    carrier = env * np.cos(2 * np.pi * (F0 + B / 2) * lags)

    b = [
        f'<text x="{X}" y="30" class="t">输入 s(t)：线性调频信号，时宽 τ 长、能量足</text>',
        top.axis(ticks=[(0, "0"), (TAU, "τ"), (2 * TAU, "2τ")]),
        top.path(t, chirp(t), GREEN),
        bracket(top.px(0), top.px(TAU), 182, "时宽 τ"),
        # 滤波器方框
        f'<line x1="{X + W / 2}" y1="214" x2="{X + W / 2}" y2="238" stroke="{DARK}" stroke-width="1.6" marker-end="url(#arrd)"/>',
        f'<rect x="{X + W / 2 - 170}" y="242" width="340" height="56" rx="6" fill="#f6ece3" stroke="{ORANGE}" stroke-width="1.5"/>',
        f'<text x="{X + W / 2}" y="266" text-anchor="middle" class="t">匹配滤波器</text>',
        f'<text x="{X + W / 2}" y="288" text-anchor="middle" class="m">h(t) = K·s*(t₀ − t)，取 t₀ = τ</text>',
        f'<line x1="{X + W / 2}" y1="300" x2="{X + W / 2}" y2="328" stroke="{DARK}" stroke-width="1.6" marker-end="url(#arrd)"/>',
        f'<text x="{X}" y="350" class="t">输出 y(t)：能量集中成窄脉冲，峰值出现在 t₀</text>',
        bot.axis(ticks=[(0, "0"), (TAU, "t₀ = τ"), (2 * TAU, "2τ")]),
        bot.path(t, carrier, GREEN, width=1, opacity=.45),
        bot.path(t, env, DARK, width=2.2),
        bracket(bot.px(TAU - 0.5 / B), bot.px(TAU + 0.5 / B), 486, "宽约 1/B"),
        f'<text x="{bot.px(1.55):.1f}" y="{bot.py(0.75):.1f}" class="m">粗线：复包络</text>',
    ]
    return svg(680, 520, "\n".join(b), "脉冲压缩示意：长的线性调频信号经匹配滤波器后变成窄脉冲")


# ---------------------------------------------------------------- 图 2：画 h(t) 的步骤
def fig_drawing():
    t = np.linspace(-1.3, 1.3, 1400)
    W, X = 540, 50
    rows = [
        ("① 原信号 s(t)：频率由低到高（上调频）", chirp(t), GREEN),
        ("② 关于纵轴翻转，得 s(−t)", chirp(-t), MUTED),
        ("③ 右移 t₀（取 t₀ = τ），得 h(t) = s(t₀ − t)：频率由高到低", chirp(TAU - t), ORANGE),
    ]
    b = []
    for i, (title, v, color) in enumerate(rows):
        y = 18 + i * 150
        p = Panel(X, y + 28, W, 80, -1.3, 1.3)
        b.append(f'<text x="{X - 30}" y="{y + 12}" class="t">{title}</text>')
        b.append(p.axis(ticks=[(-TAU, "−τ"), (0, "0"), (TAU, "τ")], vaxis_at=0))
        b.append(p.path(t, v, color))
        if i < 2:
            b.append(f'<line x1="{X + W + 40}" y1="{y + 80}" x2="{X + W + 40}" y2="{y + 170}" stroke="{AXIS}" stroke-width="1.4" stroke-dasharray="4 4" marker-end="url(#arr)"/>')
    return svg(660, 470, "\n".join(b), "由 s(t) 画匹配滤波器 h(t)：翻转、右移 t0")


# ---------------------------------------------------------------- 图 3：幅角匹配 → 同相叠加
def fig_phase():
    t = np.linspace(0, 2, 900)
    t0 = 1.0
    freqs = [2.0, 3.0, 4.5, 6.0]
    W, X = 520, 120
    b = [f'<text x="20" y="24" class="t">各频率分量经匹配滤波后，相位都被校正到在 t₀ 处取最大</text>']
    total = np.zeros_like(t)
    for i, f in enumerate(freqs):
        comp = np.cos(2 * np.pi * f * (t - t0)) * np.exp(-((t - t0) / 0.9) ** 2 * 0)  # 纯余弦
        total += comp
        p = Panel(X, 46 + i * 50, W, 40, 0, 2)
        b.append(f'<text x="20" y="{p.py(0) + 5:.1f}" class="m">分量 {i + 1}</text>')
        b.append(p.path(t, comp, GREEN, width=1.3))
    # 实际信号是连续频谱：把 [2, 7] 内大量分量相加（即 sinc 形尖峰）
    band = np.linspace(2.0, 7.0, 400)
    total = np.cos(2 * np.pi * np.outer(t - t0, band)).sum(axis=1)
    p = Panel(X, 270, W, 110, 0, 2, amp=total.max())
    b.append(f'<text x="20" y="{p.py(0) - 4:.1f}" class="t">全部分量</text>')
    b.append(f'<text x="20" y="{p.py(0) + 18:.1f}" class="t">叠加</text>')
    b.append(p.axis(ticks=[(t0, "t₀")]))
    b.append(p.path(t, total, DARK, width=2))
    x0 = p.px(t0)
    b.append(f'<line x1="{x0:.1f}" y1="40" x2="{x0:.1f}" y2="{p.y + p.h}" stroke="{ORANGE}" stroke-width="1.4" stroke-dasharray="5 4"/>')
    b.append(f'<text x="{x0 + 10:.1f}" y="{p.y + 16}" class="o">同相叠加 → 尖峰</text>')
    b.append(f'<text x="20" y="{p.y + p.h + 48}" class="m">其他时刻各分量相位不同，互相抵消，输出很小</text>')
    return svg(680, 450, "\n".join(b), "幅角匹配：所有频率分量在 t0 时刻同相叠加形成尖峰")


for name, fn in [("pulse-compression", fig_overview), ("matched-filter-drawing", fig_drawing),
                 ("phase-alignment", fig_phase)]:
    (OUT / f"{name}.svg").write_text(fn(), encoding="utf-8")
    print("wrote", OUT / f"{name}.svg")
