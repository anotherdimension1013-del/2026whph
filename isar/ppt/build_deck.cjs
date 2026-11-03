// 汇报PPT生成脚本（pptxgenjs），版式参照学校汇报模板：
// 白底；左上灰色英文小节标签 + 深蓝衬线标题 + 浅灰分隔线；右上校徽；右下两位页码；
// 小标题深蓝加粗，正文灰色；强调数字用青色；表格黑色细边框，重点行浅青底。
// 用法：node ppt/build_deck.cjs   （先运行 tools/render_ppt_figs.py 生成 ppt/fig/*.png）
// 输出：ppt/ISAR_RADARSAT1_汇报.pptx
const path = require("path");
const fs = require("fs");
const JSZip = require("jszip");
const pptxgen = require(process.env.PPTXGEN || "pptxgenjs");
const { applyTheme } = require(process.env.APPLY_THEME);

const FIG = path.join(__dirname, "fig");
const OUT = path.join(__dirname, "ISAR_RADARSAT1_汇报.pptx");
const EA_FONT = "宋体"; // 中文字体（主题的东亚字体）

// ---------- 主题 ----------
const THEME = {
  name: "BUCT Report",
  headFontFace: "Times New Roman",
  bodyFontFace: "Times New Roman",
  colors: {
    dk1: "262626", lt1: "FFFFFF", dk2: "28578A", lt2: "F3F6F9",
    accent1: "28578A", accent2: "00848B", accent3: "6F8EB1", accent4: "AFBAC5",
    accent5: "B03A2E", accent6: "5A6570", hlink: "28578A", folHlink: "6F8EB1",
  },
};
const HEX = THEME.colors;
const RULE = "D9E0E8", ROWBG = "EAF4F4", LABEL = "68737D";

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "基于FEKO仿真的RADARSAT-1卫星ISAR成像";
const C = pres.SchemeColor;
const NAVY = C.accent1, TEAL = C.accent2, STEEL = C.accent3, RED = C.accent5, GREY = C.accent6, INK = C.text1;

// ---------- 版式 ----------
const logo = { path: path.join(FIG, "logo_buct.png"), x: 11.08, y: 0.45, w: 1.67, h: 0.44 };
pres.defineSlideMaster({
  title: "COVER",
  background: { color: HEX.lt1 },
  objects: [
    { image: Object.assign({}, logo, { x: 10.6, y: 0.55, w: 2.13, h: 0.56 }) },
    { line: { x: 0.6, y: 4.05, w: 5.9, h: 0, line: { color: RULE, width: 1 } } },
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 1.75, w: 5.9, h: 2.1,
      fontSize: 34, bold: true, color: C.accent1, valign: "bottom", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 4.3, w: 5.9, h: 0.5,
      fontSize: 20, color: C.accent6, align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: HEX.lt1 },
  margin: [0.5, 0.6, 0.5, 0.6],
  slideNumber: { x: 12.15, y: 7.05, w: 0.6, h: 0.3, fontSize: 10, color: HEX.accent6, align: "right" },
  objects: [
    { image: logo },
    { line: { x: 0.58, y: 1.29, w: 12.17, h: 0, line: { color: RULE, width: 1 } } },
    { placeholder: { options: { name: "title", type: "title", x: 0.58, y: 0.6, w: 10.2, h: 0.6,
      fontSize: 28, bold: true, color: C.accent1, valign: "middle", align: "left", margin: 0 }, text: "" } },
  ],
});

