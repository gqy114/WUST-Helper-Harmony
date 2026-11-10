// 发版：版本号统一在 AppScope/app.json5，页面不再写死。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('应用版本已升到 1.0.3 / 1000003', async () => {
  const app = await source(`${root}AppScope/app.json5`);
  assert.match(app, /"versionName":\s*"1\.0\.3"/, 'versionName 未更新');
  assert.match(app, /"versionCode":\s*1000003/, 'versionCode 未更新');
});

test('页面版本号从 bundle 读取，不再写死', async () => {
  const about = await source(`${root}entry/src/main/ets/pages/profile/AboutPage.ets`);
  assert.match(about, /Text\(AppVersion\.label\(\)\)/, '关于页没有使用动态版本号');
  assert.doesNotMatch(about, /v5\.3\.0\.172/, '关于页仍有旧硬编码版本');

  const mine = await source(`${root}entry/src/main/ets/pages/mine/MinePage.ets`);
  assert.match(mine, /Text\(AppVersion\.label\(\)\)/, '个人页没有使用动态版本号');
  assert.doesNotMatch(mine, /v5\.2\.8/, '个人页仍有旧硬编码版本');
});

test('AppVersion 读取 bundleManager 的 versionName 并提供缓存', async () => {
  const util = await source(`${root}entry/src/main/ets/utils/AppVersion.ets`);
  assert.match(util, /bundleManager\.getBundleInfoForSelfSync/, '没有读取安装包版本');
  assert.match(util, /info\.versionName/, '没有取 versionName');
  assert.match(util, /return `v\$\{name \|\| '1\.0\.3'\}`/, '兜底版本号不一致');
});
