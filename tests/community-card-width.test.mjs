import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('校园社区卡片文字与热门功能左侧对齐，副标题有足够宽度', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/main/MainPage.ets', import.meta.url), 'utf8');
  const start = page.indexOf('private CardItem(item: CardItem)');
  const block = page.slice(start, page.indexOf('// ═', start));
  assert.doesNotMatch(block, /margin\(\{ left: 10 \}\)/, '卡片文字仍比热门功能多缩进 10');
  assert.match(block, /padding\(\{ left: 12, right: 8, top: 14, bottom: 14 \}\)/, '卡片右侧没有给文字留出与热门功能相同的宽度');
  assert.match(block, /maxLines\(1\)[\s\S]*?textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\)/, '副标题仍可能被截断');
});