// ---------- 工具函数 ----------
function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}
// 在(x,y,w,h)框内等比放置图片；align: "c"居中 / "l"靠左 / "t"靠上
function img(slide, file, x, y, w, h, name, align) {
  const p = path.join(FIG, file);
  const s = pngSize(p);
  const r = Math.min(w / s.w, h / s.h);
  const iw = s.w * r, ih = s.h * r;
  const ix = align === "l" ? x : x + (w - iw) / 2;
  const iy = align === "t" ? y : y + (h - ih) / 2;
  slide.addImage({ path: p, x: ix, y: iy, w: iw, h: ih, objectName: name || file, altText: name || file });
  return { x: ix, y: iy, w: iw, h: ih };
}
// 模板元素：左上小节标签（灰色、大写英文）
function section(slide, text) {
  slide.addText(text, { x: 0.58, y: 0.28, w: 6, h: 0.25, fontSize: 10, bold: true, color: LABEL,
    charSpacing: 1, margin: 0, isTextBox: true, objectName: "小节标签" });
}
// 小标题（深蓝加粗）
function sub(slide, text, x, y, w, size, color) {
  slide.addText(text, { x, y, w, h: 0.42, fontSize: size || 19, bold: true, color: color || NAVY,
    margin: 0, valign: "middle", isTextBox: true, objectName: "小标题 " + text });
}
// 图片上方的灰色加粗图题（模板中“UAV frame”式样）
function head(slide, text, x, y, w, color, align) {
  slide.addText(text, { x, y, w, h: 0.36, fontSize: 15, bold: true, color: color || LABEL,
    align: align || "left", margin: 0, valign: "bottom", isTextBox: true, objectName: "图题 " + text });
}
// 正文：最多三句话，每句一段
function body(slide, sentences, x, y, w, h, size) {
  if (sentences.length > 3) throw new Error("每页正文不超过三句话");
  slide.addText(sentences.map((s, i) => ({ text: s, options: {
    breakLine: i < sentences.length - 1, paraSpaceAfter: 9 } })),
    { x, y, w, h, fontSize: size || 16, color: GREY, valign: "top", margin: 0,
      lineSpacingMultiple: 1.12, isTextBox: true, objectName: "正文" });
}
function caption(slide, text, x, y, w, align) {
  slide.addText(text, { x, y, w, h: 0.3, fontSize: 11, color: LABEL, align: align || "left",
    margin: 0, isTextBox: true, objectName: "图注" });
}
// 模板中的大号统计：青色大数字 + 灰色说明
function stat(slide, x, y, w, big, label, color) {
  slide.addText(big, { x, y, w, h: 0.7, fontSize: 36, bold: true, color: color || TEAL, margin: 0,
    valign: "bottom", isTextBox: true, objectName: "统计 " + label });
  slide.addText(label, { x, y: y + 0.75, w, h: 0.35, fontSize: 15, color: GREY, margin: 0,
    isTextBox: true });
}
// 图片位置提示（待插入的图片）
function placeholderBox(slide, x, y, w, h, text) {
  slide.addShape(pres.shapes.RECTANGLE, { x, y, w, h, fill: { color: HEX.lt2 },
    line: { color: HEX.accent4, width: 1, dashType: "dash" }, objectName: "待插入图片" });
  slide.addText(text, { x: x + 0.2, y: y + h / 2 - 0.3, w: w - 0.4, h: 0.6, fontSize: 15, color: LABEL,
    align: "center", margin: 0, isTextBox: true, objectName: "图片位置提示" });
}
// 数据来源小字（右下，页码左侧）
function dataNote(slide) {
  slide.addText("数据：简化 PO 预览（不计遮挡与多次反射）", { x: 7.2, y: 7.05, w: 4.8, h: 0.3,
    fontSize: 10, color: LABEL, align: "right", margin: 0, isTextBox: true, objectName: "数据来源" });
}
// 模板表格：黑色细边框，表头深蓝加粗，重点行浅青底青字
const BORDER = { type: "solid", pt: 1, color: "262626" };
const th = (t, o) => ({ text: t, options: Object.assign({ bold: true, color: HEX.accent1 }, o || {}) });
const td = (t, o) => ({ text: t, options: Object.assign({ color: HEX.accent6 }, o || {}) });
const hi = (t, o) => ({ text: t, options: Object.assign({ bold: true, color: HEX.accent2, fill: { color: ROWBG } }, o || {}) });
function table(slide, rows, opt) {
  slide.addTable(rows, Object.assign({ border: BORDER, valign: "middle", margin: 0.08,
    fill: { color: HEX.lt1 } }, opt));
}
function note(slide, t) { slide.addNotes(t); }

// ---------- 数值（简化PO预览，来自 results_metrics_po.md 和 ISAR_FEKO.m 的算法对比） ----------
const M = {
  E0: { n: 6, cov: 7, spot: 0.15 },
  Ac: { n: 29, cov: 38, spot: 0.18, w: 0.45 },
  coh: { n: 53, cov: 47, spot: 0.48 },
  mean: { n: 57, cov: 57, spot: 1.00 },
  geo: { n: 36, cov: 44, spot: 0.32 },
  B: { n: 53, cov: 53, spot: 0.34, w: 0.23 },
};

// ============ 0 封面 ============
pres.addSection({ title: "封面" });
let s = pres.addSlide({ masterName: "COVER", sectionTitle: "封面" });
s.addText("《合成孔径雷达》课程汇报", { x: 0.6, y: 1.3, w: 5.9, h: 0.3, fontSize: 12, bold: true,
  color: LABEL, charSpacing: 1, margin: 0, isTextBox: true });
