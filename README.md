# 学习手账

使用 Astro 构建的中文学习笔记博客。首页是笔记目录，目前包括：

- 能观测性学习笔记（线性系统理论）：/observability/
- SAR 学习笔记（合成孔径雷达）：/sar/

## 本地预览

~~~sh
npm install
npm run dev
~~~

打开终端显示的本地地址（通常是 http://localhost:4321）。

## 构建

~~~sh
npm run build
npm run preview
~~~

构建产物输出到 dist/。

## 发布

网站部署在 GitHub Pages：
https://anotherdimension1013-del.github.io/2026whph/

.github/workflows/deploy.yml 会在 master 分支收到推送后自动构建和发布，也可以在 GitHub 仓库的 Actions 页面手动运行。第一次发布前，请在仓库 Settings → Pages → Build and deployment 中将 Source 设为 GitHub Actions。

Astro 的 site 和 base 已按项目站点地址配置。新增站内页面链接时，使用 Astro 的 base 感知路径或相对链接，避免部署后遗漏 /2026whph/ 前缀。

## 更新笔记

每篇笔记是 src/content/notes/ 下的一个 .mdx 文件，文件名即网址（sar.mdx → /sar/）。首页列表、导航栏、目录和上下篇翻页都会自动生成。

- 头部字段（frontmatter）：title、heading、short、tagline、description、eyebrow、course、question、order、status（可选），含义见 src/content.config.ts。
- 公式：行内用 `$...$`，独立公式用 `$$...$$`，构建时由 KaTeX 渲染；教材编号用 `\tag{1-1-1}`。
- 二级标题 `##` 作为章节，会进入“本页目录”。
- 可直接使用的组件（无需 import）：
  - `<Callout kind="exam|extra|tip" title="...">…</Callout>`：必考 / 补充 / 要点便签，不写 kind 为普通说明；
  - `<Formula meaning="..." point="...">$$…$$</Formula>`：公式卡片（含义 + 考点）；
  - `<Example n="01" title="...">…</Example>`：例题框；
  - `<Quiz q="问题">答案</Quiz>`：可折叠自测题。

样式统一在 src/styles/notes.css，页面框架在 src/layouts/Base.astro 和 src/pages/[slug].astro。
