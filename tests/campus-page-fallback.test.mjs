// 校园页远端资讯不可用时必须退出白屏并提供本地校园服务。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pageUrl = new URL('../entry/src/main/ets/pages/campus/CampusPage.ets', import.meta.url);
const source = () => readFile(pageUrl, 'utf8');

test('校园资讯加载失败、HTTP 错误和超时都有可见兜底', async () => {
  const code = await source();

  assert.match(code, /\.onErrorReceive\(/, '缺少 WebView 主文档错误处理');
  assert.match(code, /\.onHttpErrorReceive\(/, '缺少 HTTP 错误处理');
  assert.match(code, /const LOAD_TIMEOUT_MS = 12_000;/, '缺少无回调时的超时保护');
  assert.match(code, /if \(this\.loadError\) \{\s*this\.fallbackContent\(\)/,
    '加载失败后没有切换到本地兜底页');
  assert.match(code, /Button\('重新加载'\)/, '兜底页缺少重试入口');
});

test('加载结束后校验实际页面内容，不能把空白页当作成功', async () => {
  const code = await source();

  assert.match(code, /\.onPageEnd\(\(\) => \{\s*this\.scheduleContentCheck\(\);\s*\}\)/,
    'onPageEnd 没有触发页面内容校验');
  assert.match(code, /this\.controller\.runJavaScript\(script\)/,
    '缺少 WebView DOM 内容检查');
  assert.match(code, /contentScore < MIN_CONTENT_SCORE/,
    '空页面没有切换到失败兜底');
  assert.doesNotMatch(code, /\.onPageEnd\(\(\) => \{\s*this\.clearLoadTimer\(\);\s*this\.loading = false;/,
    'onPageEnd 仍在未校验内容时直接标记成功');
});

test('兜底页保留常用校园服务入口', async () => {
  const code = await source();
  const routes = [
    'pages/campus/SchoolCalendarPage',
    'pages/campus/SchoolBusPage',
    'pages/campus/YellowPagesPage',
    'pages/course/PhysicalExperimentPage',
  ];

  for (const route of routes) {
    assert.match(code, new RegExp(route.replaceAll('/', '\\/')), `缺少本地入口：${route}`);
  }
});

test('校园页不绕过 HTTPS 证书校验', async () => {
  const code = await source();
  assert.doesNotMatch(code, /onSslErrorEventReceive|handleConfirm\s*\(/,
    '不应通过忽略证书错误加载校园资讯');
});

test('已经报错的导航，错误页有文字也不算加载成功', async () => {
  const code = await source();

  assert.match(code, /private navigationError: boolean = false;/, '缺少本次导航空错误标记');
  assert.match(code, /if \(this\.navigationError\) \{[\s\S]*?navigation failed[\s\S]*?return;/,
    '内容校验没有先判断本次导航是否报错');
  assert.match(code, /this\.navigationError = true;/,
    '收到主文档错误时没有记录');
  assert.match(code, /\.onPageBegin\(\(\) => \{[\s\S]*?this\.beginNavigation\(\);/,
    '新导航开始时没有重置错误标记');
});

test('重试后旧页面的异步检查结果不再生效', async () => {
  const code = await source();

  assert.match(code, /private navigationToken: number = 0;/, '缺少导航标识');
  assert.match(code, /private beginNavigation\(\): void \{[\s\S]*?this\.navigationToken = this\.navigationToken \+ 1;/,
    '开始新导航时没有递增标识');
  assert.match(code, /if \(token !== this\.navigationToken\) return;/,
    '异步回调没有校验导航标识');
  assert.match(code, /private retry\(\): void \{[\s\S]*?this\.beginNavigation\(\);/,
    '重试没有开启新的导航标识');
  assert.match(code, /aboutToDisappear\(\): void \{[\s\S]*?this\.navigationToken = this\.navigationToken \+ 1;/,
    '页面销毁后旧回调仍可能改状态');
});
