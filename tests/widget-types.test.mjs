// 小组件系统：倒计时 / 周课表 / 日课表 / 快捷功能 四种卡片。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const src = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('系统只提供截图中保留的五种卡片规格', async () => {
  const { forms } = JSON.parse(await src('entry/src/main/resources/base/profile/form_config.json'));
  assert.deepEqual(forms.map(({ name, defaultDimension, supportDimensions }) =>
    ({ name, defaultDimension, supportDimensions })), [
    { name: 'wust_widget', defaultDimension: '2*4', supportDimensions: ['2*2', '2*4'] },
    { name: 'wust_weekly', defaultDimension: '4*4', supportDimensions: ['4*4'] },
    { name: 'wust_daily', defaultDimension: '2*4', supportDimensions: ['2*4'] },
    { name: 'wust_quick', defaultDimension: '2*4', supportDimensions: ['2*4'] },
  ]);
});

test('EntryFormAbility 按 form 名称映射四种模式', async () => {
  const ability = await src('entry/src/main/ets/entryformability/EntryFormAbility.ets');
  assert.match(ability, /formName\.indexOf\('daily'\) >= 0/, '没有识别日课表');
  assert.match(ability, /formName\.indexOf\('quick'\) >= 0/, '没有识别快捷功能');
  assert.match(ability, /initialMode = 'daily'/, '没有设置日课表模式');
  assert.match(ability, /initialMode = 'quick'/, '没有设置快捷功能模式');
});

test('设置页的四个按钮打开对应的系统卡片和默认尺寸', async () => {
  const page = await src('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  const { forms } = JSON.parse(await src('entry/src/main/resources/base/profile/form_config.json'));
  const buttons = new Map([
    ['添加倒计时卡片', 'wust_widget'],
    ['添加周课表卡片', 'wust_weekly'],
    ['添加日课表卡片', 'wust_daily'],
    ['添加快捷功能卡片', 'wust_quick'],
  ]);
  for (const [label, name] of buttons) {
    const form = forms.find((entry) => entry.name === name);
    assert.ok(form, `缺少卡片配置 ${name}`);
    const click = page.split(`Button('${label}')`)[1]?.split("Button('")[0];
    const dimension = form.defaultDimension.replace('*', '_');
    assert.ok(click?.includes(`this.openAddWidget('${name}', formInfo.FormDimension.Dimension_${dimension})`));
  }
  assert.match(page, /'ohos\.extra\.param\.key\.form_name': formName/);
  assert.match(page, /'ohos\.extra\.param\.key\.form_dimension': dimension/);
  assert.match(page, /'ohos\.extra\.param\.key\.module_name': 'entry'/);
});

test('快捷功能卡片渲染入口并支持点击跳转', async () => {
  const card = await src('entry/src/main/ets/widget/WidgetCard.ets');
  assert.match(card, /Quick機能|快捷功能/, '缺少快捷功能标题');
  assert.match(card, /private quickContent\(\)/, '缺少快捷功能布局');
  assert.match(card, /this\.mode === 'quick'/, '没有按模式渲染快捷功能');
  for (const route of ['pages/main/ElectricityPage', 'pages/campus/grade/GradePage',
    'pages/campus/CampusWallPage', 'pages/library/LibraryPage', 'pages/campus/TrainingPlanPage']) {
    assert.ok(card.includes(route), `缺少入口 ${route}`);
  }
  assert.match(card, /params: \{ widgetRoute: route \}/, '点击没有携带跳转路由');
});

test('快捷功能数据包含电量，且 EntryAbility 支持直达页面', async () => {
  const data = await src('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /WIDGET_MODE_QUICK/, '缺少快捷功能模式');
  assert.match(data, /getElectricityRoomsCache/, '没有读取电量缓存');
  assert.match(data, /quickSnapshot/, '缺少快捷功能快照');
  const ability = await src('entry/src/main/ets/entryability/EntryAbility.ets');
  assert.match(ability, /widgetRoute/, 'EntryAbility 没有接收跳转路由');
  assert.match(ability, /route\.startsWith\('pages\/'\)/, '没有校验跳转路由');
});

test('刷新桌面卡片时按每张卡自己的类型生成数据', async () => {
  const page = await src('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /widgetFormMode_\$\{infos\[i\]\.formId\}/, '刷新时没有读取卡片自己的模式');
  assert.match(page, /WidgetData\.build\(storage, this\.systemDark\(\), mode\)/, '没有按卡片模式重新生成数据');
});

test('App 在后台时点卡片快捷入口能跳到对应页面，失败立即重试', async () => {
  const ability = await src('entry/src/main/ets/entryability/EntryAbility.ets');
  assert.match(ability, /onNewWant\(want: Want/, '缺少 onNewWant 处理');
  assert.match(ability, /private pushWidgetRoute\(route: string, attempt: number, requestId: number, startPage: string\): void/, '缺少跳转重试方法');
  assert.match(ability, /attempt < 3/, '失败后没有重试');
  assert.match(ability, /this\.pushWidgetRoute\(route, attempt \+ 1, requestId, startPage\), 400/, '重试没有延时再次执行');
  const main = await src('entry/src/main/ets/pages/main/MainPage.ets');
  assert.doesNotMatch(main, /consumeWidgetRoute|WidgetRouteBridge/, '不应再把跳转留到首页显示后执行');
});

test('新的快捷入口请求会作废旧重试，回前台后旧重试也会取消', async () => {
  const ability = await src('entry/src/main/ets/entryability/EntryAbility.ets');
  assert.match(ability, /routeRequestId/, '缺少请求代次');
  assert.match(ability, /this\.routeRequestId\+\+/, '新请求没有推进代次');
  assert.match(ability, /if \(requestId !== this\.routeRequestId\) \{[\s\S]*?return;/, '旧请求重试没有作废');
  assert.match(ability, /current !== startPage/, '用户切到别的页面后旧重试没有作废');
  assert.match(ability, /failed after retries/, '重试耗尽后没有明确放弃');
  assert.doesNotMatch(ability, /WidgetRouteBridge/, '不应再使用延迟兜底桥');
});

test('快捷入口兼容 want.parameters.params 嵌套参数，旧卡片内部名称不变', async () => {
  const ability = await src('entry/src/main/ets/entryability/EntryAbility.ets');
  assert.match(ability, /parameters\['params'\]/, '没有读取 nested params');
  assert.match(ability, /widgetRouteFromWant\(want\)/, '没有统一的参数解析方法');
  const config = await src('entry/src/main/resources/base/profile/form_config.json');
  assert.match(config, /"name": "wust_widget"/, '旧卡片内部名称 wust_widget 被改名，会导致升级后旧卡片消失');
});

test('桌面卡片直达设置后返回走应用启动页，有上一页时仍正常返回', async () => {
  const page = await src('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /if \(Number\(router\.getLength\(\)\) > 1\) \{\s*router\.back\(\)/);
  assert.match(page, /router\.replaceUrl\(\{ url: 'pages\/splash\/LaunchPage' \}\)/);
  assert.match(page, /onBackPress\(\): boolean \{\s*if \(Number\(router\.getLength\(\)\) > 1\) return false;\s*this\.leaveSettings\(\);\s*return true;/);
  assert.match(page, /accessibilityText\('返回'\)\.onClick\(\(\) => this\.leaveSettings\(\)\)/);
});
