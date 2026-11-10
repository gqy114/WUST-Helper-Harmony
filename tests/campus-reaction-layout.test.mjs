// 校园墙详情页的表情标签需要自适应换行，不能被 Blank 挤出屏幕。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pagePath = '../entry/src/main/ets/pages/campus/CampusPostDetailPage.ets';
const source = () => readFile(new URL(pagePath, import.meta.url), 'utf8');

test('表情标签使用换行 Flex 并右对齐，不使用 layoutWeight 占位', async () => {
  const page = await source();
  const start = page.indexOf('Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End');
  assert.ok(start > 0, '缺少表情标签容器');
  const block = page.slice(start, page.indexOf('.margin({ top: 18 })', start));
  assert.doesNotMatch(block, /Blank\(\)\.layoutWeight\(1\)/, 'wrap 容器里不能放 layoutWeight 的 Blank');
  assert.match(block, /justifyContent: FlexAlign\.End/, '标签应右对齐');
  assert.match(block, /alignItems: ItemAlign\.Center/, '标签应垂直居中');
  assert.match(block, /\.maxLines\(1\)/, '标签文字不能被挤压换行');
});

test('表情标签通过 Flex 换行适配窄屏', async () => {
  const page = await source();
  assert.match(page, /Flex\(\{ wrap: FlexWrap\.Wrap, justifyContent: FlexAlign\.End/, '缺少自适应换行容器');
  assert.match(page, /ForEach\(DETAIL_REACTIONS/, '缺少表情列表');
  assert.match(page, /this\.reactionsOpen \|\| this\.reactionCount\(option\.type\) > 0/, '表情显示条件被改动');
});
