import Callout from './Callout.astro';
import Example from './Example.astro';
import Quiz from './Quiz.astro';
import Formula from './Formula.astro';
import Figure from './Figure.astro';

/** 传给 MDX <Content components={...} />，笔记里可直接使用这些标签 */
export const noteComponents = { Callout, Example, Quiz, Formula, Figure };
