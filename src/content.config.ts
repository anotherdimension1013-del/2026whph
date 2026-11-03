import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const notes = defineCollection({
  loader: glob({ pattern: '**/*.mdx', base: './src/content/notes' }),
  schema: z.object({
    title: z.string(),
    /** 首屏大标题第一行 */
    heading: z.string(),
    /** 导航栏短名 */
    short: z.string(),
    /** 首屏大标题第二行（强调色） */
    tagline: z.string(),
    description: z.string(),
    /** 英文小标题，如 LINEAR SYSTEMS */
    eyebrow: z.string(),
    /** 课程 / 章节 */
    course: z.string(),
    /** 便签上的核心问题，用 \n 换行 */
    question: z.string(),
    order: z.number(),
    status: z.string().optional(),
  }),
});

export const collections = { notes };
