// 汇报PPT生成脚本（pptxgenjs）
// 用法：node ppt/build_deck.cjs   （先运行 tools/render_ppt_figs.py 生成 ppt/fig/*.png）
// 输出：ppt/ISAR_RADARSAT1_汇报.pptx
const path = require("path");
const fs = require("fs");
const pptxgen = require(process.env.PPTXGEN || "pptxgenjs");
const { applyTheme } = require(process.env.APPLY_THEME);

const FIG = path.join(__dirname, "fig");
const OUT = path.join(__dirname, "ISAR_RADARSAT1_汇报.pptx");

// ---------- 主题：深空背景 + ISAR热力色（琥珀）+ 模型轮廓色（青） ----------
const THEME = {
  name: "ISAR Deep Space",
  headFontFace: "Microsoft YaHei",
  bodyFontFace: "Microsoft YaHei",
  colors: {
    dk1: "0B1220", lt1: "EAF0F7", dk2: "16213A", lt2: "93A3B8",
    accent1: "FFB020", accent2: "4DD9FF", accent3: "7CFF9B", accent4: "FF6B5A",
    accent5: "2A3A55", accent6: "C9D3E0", hlink: "4DD9FF", folHlink: "93A3B8",
  },
};
const HEX = THEME.colors;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "基于FEKO仿真的RADARSAT-1卫星ISAR成像";
const C = pres.SchemeColor;
// 深色主题下：background1=lt1（浅），text1=dk1（深）。正文用 background1，面板用 text2
const TXT = C.background1, MUTED = C.background2, PANEL = C.text2, BGC = C.text1;
const AMBER = C.accent1, CYAN = C.accent2, GREEN = C.accent3, RED = C.accent4, LINE = C.accent5;

// ---------- 版式 ----------
pres.defineSlideMaster({
  title: "COVER",
  background: { color: HEX.dk1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.7, y: 4.35, w: 11.9, h: 1.1,
      fontSize: 34, bold: true, color: C.background1, valign: "top", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.7, y: 5.5, w: 11.9, h: 0.55,
      fontSize: 20, color: C.accent1, align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: HEX.dk1 },
  margin: [0.5, 0.6, 0.5, 0.6],
  slideNumber: { x: 12.35, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: HEX.lt2, align: "right" },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.38, w: 10.4, h: 0.75,
      fontSize: 30, bold: true, color: C.background1, valign: "middle", align: "left", margin: 0 }, text: "" } },
    { text: { text: "RADARSAT-1 卫星 ISAR 成像", options: { x: 0.6, y: 7.0, w: 5, h: 0.3,
      fontSize: 10, color: HEX.lt2, margin: 0 } } },
  ],
});

// ---------- 工具函数 ----------
function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}
// 在(x,y,w,h)框内等比放置图片，居中
function fitImage(slide, file, x, y, w, h, name) {
  const p = path.join(FIG, file);
  const s = pngSize(p);
  const r = Math.min(w / s.w, h / s.h);
  const iw = s.w * r, ih = s.h * r;
  slide.addImage({ path: p, x: x + (w - iw) / 2, y: y + (h - ih) / 2, w: iw, h: ih,
    objectName: name || file, altText: name || file });
  return { x: x + (w - iw) / 2, y: y + (h - ih) / 2, w: iw, h: ih };
}
// 视觉母题：圆角“雷达屏”框（深色面板 + 青色细边），图片放在框内
function screen(slide, x, y, w, h, name, light) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12,
    fill: { color: light ? "FFFFFF" : HEX.dk2 }, line: { color: HEX.accent2, width: 1 },
    objectName: name + " 框" });
}
function framedImage(slide, file, x, y, w, h, name, light) {
  screen(slide, x, y, w, h, name, light);
  return fitImage(slide, file, x + 0.12, y + 0.12, w - 0.24, h - 0.24, name);
}
// 右上角标签（例如“实验 ②”“数据：简化PO预览”）
function tag(slide, text, x, w, muted) {
  slide.addText(text, { x, y: 0.5, w, h: 0.42, fontSize: 12, bold: true, color: muted ? MUTED : BGC,
    align: "center", valign: "middle", margin: 0, isTextBox: true,
    shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.21, fill: { color: muted ? HEX.dk2 : HEX.accent1 },
    line: muted ? { color: HEX.accent5, width: 0.75 } : undefined, objectName: "标签 " + text });
}
// 正文：最多三句话，每句一段
function body(slide, sentences, x, y, w, h, size) {
  if (sentences.length > 3) throw new Error("每页正文不超过三句话");
  slide.addText(sentences.map((s, i) => ({ text: s, options: {
    breakLine: i < sentences.length - 1, paraSpaceAfter: 10 } })),
    { x, y, w, h, fontSize: size || 17, color: TXT, valign: "top", margin: 0,
      lineSpacingMultiple: 1.15, isTextBox: true, objectName: "正文" });
}
function caption(slide, text, x, y, w, align) {
  slide.addText(text, { x, y, w, h: 0.32, fontSize: 11, color: MUTED, align: align || "left",
    margin: 0, isTextBox: true, objectName: "图注" });
}
// 大数字对比：before → after
function statPair(slide, x, y, label, a, b, unit) {
  slide.addText(label, { x, y, w: 3.6, h: 0.3, fontSize: 12, color: MUTED, margin: 0, isTextBox: true });
  slide.addText([
    { text: a, options: { color: MUTED, fontSize: 30, bold: true } },
    { text: "  →  ", options: { color: MUTED, fontSize: 20 } },
    { text: b, options: { color: AMBER, fontSize: 40, bold: true } },
    { text: unit ? " " + unit : "", options: { color: AMBER, fontSize: 18 } },
  ], { x, y: y + 0.3, w: 3.6, h: 0.7, margin: 0, valign: "middle", isTextBox: true });
}
function note(slide, t) { slide.addNotes(t); }

