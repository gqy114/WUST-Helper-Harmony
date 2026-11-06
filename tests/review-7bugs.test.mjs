import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * 上架审核 7 个问题的回归测试。
 *
 * 这些问题大多是页面接线错误，单元测试无法直接渲染 ArkUI，
 * 因此这里对关键源码做结构化断言：一旦有人把修复改回去，测试会失败。
 */

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const root = '../entry/src/main';

test('培养方案：loadData 前必须编码 # 号（ArkWeb 会把 # 之后内容当成片段丢弃）', async () => {
  const code = await source(`${root}/ets/pages/campus/TrainingPlanPage.ets`);
  assert.match(code, /encodeURIComponent\(/);
  assert.match(code, /loadData\(encoded/);
  // 未编码的 documentHtml 直接传给 loadData 就是白屏的原因。
  assert.doesNotMatch(code, /loadData\(\s*this\.documentHtml/);
});

test('通用网页：只有主文档错误才算失败，子资源失败不能覆盖整页', async () => {
  const code = await source(`${root}/ets/pages/common/WebPage.ets`);
  assert.match(code, /isMainFrame\(\)/);
  assert.match(code, /mainFrame === false/);
  // 错误浮层必须覆盖在 Web 上，保证 retry 时 controller 仍有效。
  assert.match(code, /Stack\(\)/);
  assert.match(code, /this\.errorOverlay\(\)/);
  assert.match(code, /loadUrl\(/);
});

test('双创学分：首页入口必须指向真实页面，不能再用空 url 的 WebPage', async () => {
  const main = await source(`${root}/ets/pages/main/MainPage.ets`);
  const line = main.split('\n').find((item) => item.includes('title: "双创学分"'));
  assert.ok(line, '首页仍然需要双创学分入口');
  assert.match(line, /pages\/campus\/InnovationCreditPage/);
  assert.doesNotMatch(line, /url:\s*""/);

  const page = await source(`${root}/ets/pages/campus/InnovationCreditPage.ets`);
  assert.match(page, /InnovationCreditApi\.getAuthTicket/);
  assert.match(page, /sfDomain=cas12226/);
});

test('QQ 用户群：不再打开会白屏的 qm.qq.com，改为原生页展示群号', async () => {
  const mine = await source(`${root}/ets/pages/mine/MinePage.ets`);
  assert.doesNotMatch(mine, /qm\.qq\.com/);
  assert.match(mine, /pages\/profile\/QQGroupPage/);

  const page = await source(`${root}/ets/pages/profile/QQGroupPage.ets`);
  assert.match(page, /648599822/);
  assert.match(page, /pasteboard/);
});

test('小组件：真实卡片 + 设置页按钮有响应', async () => {
  const module = await source(`${root}/module.json5`);
  assert.match(module, /EntryFormAbility/);
  assert.match(module, /ohos\.extension\.form/);

  const formConfig = await source(`${root}/resources/base/profile/form_config.json`);
  assert.match(formConfig, /\.\/ets\/widget\/WidgetCard\.ets/);

  const card = await source(`${root}/ets/widget/WidgetCard.ets`);
  assert.match(card, /@LocalStorageProp\('title'\)/);
  assert.match(card, /postCardAction/);

  const settings = await source(`${root}/ets/pages/profile/WidgetSettingsPage.ets`);
  assert.match(settings, /formProvider\.openFormManager/);
  assert.match(settings, /formProvider\.updateForm/);
  assert.match(settings, /refreshWidgets\(true\)/);
  assert.match(settings, /addCountdown/);
  // 旧实现在工具栏图标上没有 onClick，审核点“设置/刷新/添加”才会完全没有响应。
  assert.doesNotMatch(settings, /private toolbarIcon\(label: string\) \{\s*Text\(label\)/);
});

test('课表：并发刷新共享同一任务，并支持研究生课表接口', async () => {
  const session = await source(`${root}/ets/service/TeachingSessionService.ts`);
  assert.match(session, /inFlight/);
  // 旧实现刷新进行中直接 return false，调用方会误以为会话不可用并停在错误页。
  assert.doesNotMatch(session, /if \(TeachingSessionService\.refreshing\) return false;/);

  const api = await source(`${root}/ets/net/CourseApi.ets`);
  assert.match(api, /\/Graduate\/Support\/getCoursesPage/);
  assert.match(api, /getGraduateCourseTable/);

  const page = await source(`${root}/ets/pages/course/CoursePage.ets`);
  assert.match(page, /getGraduateCourseTable/);
  // 401 重试失败后必须继续后台恢复，而不是永久停留在错误页（研究生除外：
  // 研究生的 401 只能靠统一身份认证密码解决，刷新本科 Token 没有意义）。
  const unauthorized = page.split('\n').find((item) => item.includes('responseCode === 401'));
  assert.ok(unauthorized, '需要保留 401 分支');
  assert.match(page, /if \(!isGraduate\) \{/);
  assert.match(page, /this\.scheduleSessionRestore\(\);/);
});

test('接口与页面注册：新页面要写进 main_pages', async () => {
  const pages = await source(`${root}/resources/base/profile/main_pages.json`);
  assert.match(pages, /pages\/profile\/QQGroupPage/);
  assert.match(pages, /pages\/campus\/InnovationCreditPage/);
});
