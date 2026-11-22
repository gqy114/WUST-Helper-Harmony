// UI 细节：图书馆栏目选中状态更明显；社区操作栏收窄一半并等比缩放。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const src = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('图书馆栏目选中项对比更明显，底部绿线更宽', async () => {
  const page = await src('pages/library/LibraryPage.ets');
  assert.match(page, /fontColor\(this\.selectedTab === index \? '#111111' : '#8C8C8C'\)/, '选中/未选中文字颜色对比不足');
  assert.match(page, /height\(this\.selectedTab === index \? 4 : 2\)/, '选中项底部绿线没有加粗');
  assert.match(page, /color\(this\.selectedTab === index \? '#20C894' : '#F0F0F0'\)/, '选中项底部绿线不醒目');
  assert.match(page, /\.width\(index === 0 \? 116 : 124\)/, '栏目宽度没有增加');
});

test('社区帖子/回复的操作栏收窄到一半宽度并缩放图标文字', async () => {
  const pages = [
    'pages/campus/CampusPostDetailPage.ets',
    'pages/campus/CampusCatDetailPage.ets',
    'pages/campus/SecondHandBookDetailPage.ets'
  ];
  for (const path of pages) {
    const page = await src(path);
    assert.match(page, /\.width\('50%'\)\.height\((190|180)\)\.padding\(\{ left: 14, right: 14, top: 14 \}\)/, `${path} 操作栏没有收窄`);
    assert.match(page, /\.width\(44\)\.height\(44\)\.padding\(10\)/, `${path} 操作图标没有等比缩小`);
    assert.match(page, /fontSize\(13\)/, `${path} 操作文字没有等比缩小`);
  }
});

test('校园社区帖子列表字号和卡片高度按安卓比例缩小', async () => {
  const pages = ['pages/campus/CampusWallPage.ets', 'pages/campus/CampusCatPage.ets',
    'pages/campus/CampusHelpPage.ets', 'pages/campus/CampusMatchPage.ets', 'pages/campus/CampusLostPage.ets'];
  for (const path of pages) {
    const page = await src(path);
    assert.match(page, /width\(42\)\.height\(42\)\.borderRadius\(21\)/, `${path} 头像没有缩小`);
    assert.match(page, /fontSize: 18, textColor: '#222222', baseBold: true, lineHeight: 26/, `${path} 标题字号没有缩小`);
    assert.match(page, /fontSize: 15, textColor: '#333333', lineHeight: 24/, `${path} 正文字号没有缩小`);
    assert.match(page, /padding\(\{ left: 20, right: 20, top: 14, bottom: 16 \}\)/, `${path} 卡片内边距没有缩小`);
  }
});

test('社区帖子昵称和学院都单行省略', async () => {
  const pages = ['pages/campus/CampusWallPage.ets', 'pages/campus/CampusCatPage.ets',
    'pages/campus/CampusHelpPage.ets', 'pages/campus/CampusMatchPage.ets', 'pages/campus/CampusLostPage.ets'];
  for (const path of pages) {
    const page = await src(path);
    assert.match(page, /fontColor\('#655C86'\)\.maxLines\(1\)\.textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\)/,
      `${path} 昵称没有单行省略`);
    // 校园猫帖子只有昵称和标签，没有学院字段。
    if (!path.includes('CampusCatPage')) {
      assert.match(page, /fontColor\('#888888'\)\.margin\(\{ top: 2 \}\)\.maxLines\(1\)\.textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\)/,
        `${path} 学院没有单行省略`);
    }
  }
});

test('失物招领地点栏超过三分之一宽度换行显示，不省略', async () => {
  const page = await src('pages/campus/CampusLostPage.ets');
  assert.match(page, /Text\(this\.addressLabel\(post\)\)[\s\S]*?\.maxLines\(3\)[\s\S]*?\.constraintSize\(\{ maxWidth: '33%' \}\)/, '地点栏没有按 1/3 宽度换行');
  assert.doesNotMatch(page, /Text\(this\.addressLabel\(post\)\)[\s\S]{0,200}?TextOverflow\.Ellipsis/, '地点栏不应省略');
});

test('社区详情页用 List 承载内容，避免内容不足一屏时被 Scroll 居中', async () => {
  const pages = ['pages/campus/CampusPostDetailPage.ets', 'pages/campus/CampusCatDetailPage.ets',
    'pages/campus/SecondHandBookDetailPage.ets'];
  for (const path of pages) {
    const page = await src(path);
    assert.match(page, /List\(\) \{[\s\S]*?ListItem\(\) \{/, `${path} 没有改用 List 顶部排列`);
    assert.doesNotMatch(page, /constraintSize\(\{ minHeight: '100%' \}\)/, `${path} 仍保留 Scroll 居中兜底`);
  }
});

test('二手书筛选面板改为独立弹层，选项可滚动且按钮固定可见', async () => {
  const page = await src('pages/campus/SecondHandBookPage.ets');
  const block = page.slice(page.indexOf('筛选面板改成覆盖'), page.indexOf('if (this.majorPickerOpen)'));
  assert.match(block, /Scroll\(\) \{/, '筛选面板没有放进可滚动容器');
  assert.match(block, /\.height\('62%'\)/, '筛选面板没有固定高度');
  assert.match(block, /\.layoutWeight\(1\)\.scrollBar\(BarState\.Auto\)/, '选项区不能独立滚动');
  assert.match(block, /Divider\(\)\.height\(0\.5\)/, '底部按钮区没有分隔');
  assert.match(block, /Text\('取消'\)/, '取消按钮缺失');
  assert.match(block, /Text\('确定'\)/, '确定按钮缺失');
  assert.match(block, /backgroundColor\('#66000000'\)/, '弹层没有遮罩');
});

test('取消指定专业会恢复原来的筛选模式', async () => {
  const page = await src('pages/campus/SecondHandBookPage.ets');
  assert.match(page, /private majorPickerOriginalMode: string/, '没有记录进入前的筛选模式');
  assert.match(page, /this\.majorPickerOriginalMode = this\.pendingMajorMode;/, '进入指定专业前没有保存模式');
  assert.match(page, /this\.pendingMajorMode = this\.majorPickerOriginalMode;/, '取消时没有恢复筛选模式');
  assert.match(page, /this\.pendingMajors = \[\];\s*this\.pendingMajor = this\.pendingMajorMode;/, '恢复非指定专业模式时没有清空专业列表');
  const saves = page.match(/this\.majorPickerOriginalMode = this\.pendingMajorMode;/g) || [];
  assert.ok(saves.length >= 2, '修改入口没有保存本次打开前的模式');
});