// ---------- 数值（简化PO预览，来自 results_metrics_po.md） ----------
const M = {
  E0: { n: 6, cov: 7, spot: 0.15 },
  Ac: { n: 29, cov: 38, spot: 0.18, w: 0.45 },
  coh: { n: 53, cov: 47, spot: 0.48 },
  mean: { n: 57, cov: 57, spot: 1.00 },
  geo: { n: 36, cov: 44, spot: 0.32 },
  B: { n: 53, cov: 53, spot: 0.34, w: 0.23 },
};
const PO_TAG = "数据：简化PO预览";

// ============ 0 封面 ============
pres.addSection({ title: "封面" });
let s = pres.addSlide({ masterName: "COVER", sectionTitle: "封面" });
fitImage(s, "cover_fusion.png", 1.2, 0.35, 10.9, 3.85, "封面：几何平均融合ISAR图像");
s.addText("基于 FEKO 仿真的 RADARSAT-1 卫星 ISAR 成像", { placeholder: "title" });
s.addText("转台成像 · 子孔径融合 · 分辨率对比", { placeholder: "body" });
s.addText("《合成孔径雷达》课程汇报", { x: 0.7, y: 6.55, w: 6, h: 0.35, fontSize: 14, color: MUTED,
  margin: 0, isTextBox: true });
note(s, "大家好，我们的题目是用 FEKO 电磁仿真得到 RADARSAT-1 卫星的 ISAR 图像。背景这张图就是我们最终得到的融合图像。");

// ============ 1 引言 ============
pres.addSection({ title: "引言" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "引言" });
s.addText("雷达能把卫星拍成什么样", { placeholder: "title" });
screen(s, 0.6, 1.45, 6.6, 5.1, "TIRA 图像");
s.addText("在此插入：天宫一号 TIRA 雷达图像", { x: 0.8, y: 3.6, w: 6.2, h: 0.6, fontSize: 16,
  color: MUTED, align: "center", margin: 0, isTextBox: true, objectName: "图片位置提示" });
caption(s, "天宫一号 ISAR 图像（Fraunhofer FHR，TIRA 雷达，2018）", 0.6, 6.6, 6.6);
body(s, [
  "雷达不受昼夜和天气限制，能给在轨卫星“拍照”。",
  "真实雷达图像中，卫星的主体和太阳翼清晰可辨。",
  "本文用电磁仿真复现这一过程，并探究怎样才能看出卫星的形状。",
], 7.7, 1.75, 5.0, 3.2, 19);
s.addText("怎样才能看出卫星的形状？", { x: 7.7, y: 5.2, w: 5.0, h: 0.8, fontSize: 22, bold: true,
  color: AMBER, margin: 0, isTextBox: true, objectName: "核心问题" });
note(s, "这是德国 TIRA 雷达拍到的天宫一号，能清楚看到本体和两块太阳翼。我们想知道，用仿真数据能不能得到这样的图像，以及需要什么条件。");