s.addText("基于 FEKO 仿真的 RADARSAT-1 卫星 ISAR 成像", { placeholder: "title" });
s.addText("转台成像 · 子孔径融合 · 分辨率对比", { placeholder: "body" });
const cv = img(s, "cover_fusion.png", 6.9, 1.9, 5.85, 3.6, "封面：几何平均融合ISAR图像");
caption(s, "RADARSAT-1 的 ISAR 图像（ε = 30°，18 个子孔径几何平均融合）", 6.9, cv.y + cv.h + 0.1, 5.85, "center");
note(s, "大家好，我们的题目是用 FEKO 电磁仿真得到 RADARSAT-1 卫星的 ISAR 图像。右边这张图就是我们最终得到的融合图像。");

// ============ 1 引言 ============
pres.addSection({ title: "引言" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "引言" });
section(s, "INTRODUCTION");
s.addText("雷达能把卫星拍成什么样？", { placeholder: "title" });
sub(s, "真实雷达图像", 0.6, 1.5, 6.6);
placeholderBox(s, 0.6, 2.0, 6.6, 4.5, "在此插入：天宫一号 TIRA 雷达图像");
caption(s, "天宫一号 ISAR 图像（Fraunhofer FHR，TIRA 雷达，2018）", 0.6, 6.55, 6.6);
sub(s, "研究问题", 7.8, 1.5, 4.9);
body(s, [
  "雷达不受昼夜和天气限制，能给在轨卫星“拍照”。",
  "真实雷达图像中，卫星的主体和太阳翼清晰可辨。",
  "本文用电磁仿真复现这一过程，并探究怎样才能看出卫星的形状。",
], 7.8, 2.05, 4.9, 2.8, 18);
s.addText("怎样才能看出卫星的形状？", { x: 7.8, y: 5.3, w: 4.9, h: 0.6, fontSize: 22, bold: true,
  color: TEAL, margin: 0, isTextBox: true, objectName: "核心问题" });
note(s, "这是德国 TIRA 雷达拍到的天宫一号，能清楚看到本体和两块太阳翼。我们想知道，用仿真数据能不能得到这样的图像，以及需要什么条件。");

// ============ 2 相关工作 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "引言" });
section(s, "RELATED WORK");
s.addText("相关工作：用 FEKO 仿真空间目标 ISAR", { placeholder: "title" });
sub(s, "国际空间站的 FEKO 仿真", 0.6, 1.5, 7.2);
placeholderBox(s, 0.6, 2.0, 7.2, 4.5, "在此插入：ISS 论文图 2 的 (b) FEKO 模型与 (c) ISAR 图像");
caption(s, "国际空间站的 FEKO 仿真 ISAR 图像（ACES 期刊，作者与年份请核对原文）", 0.6, 6.55, 7.2);
sub(s, "本文的不同", 8.4, 1.5, 4.3);
body(s, [
  "已有工作用 FEKO 计算空间站的散射场，并生成了 ISAR 图像。",
  "本文沿用这一路线，目标换成以平板为主的 RADARSAT-1 卫星。",
  "平板只在特定角度反光，因此成像更具挑战。",
], 8.4, 2.05, 4.3, 4.0, 18);
note(s, "已有工作用 FEKO 仿真了国际空间站的 ISAR 图像。空间站有很多圆柱舱段，各个角度都有回波；而我们的卫星以平板为主，只在特定角度反光，这是本文要面对的难点。");

// ============ 3 原理 ============
pres.addSection({ title: "方法" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "方法" });
section(s, "METHOD");
s.addText("ISAR 成像原理：转台模型", { placeholder: "title" });
img(s, "turntable.png", 0.6, 1.45, 12.15, 4.1, "转台等效示意图");
stat(s, 0.6, 5.55, 3.2, "ρr = c / 2B", "距离分辨率：带宽越大越细", NAVY);
stat(s, 3.9, 5.55, 3.2, "ρa = λ / 2θm", "横向分辨率：转角越大越细", NAVY);
body(s, [
  "距离向靠带宽分辨，横向靠转动分辨。",
  "目标不动、雷达绕着转，FEKO 的“扫频 × 扫角”数据就等价于 ISAR 回波。",
], 7.5, 5.75, 5.25, 1.2, 16);
note(s, "左图：目标顺时针转动，等效于目标不动、雷达逆时针绕它转，所以 FEKO 里扫方位角就能得到 ISAR 回波。右图：每个频率和角度对应空间频率平面上的一个点，数据排成扇形。距离分辨率由带宽决定，横向分辨率由转角决定。");

