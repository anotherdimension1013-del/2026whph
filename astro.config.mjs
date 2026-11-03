// @ts-check
import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import remarkCjkFriendly from 'remark-cjk-friendly';

// https://astro.build/config
export default defineConfig({
  // The repository is published as a GitHub Pages project site.
  site: 'https://anotherdimension1013-del.github.io',
  base: '/2026whph',
  trailingSlash: 'always',
  integrations: [mdx()],
  markdown: {
    // remark-cjk-friendly：修复 **加粗** 紧邻中文标点时不生效的问题。
    // 公式用 $...$ / $$...$$ 书写，构建时由 KaTeX 渲染成静态 HTML。
    remarkPlugins: [remarkMath, remarkCjkFriendly],
    rehypePlugins: [[rehypeKatex, { strict: false }]],
  },
});