// ============ 2 相关工作 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "引言" });
s.addText("相关工作：用 FEKO 仿真空间目标 ISAR", { placeholder: "title" });
screen(s, 0.6, 1.45, 7.4, 5.1, "ISS 图像");
s.addText("在此插入：ISS 论文图 2 的 (b) FEKO 模型与 (c) ISAR 图像", { x: 0.8, y: 3.6, w: 7.0,
  h: 0.6, fontSize: 16, color: MUTED, align: "center", margin: 0, isTextBox: true, objectName: "图片位置提示" });
caption(s, "国际空间站的 FEKO 仿真 ISAR 图像（ACES 期刊，作者与年份请核对原文）", 0.6, 6.6, 7.4);
body(s, [
  "已有工作用 FEKO 计算空间站的散射场，并生成了 ISAR 图像。",
  "本文沿用这一路线，目标换成以平板为主的 RADARSAT-1 卫星。",
  "平板只在特定角度反光，因此成像更具挑战。",
], 8.5, 1.75, 4.2, 4.0, 18);
note(s, "已有工作用 FEKO 仿真了国际空间站的 ISAR 图像。空间站有很多圆柱舱段，各个角度都有回波；而我们的卫星以平板为主，只在特定角度反光，这是本文要面对的难点。");

// ============ 3 原理 ============
pres.addSection({ title: "方法" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "方法" });
s.addText("ISAR 成像原理：转台模型", { placeholder: "title" });
framedImage(s, "turntable.png", 0.6, 1.4, 12.1, 4.15, "转台等效示意图", true);
const fx = [["距离分辨率", "ρr = c / 2B", "带宽 B 越大越细"], ["横向分辨率", "ρa = λ / 2θm", "转角 θm 越大越细"]];
fx.forEach((f, i) => {
  const x = 0.6 + i * 3.35;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 5.8, w: 3.15, h: 1.0, rectRadius: 0.1,
    fill: { color: HEX.dk2 }, line: { color: HEX.accent5, width: 0.75 }, objectName: f[0] });
  s.addText(f[0], { x: x + 0.2, y: 5.88, w: 2.8, h: 0.3, fontSize: 12, color: MUTED, margin: 0, isTextBox: true });
  s.addText(f[1], { x: x + 0.2, y: 6.18, w: 2.8, h: 0.55, fontSize: 24, bold: true, color: AMBER, margin: 0,
    isTextBox: true, fontFace: "Cambria" });
});
body(s, [
  "距离向靠带宽分辨，横向靠转动分辨。",
  "目标不动、雷达绕着转，FEKO 的“扫频 × 扫角”数据就等价于 ISAR 回波。",
], 7.4, 5.8, 5.3, 1.1, 16);
note(s, "左图：目标顺时针转动，等效于目标不动、雷达逆时针绕它转，所以 FEKO 里扫方位角就能得到 ISAR 回波。右图：每个频率和角度对应空间频率平面上的一个点，数据排成扇形。距离分辨率由带宽决定，横向分辨率由转角决定。");

// ============ 4 方法 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "方法" });
s.addText("成像方法：三种算法各解决一个问题", { placeholder: "title" });
const steps = [
  { t: "FEKO 数据", d: "E(f, φ)\n频率 × 方位角", c: HEX.accent6 },
  { t: "RD", d: "把扇形近似成矩形\n直接二维 FFT", c: HEX.accent1 },
  { t: "PFA", d: "先插值到矩形网格\n消除扇形误差", c: HEX.accent1 },
  { t: "BP + 子孔径融合", d: "宽角分段成像\n几何平均融合", c: HEX.accent2 },
];
const sw = 2.6, sg = 0.55, sy = 1.7;
steps.forEach((st, i) => {
  const x = 0.6 + i * (sw + sg);
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: sy, w: sw, h: 1.9, rectRadius: 0.12,
    fill: { color: HEX.dk2 }, line: { color: st.c, width: 1.5 }, objectName: "步骤 " + st.t });
  s.addText(st.t, { x: x + 0.15, y: sy + 0.2, w: sw - 0.3, h: 0.5, fontSize: 20, bold: true,
    color: st.c, align: "center", margin: 0, isTextBox: true });
  s.addText(st.d, { x: x + 0.15, y: sy + 0.8, w: sw - 0.3, h: 0.9, fontSize: 14, color: TXT,
    align: "center", margin: 0, isTextBox: true });
  if (i < steps.length - 1) {
    s.addShape(pres.shapes.RIGHT_ARROW, { x: x + sw + 0.1, y: sy + 0.75, w: sg - 0.2, h: 0.4,
      fill: { color: HEX.lt2 }, line: { color: HEX.lt2, width: 0 }, objectName: "箭头" });
  }
});
const probs = ["", "适用于小转角、窄带宽", "解决：大转角/宽带宽下的散焦", "解决：散射的方向性"];
probs.forEach((p, i) => {
  if (!p) return;
  s.addText(p, { x: 0.6 + i * (sw + sg), y: sy + 2.0, w: sw, h: 0.35, fontSize: 12, color: MUTED,
    align: "center", margin: 0, isTextBox: true });
});
// 几何平均公式卡片
s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 4.5, w: 5.6, h: 2.1, rectRadius: 0.12,
  fill: { color: HEX.dk2 }, line: { color: HEX.accent5, width: 0.75 }, objectName: "融合公式" });
