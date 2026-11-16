// 第二轮应用市场反馈：QQ 打开兜底、课表二维码保存/分享、双创错误文案。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(`${root}/${path}`, import.meta.url), 'utf8');

test('未安装 QQ 时不再弹系统选择框，直接复制群号', async () => {
  const page = await source('pages/profile/QQGroupPage.ets');
  assert.match(page, /bundleManager\.canOpenLink\(links\[i\]\)/, '只检测了第一种打开方式');
  assert.match(page, /openable\.push\(links\[i\]\)/, '没有收集可打开的链接');
  assert.match(page, /未检测到 QQ，已复制群号/, '缺少未安装时的复制提示');
});

test('课表二维码：保存/分享按钮已接线', async () => {
  const page = await source('pages/course/CourseSharePage.ets');
  assert.match(page, /Button\('保存图片'\)[\s\S]*?\.onClick\(\(\) => \{ this\.saveQrImage\(\); \}\)/, '保存按钮没有响应');
  assert.match(page, /Button\('分享二维码'\)[\s\S]*?\.onClick\(\(\) => \{ this\.shareQrImage\(\); \}\)/, '分享按钮没有响应');
  assert.match(page, /getComponentSnapshot\(\)\.get\('courseShareQr'\)/, '保存/分享没有截图二维码');
  assert.match(page, /fileUri\.getUriFromPath\(path\)/, '文件 URI 没有用 SDK 接口生成');
  assert.match(page, /showAssetsCreationDialog/, '保存没有走向系统相册');
  assert.match(page, /new systemShare\.ShareController\(data\)/, '分享没有使用系统分享');
});

test('双创学分请求带 Platform，错误文案不再直接是“未知错误”', async () => {
  const api = await source('net/InnovationCreditApi.ets');
  assert.match(api, /Platform: 'android'/, '认证请求缺少 Platform');
  assert.doesNotMatch(api, /throw new Error\(message \|\| '双创学分认证失败'\);/, '仍会直接抛后端原始错误');
});

test('志愿工时服务异常时给出对应提示，不冒充第二课堂', async () => {
  const page = await source('pages/volunteer/VolunteerPage.ets');
  assert.match(page, /志愿工时服务暂不可用，请稍后重试/, '缺少志愿工时服务提示');
  assert.doesNotMatch(page, /第二课堂服务暂不可用/, '志愿工时页面不应提示第二课堂');
});

test('工时码无效/过期时提示码的问题，而不是服务不可用', async () => {
  const page = await source('pages/volunteer/VolunteerPage.ets');
  assert.match(page, /工时码无效或已过期，请核对后重试/, '缺少工时码无效提示');
  const codeIndex = page.indexOf("message.indexOf('工时码')");
  const serviceIndex = page.indexOf("message.indexOf('无效')");
  assert.ok(codeIndex >= 0 && codeIndex < serviceIndex, '应先判断工时码，再判断服务不可用');
});

test('QQ 只尝试系统确认可打开的链接', async () => {
  const page = await source('pages/profile/QQGroupPage.ets');
  assert.match(page, /const openable: string\[\] = \[\];/, '缺少可用链接列表');
  assert.match(page, /await context\.openLink\(openable\[i\]\)/, '仍在尝试不可用的链接');
  assert.doesNotMatch(page, /await context\.openLink\(links\[i\]\)/, '不应直接遍历原始链接');
});

test('第二课堂页面本身也会把“无效查询请求”转为可读提示', async () => {
  const page = await source('pages/main/SecondClassroomPage.ets');
  assert.match(page, /第二课堂服务暂不可用，请稍后重试/, '第二课堂页面缺少可读提示');
  assert.match(page, /rawMessage\.indexOf\('无效'\)/, '没有识别后端的无效请求文案');
});

test('普通课表二维码使用紧凑格式并限制在 512 字符内', async () => {
  const page = await source('pages/course/CourseSharePage.ets');
  assert.match(page, /private staticQrPayload: string = '';/, '缺少课表二维码内容');
  assert.match(page, /QR_MAX_CHARS = 500;/, '缺少 512 字符上限保护');
  assert.match(page, /this\.staticQrPayload\.length <= CourseSharePage\.QR_MAX_CHARS/, '没有按上限校验');
  assert.match(page, /`WUSTC1\|/, '二维码内容没有使用紧凑格式');
  assert.match(page, /state\.qrValue = this\.staticQrPayload/, '静态二维码没有使用课表内容');
  assert.match(page, /课表内容过长（二维码最多 512 字符）/, '缺少内容过长的提示');
});
test('扫码导入页面能解析紧凑格式，并兼容旧 JSON', async () => {
  const page = await source('pages/course/CourseArchivePage.ets');
  assert.match(page, /static parseCompact\(content: string\): CourseArchive \| null/, '缺少紧凑格式解析');
  assert.match(page, /parts\[0\] !== 'WUSTC1'/, '没有识别紧凑格式前缀');
  assert.match(page, /content\.startsWith\('WUSTC1\|'\)/, '扫码后没有优先解析紧凑格式');
  assert.match(page, /JSON\.parse\(content\) as CourseArchive/, '没有兼容旧的 JSON 课表档案');
});
