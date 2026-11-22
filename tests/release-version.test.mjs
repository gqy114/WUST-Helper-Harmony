// 发版：版本号统一在 AppScope/app.json5，页面不再写死。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('应用版本号合法且不低于 1.0.2 / 1000002', async () => {
  const app = await source(`${root}AppScope/app.json5`);
  const nameMatch = /"versionName":\s*"(\d+)\.(\d+)\.(\d+)"/.exec(app);
  const codeMatch = /"versionCode":\s*(\d+)/.exec(app);
  assert.ok(nameMatch, '缺少合法 versionName');
  assert.ok(codeMatch, '缺少 versionCode');
  const major = Number(nameMatch[1]);
  const minor = Number(nameMatch[2]);
  const patch = Number(nameMatch[3]);
  assert.ok(major > 1 || (major === 1 && minor > 0) || (major === 1 && minor === 0 && patch >= 2),
    `versionName 低于 1.0.2：${nameMatch[0]}`);
  assert.ok(Number(codeMatch[1]) >= 1000002, `versionCode 低于 1000002：${codeMatch[1]}`);
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
  assert.match(util, /return `v\$\{name \|\| '1\.0\.2'\}`/, '兜底版本号不一致');
});