s.addText("几何平均融合（N 个子孔径）", { x: 0.85, y: 4.65, w: 5.1, h: 0.35, fontSize: 13, color: MUTED,
  margin: 0, isTextBox: true });
s.addText("I = ( P₁ · P₂ · … · P_N )^(1/N)", { x: 0.85, y: 5.05, w: 5.1, h: 0.6, fontSize: 24, bold: true,
  color: CYAN, margin: 0, isTextBox: true, fontFace: "Cambria" });
s.addText("= 各子孔径图像在 dB 域取平均", { x: 0.85, y: 5.75, w: 5.1, h: 0.4, fontSize: 14, color: TXT,
  margin: 0, isTextBox: true });
body(s, [
  "RD 把扇形数据近似为矩形，转角或带宽一大就会散焦，PFA 先插值到矩形网格来消除这一误差。",
  "宽角观测时，每个部件只在一小段角度内反光，因此先分成 6.3° 的子孔径分别用 BP 成像。",
  "再按几何平均融合：只有在多数角度都亮的点才会保留下来。",
], 6.7, 4.55, 6.0, 2.2, 16);
note(s, "RD 是最基本的算法，但它假设转角很小。PFA 把扇形数据插值到矩形网格，能处理更大的转角和带宽。60 度宽角观测时，我们用后向投影把每 6.3 度做成一张子图，再把 18 张子图做几何平均。几何平均相当于在 dB 域取平均，只有在多数角度都存在的散射点才会保留。");

