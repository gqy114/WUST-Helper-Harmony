// 第二轮应用市场反馈：QQ 打开兜底、课表二维码保存/分享、双创错误文案。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(`${root}/${path}`, import.meta.url), 'utf8');

test('未安装 QQ 时不再弹系统选择框，直接复制群号', async () => {
  const page = await source('pages/profile/QQGroupPage.ets');
  assert.match(page, /bundleManager\.canOpenLink\(links\[0\]\)/, '打开前没有检测 QQ 是否安装');
  assert.match(page, /if \(canOpen\) \{/, '未安装时仍会尝试 openLink');
  assert.match(page, /未检测到 QQ，已复制群号/, '缺少未安装时的复制提示');
});

test('课表二维码：保存/分享按钮已接线', async () => {
  const page = await source('pages/course/CourseSharePage.ets');
  assert.match(page, /Button\('保存图片'\)[\s\S]*?\.onClick\(\(\) => \{ this\.saveQrImage\(\); \}\)/, '保存按钮没有响应');
  assert.match(page, /Button\('分享二维码'\)[\s\S]*?\.onClick\(\(\) => \{ this\.shareQrImage\(\); \}\)/, '分享按钮没有响应');
  assert.match(page, /getComponentSnapshot\(\)\.get\('courseShareQr'\)/, '保存/分享没有截图二维码');
  assert.match(page, /showAssetsCreationDialog/, '保存没有走向系统相册');
  assert.match(page, /new systemShare\.ShareController\(data\)/, '分享没有使用系统分享');
});

test('双创学分请求带 Platform，错误文案不再直接是“未知错误”', async () => {
  const api = await source('net/InnovationCreditApi.ets');
  assert.match(api, /Platform: 'android'/, '认证请求缺少 Platform');
  assert.doesNotMatch(api, /throw new Error\(message \|\| '双创学分认证失败'\);/, '仍会直接抛后端原始错误');
});

test('第二课堂服务异常时给出可读提示', async () => {
  const page = await source('pages/volunteer/VolunteerPage.ets');
  assert.match(page, /第二课堂服务暂不可用，请稍后重试/, '缺少服务不可用提示');
});
