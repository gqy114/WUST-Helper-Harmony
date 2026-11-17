// 倒计时桌面卡片：4×2 宽卡、图标、背景裁剪、主题、不透明度、考试轮换。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('卡片使用系统支持的 2*4 宽卡（视觉上的 4×2）', async () => {
  const config = await source('entry/src/main/resources/base/profile/form_config.json');
  assert.match(config, /"defaultDimension": "2\*4"/, '默认尺寸应为宽卡 2*4');
  assert.match(config, /"supportDimensions": \[\s*"2\*2",\s*"2\*4",\s*"4\*4"/, '2*4 宽卡不在支持列表');
  assert.doesNotMatch(config, /"4\*2"/, 'config 不支持 4*2 写法');
});

test('预览使用 setting.svg 和 add.svg 图标', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /\$r\('app\.media\.setting'\)/, '缺少 setting.svg');
  assert.match(page, /\$r\('app\.media\.add'\)/, '缺少 add.svg');
  assert.doesNotMatch(page, /toolbarIcon\('⚙'/, '不应再用字符齿轮');
  assert.doesNotMatch(page, /toolbarIcon\('\+'/, '不应再用字符加号');
});

test('自定义背景：选图后按 2:1 裁剪并保存到沙箱', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /photoAccessHelper\.PhotoViewPicker/, '没有调用系统选图器');
  assert.match(page, /const CROP_WIDTH = 300;/, '缺少裁剪宽度');
  assert.match(page, /const CROP_HEIGHT = 150;/, '裁剪比例不是 2:1');
  assert.match(page, /getComponentSnapshot\(\)\.get\('widgetCropBox'\)/, '没有截取裁剪框');
  assert.match(page, /widget_bg\.jpg/, '没有保存背景文件');
  assert.match(page, /WidgetPrefs\.setBackground\(/, '背景没有持久化');
});

test('不透明度默认 70%，只作用于背景图', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /DEFAULT_BACKGROUND_OPACITY: number = 0\.7/, '默认不透明度不是 70%');
  assert.match(data, /getBackgroundOpacity/, '缺少不透明度偏好');
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  const preview = page.slice(page.indexOf('private previewCard()'), page.indexOf('build()'));
  assert.match(preview, /Image\(this\.backgroundSource\(\)\)[\s\S]*?\.opacity\(this\.backgroundOpacity\)/,
    '背景图没有使用不透明度');
  assert.doesNotMatch(preview, /Text\([\s\S]*?\)\.opacity\(/, '不透明度不能作用到文字');
  assert.match(page, /Text\(`\$\{Math\.round\(this\.backgroundOpacity \* 100\)\}%`\)/, '缺少百分比显示');
});

test('主题使用滚轮选择器，支持跟随系统/简洁白/主题黑', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /TextPickerDialog\.show\(/, '主题没有使用滚轮选择器');
  assert.match(page, /const THEME_LABELS: string\[\] = \['跟随系统', '简洁白', '主题黑'\]/, '主题选项不符');
  assert.match(page, /ConfigurationConstant\.ColorMode\.COLOR_MODE_DARK/, '跟随系统没有读取深色模式');
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /theme === WIDGET_THEME_DARK \|\| \(theme === WIDGET_THEME_SYSTEM && systemDark\)/,
    '主题没有解析深浅色');
  assert.match(data, /'#1C1C1E', '#FFFFFF'/, '缺少深色配色');
});

test('倒计时卡片展示考试倒计时，多场按小时轮换', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /getExamCountdowns/, '没有读取考试倒计时');
  assert.match(data, /Math\.floor\(Date\.now\(\) \/ \(60 \* 60 \* 1000\)\) % total/, '没有按小时轮换');
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /CountdownApi\.listExams\(term\)/, '没有同步考试安排');
  assert.match(page, /detailParts\.push\(exam\.location\)/, '考试地点没有进入详情');
  const card = await source('entry/src/main/ets/widget/WidgetCard.ets');
  assert.match(card, /@LocalStorageProp\('days'\)/, '卡片缺少天数');
  assert.match(card, /@LocalStorageProp\('bgOpacity'\)/, '卡片缺少背景不透明度');
  assert.match(card, /\.opacity\(this\.bgOpacity\)/, '卡片背景没有应用不透明度');
});
