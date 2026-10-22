# 学习手账

使用 Astro 构建的中文学习笔记博客。当前首页整理线性系统理论中的能观测性、矩阵指数与约当块。

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

当前长篇笔记和首页布局位于 src/pages/index.astro。提交并推送到 master 后，GitHub Actions 会自动更新线上博客。后续笔记增多时，可以将每篇笔记拆成独立的 Markdown 内容，再由首页按日期、主题和摘要生成列表。
