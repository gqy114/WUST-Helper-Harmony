// 外部链接：QQ 群跳转与网页加载错误提示。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('QQ 群优先用 openLink 打开深链，失败再退回 Want 与复制', async () => {
  const page = await source(`${root}/ets/pages/profile/QQGroupPage.ets`);
  assert.match(page, /await context\.openLink\(links\[i\]\)/, '缺少 openLink 跳转');
  assert.match(page, /mqqapi:\/\/card\/show_pslcard\?src_type=internal&version=1&uin=\$\{QQ_GROUP_NUMBER\}/, '缺少群卡片深链');
  assert.match(page, /await context\.startAbility\(want\)/, '缺少 Want 兜底');
  assert.match(page, /this\.copyGroupNumber\(\);\s*\n\s*promptAction\.showToast\(\{ message: '未检测到 QQ/, '打不开时没有复制兜底');
});

test('module.json5 声明 QQ scheme，系统才允许查询/拉起', async () => {
  const config = await source(`${root}/module.json5`);
  assert.match(config, /"querySchemes": \[/, '缺少 querySchemes');
  assert.match(config, /"mqq"/, '缺少 mqq scheme');
  assert.match(config, /"mqqapi"/, '缺少 mqqapi scheme');
});

test('网页证书错误给出可读提示，并保留浏览器兜底', async () => {
  const page = await source(`${root}/ets/pages/common/WebPage.ets`);
  assert.match(page, /code <= -200 && code >= -299/, '没有识别证书错误');
  assert.match(page, /网站证书异常，暂时无法打开/, '缺少证书错误提示');
  assert.match(page, /Button\('在浏览器打开'\)/, '缺少浏览器兜底');
  assert.match(page, /Button\('重试'\)/, '缺少重试');
});