// ============ 4 方法 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "方法" });
section(s, "METHOD");
s.addText("成像方法：三种算法并列，适用范围依次扩大", { placeholder: "title" });
const srcY = 1.6, rowH = 0.8, rowG = 0.2, rowsH = 3 * rowH + 2 * rowG;
s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: srcY, w: 2.2, h: rowsH, fill: { color: HEX.lt2 },
  line: { color: HEX.accent1, width: 1 }, objectName: "数据源" });
s.addText([
  { text: "FEKO 数据", options: { fontSize: 19, bold: true, color: NAVY, breakLine: true } },
  { text: "E(f, φ)", options: { fontSize: 17, color: INK, breakLine: true } },
  { text: "频率 × 方位角", options: { fontSize: 13, color: GREY } },
], { x: 0.7, y: srcY, w: 2.0, h: rowsH, align: "center", valign: "middle", margin: 0, isTextBox: true });
const branches = [
  { t: "RD", d: "扇形近似成矩形，直接二维 FFT", cond: "适用：小转角、窄带宽", use: "本文：B 数据，作对照（结果①）" },
  { t: "PFA", d: "先插值到矩形网格，再二维 FFT", cond: "解决：大转角/宽带宽下的散焦", use: "本文：B 数据（结果①）" },
  { t: "BP + 子孔径融合", d: "逐像素投影，分段成像后几何平均", cond: "解决：宽角观测与散射方向性", use: "本文：B（结果①）、A 的 60° 数据（②③④）" },
];
const bx = 3.7, bw = 4.4;
branches.forEach((b, i) => {
  const y = srcY + i * (rowH + rowG), cy = y + rowH / 2, sy = srcY + rowsH / 2;
  s.addShape(pres.shapes.LINE, { x: 2.8, y: Math.min(sy, cy), w: bx - 2.8, h: Math.max(Math.abs(cy - sy), 0.001),
    flipV: cy < sy, line: { color: HEX.accent1, width: 1.25, endArrowType: "triangle" }, objectName: "连线 " + b.t });
  s.addShape(pres.shapes.RECTANGLE, { x: bx, y, w: bw, h: rowH, fill: { color: i === 2 ? ROWBG : HEX.lt2 },
    line: { color: i === 2 ? HEX.accent2 : HEX.accent3, width: 1 }, objectName: "支路 " + b.t });
  s.addText([
    { text: b.t, options: { fontSize: 17, bold: true, color: i === 2 ? TEAL : NAVY, breakLine: true } },
    { text: b.d, options: { fontSize: 13, color: GREY } },
  ], { x: bx + 0.2, y, w: bw - 0.3, h: rowH, valign: "middle", margin: 0, isTextBox: true });
  s.addText([
    { text: b.cond, options: { fontSize: 14, color: INK, breakLine: true } },
    { text: b.use, options: { fontSize: 12, color: GREY } },
  ], { x: bx + bw + 0.3, y, w: 12.75 - (bx + bw + 0.3), h: rowH, valign: "middle", margin: 0, isTextBox: true });
});
s.addShape(pres.shapes.LINE, { x: 0.6, y: 4.75, w: 12.15, h: 0, line: { color: RULE, width: 1 }, objectName: "分隔线" });
sub(s, "几何平均融合（N 个子孔径）", 0.6, 4.95, 5.4);
s.addText("I = ( P₁ · P₂ · … · P_N )^(1/N)", { x: 0.6, y: 5.45, w: 5.6, h: 0.6, fontSize: 26, bold: true,
  color: TEAL, margin: 0, isTextBox: true });
s.addText("即各子孔径图像在 dB 域取平均", { x: 0.6, y: 6.1, w: 5.6, h: 0.4, fontSize: 15, color: GREY,
  margin: 0, isTextBox: true });
body(s, [
  "三种算法都直接处理同一份数据：RD 把扇形近似为矩形，转角或带宽一大就会散焦；PFA 先插值到矩形网格，消除这一误差。",
  "宽角观测时，每个部件只在一小段角度内反光，因此先分成 6.3° 的子孔径分别用 BP 成像。",
  "再按几何平均融合：只有在多数角度都亮的点才会保留下来。",
], 6.6, 4.98, 6.15, 2.0, 15);
note(s, "三种算法不是先后步骤，而是并列的，都直接处理同一份 FEKO 数据。RD 最简单，但假设转角和带宽很小；PFA 先把扇形数据插值到矩形网格，能处理更大的转角和带宽；60 度宽角时 PFA 也不够用，我们改用后向投影，每 6.3 度做一张子图，再把 18 张子图做几何平均。");

