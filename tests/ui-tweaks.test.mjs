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

test('二手书筛选面板可滚动且有高度上限，选项和按钮都能点到', async () => {
  const page = await src('pages/campus/SecondHandBookPage.ets');
  const block = page.slice(page.indexOf('if (this.filterOpen)'), page.indexOf('if (this.searching)'));
  assert.match(block, /Scroll\(\) \{/, '筛选面板没有放进可滚动容器');
  assert.match(block, /constraintSize\(\{ maxHeight: '55%' \}\)/, '筛选面板没有高度上限');
  assert.match(block, /Text\('取消'\)/, '取消按钮缺失');
  assert.match(block, /Text\('确定'\)/, '确定按钮缺失');
});