// ============ 5 实验设计 ============
pres.addSection({ title: "实验" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("目标与实验设计", { placeholder: "title" });
framedImage(s, "model_3d.png", 0.6, 1.4, 4.6, 4.2, "RADARSAT-1 三维模型", true);
caption(s, "RADARSAT-1（NASA 3D Resources，翼展约 16 m）", 0.6, 5.68, 4.6);
const hdr = (t) => ({ text: t, options: { bold: true, color: HEX.dk1, fill: { color: HEX.accent1 }, align: "center" } });
const cell = (t, o) => ({ text: t, options: Object.assign({ color: HEX.lt1, align: "center" }, o || {}) });
s.addTable([
  [hdr("数据"), hdr("俯仰角 ε"), hdr("带宽 / 转角"), hdr("分辨率"), hdr("用途")],
  [cell("E0", { bold: true }), cell("0°"), cell("500 MHz / 5.5°"), cell("0.3 m"), cell("俯仰对比")],
  [cell("A", { bold: true }), cell("30°"), cell("577 MHz / 60°\n（18 个 6.3° 子孔径）"), cell("0.3 m"), cell("俯仰、融合对比")],
  [cell("B", { bold: true }), cell("30°"), cell("1155 MHz / 12.5°"), cell("0.15 m"), cell("算法、分辨率对比")],
], { x: 5.6, y: 1.45, w: 7.1, colW: [0.9, 1.2, 2.2, 1.1, 1.7], fontSize: 13, rowH: [0.45, 0.55, 0.8, 0.55],
  fill: { color: HEX.dk2 }, border: { type: "solid", pt: 0.75, color: HEX.accent5 }, valign: "middle",
  objectName: "实验参数表" });
s.addText("固定条件：5.3 GHz（C 波段）· VV 极化 · FEKO RL-GO · 中心方位 300°", { x: 5.6, y: 4.0, w: 7.1,
  h: 0.35, fontSize: 12, color: MUTED, margin: 0, isTextBox: true });
body(s, [
  "目标是加拿大 SAR 卫星 RADARSAT-1，在它自身的 C 波段用 RL-GO 计算单站散射场。",
  "三组数据分别改变俯仰角、观测角度和分辨率，构成四组对比。",
  "计算量与分辨率的平方成反比，0.3 m 单孔径只需 31 分钟。",
], 5.6, 4.6, 7.1, 2.1, 16);
note(s, "目标是 RADARSAT-1，用 NASA 公开的三维模型。E0 是雷达与卫星同高；A 把雷达抬高 30 度并扫 60 度；B 把分辨率提高到 0.15 米。");

// ============ 6 结果①：RD vs PFA ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("结果①：PFA 校正边缘散焦", { placeholder: "title" });
tag(s, PO_TAG, 10.6, 2.1, true);
[["rd_zoom.png", "RD（小转角近似）", RED], ["pfa_zoom.png", "PFA（极坐标插值）", GREEN]].forEach((d, i) => {
  const x = 0.6 + i * 3.95;
  framedImage(s, d[0], x, 1.45, 3.75, 3.75, d[1]);
  s.addText(d[1], { x, y: 5.3, w: 3.75, h: 0.4, fontSize: 16, bold: true, color: d[2], align: "center",
    margin: 0, isTextBox: true });
});
caption(s, "B 数据（0.15 m）中离中心最远的散射点，窗口 2 m × 2 m", 0.6, 5.8, 7.7);
s.addText([
  { text: "1.65 m", options: { fontSize: 48, bold: true, color: AMBER, breakLine: true } },
  { text: "边缘点的距离徙动 ≈ 11 个分辨单元", options: { fontSize: 13, color: MUTED } },
], { x: 8.9, y: 1.5, w: 3.8, h: 1.4, margin: 0, isTextBox: true, objectName: "距离徙动" });
body(s, [
  "B 的转角和带宽较大，RD 把边缘的点拉成一条 L 形的拖尾。",
  "PFA 先校正扇形数据，把它恢复成一个点。",
  "点聚焦好了，但能不能看出卫星的形状？",
], 8.9, 3.3, 3.8, 3.0, 17);
note(s, "B 数据转角 12.5 度、带宽 1.15 GHz，边缘点的距离徙动约 1.65 米。RD 中这个点被拉成 L 形，PFA 恢复为一个点。算法问题解决了，下面看形状。");

// ============ 7 结果②：俯仰角 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("结果②：俯仰角决定“看见什么”", { placeholder: "title" });
tag(s, PO_TAG, 10.6, 2.1, true);
[["eps0.png", "ε = 0°：雷达与卫星同高"], ["eps30.png", "ε = 30°：雷达在斜上方"]].forEach((d, i) => {
  const y = 1.4 + i * 2.4;
  framedImage(s, d[0], 0.6, y, 7.6, 2.25, d[1]);
  s.addText(d[1], { x: 8.45, y: y + 0.1, w: 4.3, h: 0.35, fontSize: 14, bold: true,
    color: i ? CYAN : MUTED, margin: 0, isTextBox: true });
});
statPair(s, 8.45, 1.85, "散射中心个数", String(M.E0.n), String(M.Ac.n), "个");
statPair(s, 8.45, 4.25, "轮廓覆盖率", M.E0.cov + "%", M.Ac.cov + "%", "");
body(s, [
  "同高时太阳翼只露出侧棱；抬高 30° 后太阳翼被照到，覆盖率从 7% 升到 38%。",
  "但单张图仍只能看到一部分部件。",
], 0.6, 6.15, 12.1, 0.75, 15);
note(s, "两张图分辨率相同。雷达与卫星同高时，几乎水平的太阳翼只露出侧棱，图上只剩天线上的几个亮点。雷达抬高 30 度后，散射中心从 6 个增加到 29 个，轮廓覆盖率从 7% 提高到 38%。");

// ============ 8 结果③：融合 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("结果③：几何平均融合拼出更完整的形状", { placeholder: "title" });
tag(s, PO_TAG, 10.6, 2.1, true);
const fu = [
  ["fu_single.png", "单个子孔径", M.Ac, MUTED],
  ["fu_coh.png", "60° 整段相干", M.coh, MUTED],
  ["fu_mean.png", "算术平均融合", M.mean, MUTED],
  ["fu_geo.png", "几何平均融合", M.geo, AMBER],
];
const gw = 4.35, gh = 2.05;
fu.forEach((d, i) => {
  const x = 0.6 + (i % 2) * (gw + 0.2), y = 1.4 + Math.floor(i / 2) * (gh + 0.6);
  framedImage(s, d[0], x, y, gw, gh, d[1]);
  s.addText([
    { text: d[1], options: { bold: true, color: d[3] === AMBER ? AMBER : TXT } },
    { text: `   ${d[2].n} 个 · 覆盖 ${d[2].cov}% · 光斑 ${d[2].spot.toFixed(2)} m²`, options: { color: MUTED } },
  ], { x, y: y + gh + 0.05, w: gw, h: 0.35, fontSize: 12, margin: 0, isTextBox: true });
});
body(s, [
  "每个部件只在特定角度反光，单个子孔径只能看到局部；整段相干和算术平均又会被少数强闪光拉成拖影。",
  "几何平均相当于在 dB 域取平均，只保留在多数角度都亮的点。",
  "覆盖率从 38% 提高到 44%，光斑面积只有算术平均的三分之一。",
], 9.75, 1.45, 3.0, 5.2, 15);
note(s, "同一份 60 度数据的四种处理。整段相干成像会被少数镜面闪光主导，形成长条；算术平均让任意一张子图里的闪光都留在结果里。几何平均只保留跨角度持续存在的散射中心，所以既比单张完整，又没有拖影。这一思路与 Moses 等人提出的散射中心有限持续性一致，几何平均的做法借鉴了 Gasnier 等人对 SAR 多幅图像的几何平均。");

// ============ 9 结果④：分辨率 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("结果④：提高分辨率的效果与代价", { placeholder: "title" });
tag(s, PO_TAG, 10.6, 2.1, true);
[["res_030.png", "zoom_030.png", "0.3 m（A 单个子孔径）"], ["res_015.png", "zoom_015.png", "0.15 m（B）"]].forEach((d, i) => {
  const y = 1.4 + i * 2.75;
  framedImage(s, d[0], 0.6, y, 5.6, 2.3, d[2]);
  framedImage(s, d[1], 6.35, y, 2.3, 2.3, d[2] + " 局部");
  s.addText(d[2], { x: 0.6, y: y + 2.3, w: 5.6, h: 0.3, fontSize: 12, bold: true, color: i ? AMBER : MUTED,
    margin: 0, isTextBox: true });
});
statPair(s, 9.0, 1.4, "−3 dB 点宽度", M.Ac.w.toFixed(2), M.B.w.toFixed(2), "m");
statPair(s, 9.0, 2.6, "轮廓覆盖率", M.Ac.cov + "%", M.B.cov + "%", "");
statPair(s, 9.0, 3.8, "计算点数", "1×", "≈4×", "");
body(s, [
  "分辨率提高一倍，散射点宽度减半，但计算点数约为 4 倍。",
  "覆盖率的提高有一部分来自 B 的转角加倍，而不只是分辨率。",
], 9.0, 5.05, 3.75, 1.8, 15);
note(s, "0.15 米分辨率下散射点明显更细，宽度从 0.45 米降到 0.23 米。但计算量随分辨率平方增长，约为 4 倍。B 的转角是 12.5 度，比单个子孔径大一倍，所以覆盖率的提高不能完全归功于分辨率。");

// ============ 10 散射机理 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
s.addText("散射机理：亮的是结构的“不连续处”", { placeholder: "title" });
tag(s, PO_TAG, 10.6, 2.1, true);
framedImage(s, "scatter.png", 0.6, 1.4, 8.1, 4.1, "主要散射中心标注");
s.addTable([
  [hdr("编号"), hdr("部件"), hdr("强度")],
  [cell("1, 2"), cell("天线桁架与本体连接处"), cell("0 ~ −1 dB")],
  [cell("4, 6, 7, 8"), cell("SAR 天线下边沿"), cell("−6 ~ −9 dB")],
  [cell("3, 5, 9, 10"), cell("本体角点"), cell("−4 ~ −10 dB")],
], { x: 8.95, y: 1.45, w: 3.8, colW: [1.0, 1.75, 1.05], fontSize: 12, rowH: 0.6,
  fill: { color: HEX.dk2 }, border: { type: "solid", pt: 0.75, color: HEX.accent5 }, valign: "middle",
  objectName: "散射中心表" });
body(s, [
  "最强的回波来自桁架连接处和天线边沿，而不是天线的大平面。",
  "太阳翼的回波来自电池板之间的拼缝。",
  "斜视时平面不把能量反射回雷达，图像上亮的是棱边、拼缝和角点。",
], 0.6, 5.75, 12.1, 1.2, 15);
note(s, "图中标出了融合图像里最强的 10 个散射中心。最强的两个在天线桁架与本体的连接处，SAR 天线下边沿形成一排亮点，太阳翼上则是电池板拼缝。斜视观测时大平面的镜面反射方向偏离雷达，亮的都是结构的不连续处。");

// ============ 11 结论 ============
pres.addSection({ title: "结论" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "结论" });
s.addText("结论与不足", { placeholder: "title" });
s.addTable([
  [hdr("方案"), hdr("分辨率"), hdr("散射中心 / 覆盖率"), hdr("计算量"), hdr("能看出什么")],
  [cell("ε = 0°"), cell("0.3 m"), cell(`${M.E0.n} 个 / ${M.E0.cov}%`), cell("31 min"), cell("只有天线上几个亮点")],
  [cell("ε = 30° 单孔径"), cell("0.3 m"), cell(`${M.Ac.n} 个 / ${M.Ac.cov}%`), cell("1×"), cell("局部部件")],
  [cell("ε = 30° 几何平均融合", { bold: true, color: HEX.accent1 }), cell("0.3 m"),
    cell(`${M.geo.n} 个 / ${M.geo.cov}%`, { bold: true, color: HEX.accent1 }), cell("≈9×（60° 数据）"),
    cell("本体、太阳翼、天线轮廓", { bold: true, color: HEX.accent1 })],
  [cell("ε = 30° 高分辨率"), cell("0.15 m"), cell(`${M.B.n} 个 / ${M.B.cov}%`), cell("≈4×"), cell("散射点更精细")],
], { x: 0.6, y: 1.45, w: 12.1, colW: [2.9, 1.3, 2.6, 2.3, 3.0], fontSize: 14, rowH: 0.55,
  fill: { color: HEX.dk2 }, border: { type: "solid", pt: 0.75, color: HEX.accent5 }, valign: "middle",
  objectName: "结论汇总表" });
body(s, [
  "能否看出形状首先取决于观测几何：抬高俯仰角，再把多个角度按几何平均融合，形状最完整；提高分辨率只让散射点更精细。",
  "不足：以上为不计遮挡与多次反射的简化 PO 预览，FEKO 的 A、B 数据仍在计算；斜视还带来叠掩。",
  "下一步用 FEKO 数据复核结论，并尝试三维 ISAR。",
], 0.6, 4.5, 12.1, 2.3, 16);
note(s, "总结一下：要看出卫星形状，关键是观测几何和角度多样性，而不是一味提高分辨率。目前的数字来自简化 PO 预览，FEKO 正式数据算完后会更新。");

// ============ 12 参考文献 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "结论" });
s.addText("参考文献", { placeholder: "title" });
const refs = [
  "D. A. Ausherman et al., “Developments in radar imaging,” IEEE Trans. AES, 20(4), 1984.",
  "J. L. Walker, “Range-Doppler imaging of rotating objects,” IEEE Trans. AES, 16(1): 23–52, 1980.",
  "R. L. Moses, L. C. Potter, M. Çetin, “Wide angle SAR imaging,” Proc. SPIE 5427, 2004.",
  "C. Gasnier, L. Denis, F. Tupin, “On the use and denoising of the temporal geometric mean for SAR time series,” IEEE GRSL, 2022.",
  "FEKO Simulation of Radar Scattering from Objects in Low Earth Orbit for ISAR Imaging, ACES Journal（作者待核对）.",
  "Fraunhofer FHR, TIRA 天宫一号雷达图像, 2018；NASA 3D Resources, RADARSAT-1 模型.",
];
s.addText(refs.map((r, i) => ({ text: `[${i + 1}]  ${r}`, options: { breakLine: i < refs.length - 1, paraSpaceAfter: 8 } })),
  { x: 0.6, y: 1.45, w: 12.1, h: 5.2, fontSize: 14, color: TXT, valign: "top", margin: 0, isTextBox: true,
    objectName: "参考文献列表" });
note(s, "谢谢大家，欢迎提问。");

pres.writeFile({ fileName: OUT }).then(async () => {
  await applyTheme(OUT, THEME);
  console.log("已生成", OUT);
});