// ============ 5 实验设计 ============
pres.addSection({ title: "实验" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "EXPERIMENTS");
s.addText("目标与实验设计", { placeholder: "title" });
sub(s, "目标：RADARSAT-1", 0.6, 1.5, 4.6);
img(s, "model_3d.png", 0.6, 2.0, 4.6, 4.0, "RADARSAT-1 三维模型");
caption(s, "NASA 3D Resources 模型，翼展约 16 m", 0.6, 6.1, 4.6, "center");
sub(s, "三组仿真数据", 5.6, 1.5, 7.1);
table(s, [
  [th("数据"), th("俯仰角 ε"), th("带宽 / 转角"), th("分辨率"), th("用途")],
  [td("E0"), td("0°"), td("500 MHz / 5.5°"), td("0.3 m"), td("俯仰对比")],
  [td("A"), td("30°"), td("577 MHz / 60°（18 × 6.3°）"), td("0.3 m"), td("俯仰、融合对比")],
  [td("B"), td("30°"), td("1155 MHz / 12.5°"), td("0.15 m"), td("算法、分辨率对比")],
], { x: 5.6, y: 2.0, w: 7.15, colW: [0.7, 1.05, 2.5, 0.95, 1.95], fontSize: 14, rowH: 0.48, objectName: "实验参数表" });
s.addText("固定条件：5.3 GHz（C 波段）· VV 极化 · FEKO RL-GO · 中心方位 300°", { x: 5.6, y: 4.15, w: 7.15,
  h: 0.32, fontSize: 12, color: LABEL, margin: 0, isTextBox: true });
body(s, [
  "目标是加拿大 SAR 卫星 RADARSAT-1，在它自身的 C 波段用 RL-GO 计算单站散射场。",
  "三组数据分别改变俯仰角、观测角度和分辨率，构成四组对比。",
  "计算量与分辨率的平方成反比，0.3 m 单孔径只需 31 分钟。",
], 5.6, 4.65, 7.15, 2.2, 16);
note(s, "目标是 RADARSAT-1，用 NASA 公开的三维模型。E0 是雷达与卫星同高；A 把雷达抬高 30 度并扫 60 度；B 把分辨率提高到 0.15 米。");

// ============ 6 结果①：RD / PFA / BP ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "RESULTS");
s.addText("结果①：三种算法对比，RD 在边缘散焦", { placeholder: "title" });
dataNote(s);
const ALG = [
  { f: "alg_rd.png", t: "RD（小转角近似）", spot: "0.44", cost: "直接二维 FFT", c: RED },
  { f: "alg_pfa.png", t: "PFA（极坐标插值）", spot: "0.042", cost: "插值 + FFT · 0.06 s", c: NAVY },
  { f: "alg_bp.png", t: "BP（后向投影）", spot: "0.038", cost: "逐像素累加 · 10 s", c: NAVY },
];
const aw = 3.85, ag = 0.3;
ALG.forEach((d, i) => {
  const x = 0.6 + i * (aw + ag);
  head(s, d.t, x, 1.45, aw);
  img(s, d.f, x, 1.9, aw, 3.1, d.t, "l");
  s.addText([
    { text: d.spot + " m²", options: { fontSize: 24, bold: true, color: i ? TEAL : RED } },
    { text: "  −3 dB 光斑", options: { fontSize: 13, color: GREY } },
  ], { x, y: 5.05, w: aw, h: 0.45, margin: 0, valign: "middle", isTextBox: true });
  s.addText(d.cost, { x, y: 5.5, w: aw, h: 0.28, fontSize: 12, color: LABEL, margin: 0, isTextBox: true });
});
body(s, [
  "同一份 B 数据、同一网格上，RD 把离中心最远的点拉成 L 形拖尾，光斑是另外两种的 10 倍以上。",
  "PFA 和 BP 都把它聚焦成一个点，位置一致，互相印证。",
  "PFA 快，BP 慢约两个数量级但不受转角限制，所以 60° 宽角数据改用 BP。",
], 0.6, 5.95, 12.15, 1.05, 15);
note(s, "三种算法处理同一份 B 数据，放大的是离旋转中心最远的散射点，窗口约 2 米见方。边缘点的距离徙动约 1.65 米，RD 的小转角近似不再成立，这个点被拉成 L 形，-3 dB 光斑 0.44 平方米。PFA 和 BP 都恢复成一个点，约 0.04 平方米，而且位置相同。PFA 只要 0.06 秒，BP 要 10 秒，但 BP 没有转角限制，所以后面 60 度的宽角数据都用 BP。");

// ============ 7 结果②：俯仰角 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "RESULTS");
s.addText("结果②：俯仰角决定“看见什么”", { placeholder: "title" });
dataNote(s);
[["eps0.png", "ε = 0°：雷达与卫星同高"], ["eps30.png", "ε = 30°：雷达在斜上方"]].forEach((d, i) => {
  const x = 0.6 + i * 6.2;
  head(s, d[1], x, 1.45, 5.95, i ? NAVY : LABEL);
  img(s, d[0], x, 1.9, 5.95, 2.8, d[1], "l");
});
stat(s, 0.6, 4.85, 2.9, `${M.E0.n} → ${M.Ac.n}`, "散射中心个数");
stat(s, 3.6, 4.85, 2.9, `${M.E0.cov}% → ${M.Ac.cov}%`, "轮廓覆盖率");
body(s, [
  "雷达与卫星同高时，几乎水平的太阳翼只露出侧棱，图上只剩天线上的几个亮点。",
  "抬高 30° 后太阳翼被照到，形状开始显现。",
  "但单张图仍只能看到一部分部件。",
], 6.8, 4.95, 5.95, 1.9, 16);
note(s, "两张图分辨率相同。雷达与卫星同高时，几乎水平的太阳翼只露出侧棱，图上只剩天线上的几个亮点。雷达抬高 30 度后，散射中心从 6 个增加到 29 个，轮廓覆盖率从 7% 提高到 38%。");

// ============ 8 结果③：融合 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "RESULTS");
s.addText("结果③：几何平均融合拼出更完整的形状", { placeholder: "title" });
dataNote(s);
const fu = [
  ["fu_single.png", "单个子孔径", M.Ac],
  ["fu_coh.png", "60° 整段相干", M.coh],
  ["fu_mean.png", "算术平均融合", M.mean],
  ["fu_geo.png", "几何平均融合", M.geo],
];
const gw = 4.25, gh = 2.0;
fu.forEach((d, i) => {
  const x = 0.6 + (i % 2) * (gw + 0.3), y = 1.45 + Math.floor(i / 2) * (gh + 0.75);
  s.addText([
    { text: d[1], options: { bold: true, color: i === 3 ? TEAL : LABEL, fontSize: 15 } },
    { text: `   ${d[2].n} 个 · 覆盖 ${d[2].cov}% · 光斑 ${d[2].spot.toFixed(2)} m²`, options: { color: GREY, fontSize: 12 } },
  ], { x, y, w: gw, h: 0.36, margin: 0, valign: "bottom", isTextBox: true, objectName: "图题 " + d[1] });
  img(s, d[0], x, y + 0.42, gw, gh, d[1], "l");
});
stat(s, 9.75, 1.45, 3.0, `${M.Ac.cov}% → ${M.geo.cov}%`, "覆盖率（对比单孔径）");
stat(s, 9.75, 2.75, 3.0, `${M.geo.spot.toFixed(2)} m²`, `光斑（算术平均 ${M.mean.spot.toFixed(2)} m²）`);
body(s, [
  "单个子孔径只能看到局部，整段相干和算术平均又被少数强闪光拉成拖影。",
  "几何平均相当于在 dB 域取平均，只保留在多数角度都亮的点。",
], 9.75, 4.2, 3.0, 2.6, 15);
note(s, "同一份 60 度数据的四种处理。整段相干成像会被少数镜面闪光主导，形成长条；算术平均让任意一张子图里的闪光都留在结果里。几何平均只保留跨角度持续存在的散射中心，所以既比单张完整，又没有拖影，光斑只有算术平均的三分之一。这一思路与 Moses 等人提出的散射中心有限持续性一致，几何平均的做法借鉴了 Gasnier 等人对 SAR 多幅图像的几何平均。");

// ============ 9 结果④：分辨率 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "RESULTS");
s.addText("结果④：提高分辨率的效果与代价", { placeholder: "title" });
dataNote(s);
[["res_030.png", "zoom_030.png", "0.3 m（A 单个子孔径）"], ["res_015.png", "zoom_015.png", "0.15 m（B）"]].forEach((d, i) => {
  const y = 1.45 + i * 2.75;
  head(s, d[2], 0.6, y, 5.6, i ? NAVY : LABEL);
  img(s, d[0], 0.6, y + 0.42, 5.6, 2.2, d[2], "l");
  img(s, d[1], 6.35, y + 0.42, 2.2, 2.2, d[2] + " 局部");
});
stat(s, 9.0, 1.45, 3.75, `${M.Ac.w.toFixed(2)} → ${M.B.w.toFixed(2)} m`, "−3 dB 点宽度");
stat(s, 9.0, 2.75, 3.75, `${M.Ac.cov}% → ${M.B.cov}%`, "轮廓覆盖率");
stat(s, 9.0, 4.05, 3.75, "≈ 4×", "计算点数", NAVY);
body(s, [
  "分辨率提高一倍，散射点宽度减半，但计算点数约为 4 倍。",
  "覆盖率的提高有一部分来自 B 的转角加倍，而不只是分辨率。",
], 9.0, 5.45, 3.75, 1.5, 15);
note(s, "0.15 米分辨率下散射点明显更细，宽度从 0.45 米降到 0.23 米。但计算量随分辨率平方增长，约为 4 倍。B 的转角是 12.5 度，比单个子孔径大一倍，所以覆盖率的提高不能完全归功于分辨率。");

// ============ 10 散射机理 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "实验" });
section(s, "RESULTS");
s.addText("散射机理：亮的是结构的“不连续处”", { placeholder: "title" });
dataNote(s);
head(s, "几何平均融合图像中的 10 个主要散射中心", 0.6, 1.45, 8.0);
img(s, "scatter.png", 0.6, 1.9, 8.0, 3.75, "主要散射中心标注", "l");
table(s, [
  [th("编号"), th("部件"), th("强度")],
  [td("1, 2"), td("天线桁架与本体连接处"), td("0 ~ −1 dB")],
  [td("4, 6, 7, 8"), td("SAR 天线下边沿"), td("−6 ~ −9 dB")],
  [td("3, 5, 9, 10"), td("本体角点"), td("−4 ~ −10 dB")],
], { x: 8.9, y: 1.95, w: 3.85, colW: [1.05, 1.75, 1.05], fontSize: 12, rowH: 0.55, objectName: "散射中心表" });
body(s, [
  "最强的回波来自桁架连接处和天线边沿，而不是天线的大平面。",
  "太阳翼的回波来自电池板之间的拼缝。",
  "斜视时平面不把能量反射回雷达，图像上亮的是棱边、拼缝和角点。",
], 0.6, 5.85, 12.15, 1.15, 15);
note(s, "图中标出了融合图像里最强的 10 个散射中心。最强的两个在天线桁架与本体的连接处，SAR 天线下边沿形成一排亮点，太阳翼上则是电池板拼缝。斜视观测时大平面的镜面反射方向偏离雷达，亮的都是结构的不连续处。");

// ============ 11 结论 ============
pres.addSection({ title: "结论" });
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "结论" });
section(s, "CONCLUSION");
s.addText("结论与不足", { placeholder: "title" });
dataNote(s);
sub(s, "轮廓覆盖率对比", 0.6, 1.45, 7.0);
s.addChart(pres.charts.BAR, [{
  name: "轮廓覆盖率",
  labels: ["ε=0°", "ε=30° 单孔径", "ε=30° 高分辨率", "ε=30° 几何平均融合"],
  values: [M.E0.cov, M.Ac.cov, M.B.cov, M.geo.cov],
}], {
  x: 0.6, y: 1.9, w: 7.0, h: 2.45, barDir: "bar", barGapWidthPct: 45,
  chartColors: [HEX.accent4, HEX.accent3, HEX.accent3, HEX.accent2], // 单系列：逐条着色
  showValue: true, dataLabelPosition: "outEnd", dataLabelFormatCode: '0"%"', dataLabelColor: HEX.accent1,
  dataLabelFontSize: 12, dataLabelFontBold: true, dataLabelFontFace: "+mn-lt",
  catAxisLabelColor: HEX.accent6, catAxisLabelFontSize: 12, catAxisLabelFontFace: "+mn-lt",
  valAxisLabelColor: HEX.accent6, valAxisLabelFontSize: 10, valAxisLabelFontFace: "+mn-lt",
  valAxisMinVal: 0, valAxisMaxVal: 60, valAxisMajorUnit: 20, valAxisLabelFormatCode: '0"%"',
  valGridLine: { color: "E5E9EE", size: 0.75 }, catGridLine: { style: "none" },
  catAxisLineShow: false, valAxisLineShow: false, showLegend: false, showTitle: false,
  invertedColors: [HEX.accent4, HEX.accent3, HEX.accent3, HEX.accent2],
  objectName: "覆盖率条形图",
});
body(s, [
  "能否看出形状首先取决于观测几何：抬高俯仰角、再按几何平均融合多个角度，形状最完整；提高分辨率主要让散射点更精细。",
  "不足：以上为不计遮挡与多次反射的简化 PO 预览，FEKO 的 A、B 数据仍在计算，斜视还带来叠掩。",
  "下一步用 FEKO 数据复核结论，并尝试三维 ISAR。",
], 8.0, 1.5, 4.75, 2.9, 15);
table(s, [
  [th("方案"), th("分辨率"), th("散射中心"), th("覆盖率"), th("计算量"), th("能看出什么")],
  [td("ε = 0°"), td("0.3 m"), td(`${M.E0.n} 个`), td(`${M.E0.cov}%`), td("31 min"), td("只有天线上几个亮点")],
  [td("ε = 30° 单孔径"), td("0.3 m"), td(`${M.Ac.n} 个`), td(`${M.Ac.cov}%`), td("1×"), td("局部部件")],
  [td("ε = 30° 高分辨率"), td("0.15 m"), td(`${M.B.n} 个`), td(`${M.B.cov}%`), td("≈4×"), td("散射点更精细")],
  [hi("ε = 30° 几何平均融合"), hi("0.3 m"), hi(`${M.geo.n} 个`), hi(`${M.geo.cov}%`), hi("≈9×（60°）"), hi("本体、太阳翼、天线轮廓")],
], { x: 0.6, y: 4.6, w: 12.15, colW: [2.9, 1.3, 1.5, 1.4, 1.85, 3.2], fontSize: 14, rowH: 0.43,
  objectName: "结论汇总表" });
