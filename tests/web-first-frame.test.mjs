// WebView 首帧：先渲染页面框架，再创建 Web，避免点击后转场被 Web 初始化卡住。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const page = () => readFile(new URL('../entry/src/main/ets/pages/common/WebPage.ets', import.meta.url), 'utf8');

test('WebPage 延迟创建 Web 并先显示加载占位', async () => {
  const source = await page();
  assert.match(source, /@State private webReady: boolean = false;/, '没有延迟 Web 的开关');
  assert.match(source, /setTimeout\(\(\) => \{ this\.webReady = true; \}, 80\)/, '没有在转场后再挂载 Web');
  assert.match(source, /else if \(!this\.webReady\)/, '缺少首帧加载占位分支');
  assert.match(source, /正在打开页面…/, '占位没有提示文案');
  assert.match(source, /Web\(\{ src: this\.pageUrl/, 'Web 组件缺失');
});