note(s, "总结一下：要看出卫星形状，关键是观测几何和角度多样性，而不是一味提高分辨率。目前的数字来自简化 PO 预览，FEKO 正式数据算完后会更新。");

// ============ 12 参考文献 ============
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "结论" });
section(s, "REFERENCES");
s.addText("参考文献", { placeholder: "title" });
const refs = [
  "D. A. Ausherman et al., “Developments in radar imaging,” IEEE Trans. AES, 20(4), 1984.",
  "J. L. Walker, “Range-Doppler imaging of rotating objects,” IEEE Trans. AES, 16(1): 23–52, 1980.",
  "R. L. Moses, L. C. Potter, M. Çetin, “Wide angle SAR imaging,” Proc. SPIE 5427, 2004.",
  "C. Gasnier, L. Denis, F. Tupin, “On the use and denoising of the temporal geometric mean for SAR time series,” IEEE GRSL, 2022.",
  "FEKO Simulation of Radar Scattering from Objects in Low Earth Orbit for ISAR Imaging, ACES Journal（作者待核对）.",
  "Fraunhofer FHR, TIRA 天宫一号雷达图像, 2018；NASA 3D Resources, RADARSAT-1 模型.",
];
s.addText(refs.map((r, i) => ({ text: `[${i + 1}]  ${r}`, options: { breakLine: i < refs.length - 1, paraSpaceAfter: 10 } })),
  { x: 0.6, y: 1.55, w: 12.15, h: 5.2, fontSize: 15, color: GREY, valign: "top", margin: 0, isTextBox: true,
    objectName: "参考文献列表" });
note(s, "谢谢大家，欢迎提问。");

// 写文件 → 应用主题颜色 → 主题字体加上中文（东亚）字体
pres.writeFile({ fileName: OUT }).then(async () => {
  await applyTheme(OUT, THEME);
  const zip = await JSZip.loadAsync(fs.readFileSync(OUT));
  for (const f of Object.keys(zip.files).filter((n) => /^ppt\/theme\/theme\d+\.xml$/.test(n))) {
    let x = await zip.file(f).async("string");
    x = x.replace(/<a:ea typeface="[^"]*"\s*\/>/g, `<a:ea typeface="${EA_FONT}"/>`);
    zip.file(f, x);
  }
  fs.writeFileSync(OUT, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
  console.log("已生成", OUT);
});
