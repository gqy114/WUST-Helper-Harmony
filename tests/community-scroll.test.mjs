// 社区列表返回定位的行为与接线测试。
// 真实运行 CommunityNavigationStore（TS 源码转译到 vm），并对 6 个列表页做源码断言。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

async function loadStore() {
  const code = stripTypeScriptTypes(await source(`${root}/store/CommunityNavigationStore.ets`), { mode: 'transform' });
  const context = createContext({ console });
  const mod = new SourceTextModule(code, { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  return mod.namespace.CommunityNavigationStore.getInstance();
}

test('返回位置按页面区分保存，读取一次后清除', async () => {
  const store = await loadStore();
  store.rememberListReturn('campus-wall', 640);
  store.rememberListReturn('campus-help', 120);
  assert.equal(store.consumeListReturnOffset('campus-wall'), 640);
  assert.equal(store.consumeListReturnOffset('campus-wall'), -1, '消费后应清除，避免下次误恢复');
  assert.equal(store.consumeListReturnOffset('campus-help'), 120);
});

test('同一页面重复记录时保留最新偏移', async () => {
  const store = await loadStore();
  store.rememberListReturn('campus-wall', 100);
  store.rememberListReturn('campus-wall', 900);
  assert.equal(store.consumeListReturnOffset('campus-wall'), 900);
});

test('删除与更新记录消费后清空，不跨页面积累', async () => {
  const store = await loadStore();
  store.markCampusPostDeleted(7);
  store.markCampusPostDeleted(7);
  assert.deepEqual(Array.from(store.consumeDeletedCampusPostIds()), [7]);
  assert.deepEqual(Array.from(store.consumeDeletedCampusPostIds()), []);

  store.markCampusPostUpdated(9);
  assert.deepEqual(Array.from(store.consumeUpdatedCampusPostIds()), [9]);
  assert.deepEqual(Array.from(store.consumeUpdatedCampusPostIds()), []);

  store.markCatPostUpdated(3);
  assert.deepEqual(Array.from(store.consumeUpdatedCatPostIds()), [3]);
});

test('非法 id 不进入队列', async () => {
  const store = await loadStore();
  store.markCampusPostDeleted(0);
  store.markCampusPostUpdated(-5);
  assert.deepEqual(Array.from(store.consumeDeletedCampusPostIds()), []);
  assert.deepEqual(Array.from(store.consumeUpdatedCampusPostIds()), []);
});

test('6 个社区列表页都接入共享返回状态与下拉刷新', async () => {
  const pages = [
    { file: 'campus/CampusWallPage.ets', key: 'campus-wall' },
    { file: 'campus/CampusHelpPage.ets', key: 'campus-help' },
    { file: 'campus/CampusLostPage.ets', key: 'campus-lost' },
    { file: 'campus/CampusMatchPage.ets', key: 'campus-match' },
    { file: 'campus/CampusCatPage.ets', key: 'campus-cat' },
    { file: 'campus/SecondHandBookPage.ets', key: 'secondhand' },
  ];
  for (const page of pages) {
    const code = await source(`${root}/pages/${page.file}`);
    assert.match(code, new RegExp(`pageKey: string = '${page.key}'`), `${page.file} 缺少 pageKey`);
    assert.match(code, /rememberListReturn\(this\.pageKey, this\.listScroller\.currentOffset\(\)\.yOffset\)/,
      `${page.file} 打开详情前没有记录偏移`);
    assert.match(code, /consumeListReturnOffset\(this\.pageKey\)/, `${page.file} 返回时没有读取偏移`);
    assert.match(code, /this\.pendingRestoreOffset = returnOffset;/, `${page.file} 没有暂存待恢复偏移`);
    assert.match(code, /scrollTo\(\{ xOffset: 0, yOffset: offset, animation: false \}\)/, `${page.file} 没有恢复滚动`);
    assert.match(code, /Refresh\(\{ refreshing: this\.refreshing \}\)/, `${page.file} 没有下拉刷新容器`);
    assert.match(code, /onRefreshing\(\(\): void => \{ this\.refreshList\(\); \}\)/, `${page.file} 没有接 onRefreshing`);
    assert.match(code, /consumeDeletedCampusPostIds\(\)|consumeDeletedCatPostIds\(\)/, `${page.file} 没有消费删除记录`);
  }
});

test('详情页修改后标记帖子已更新，列表页据此补拉单条', async () => {
  const post = await source(`${root}/pages/campus/CampusPostDetailPage.ets`);
  assert.match(post, /markCampusPostUpdated\(this\.postId\)/, '帖子详情没有标记更新');
  const cat = await source(`${root}/pages/campus/CampusCatDetailPage.ets`);
  assert.match(cat, /markCatPostUpdated\(this\.postId\)/, '猫猫详情没有标记更新');

  const wall = await source(`${root}/pages/campus/CampusWallPage.ets`);
  assert.match(wall, /consumeUpdatedCampusPostIds\(\)/, '列表没有消费更新记录');
  assert.match(wall, /CampusWallApi\.detail\(id\)/, '列表没有补拉单条帖子');
  assert.match(wall, /this\.posts = this\.posts\.map\(/, '列表没有原地替换更新后的帖子');

  const catPage = await source(`${root}/pages/campus/CampusCatPage.ets`);
  assert.match(catPage, /CampusCatApi\.detail\(id\)/, '猫猫列表没有补拉单条帖子');
});

test('删除仍然只移除对应条目，不整表刷新', async () => {
  const wall = await source(`${root}/pages/campus/CampusWallPage.ets`);
  assert.match(wall, /this\.posts = this\.posts\.filter\(/, '删除后应只过滤对应 id');
  assert.doesNotMatch(wall, /onPageShow\(\): void \{\s*\n\s*this\.load\(\);\s*\n\s*\}/, '返回时不应无条件 load()');
});

test('删除回复后也标记帖子已更新，返回列表不会停留在旧状态', async () => {
  const post = await source(`${root}/pages/campus/CampusPostDetailPage.ets`);
  const deleteReply = post.match(/await CampusWallApi\.deleteReply\(this\.postId, this\.actionReplyId\);[\s\S]{0,260}/);
  assert.ok(deleteReply, '没有找到删除回复的调用');
  assert.match(deleteReply[0], /markCampusPostUpdated\(this\.postId\)/, '删除回复后没有标记帖子已更新');
});

async function makePatcher() {
  const pageSource = await source(`${root}/pages/campus/CampusWallPage.ets`);
  const found = pageSource.match(/  private async patchUpdatedPosts\(ids: number\[\]\): Promise<void> \{[\s\S]*?\r?\n  \}/);
  assert.ok(found, 'patchUpdatedPosts 方法未找到');
  const detailResults = {};
  const context = createContext({
    console,
    Array,
    CampusWallApi: { detail: async (id) => detailResults[id] },
  });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestPage {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  page.posts = [
    { id: 1, title: '旧标题', content: '旧内容', replyCount: 1 },
    { id: 2, title: '另一条', content: '内容', replyCount: 0 },
  ];
  return { page, detailResults };
}

test('补拉失败返回空帖子时，保留列表里的旧数据而不是变成空白条目', async () => {
  const { page, detailResults } = await makePatcher();
  detailResults[1] = {};                                   // 登录失效：detail() 返回空对象
  detailResults[2] = { id: 2, title: '另一条(已更新)', content: '内容' };
  await page.patchUpdatedPosts([1, 2]);

  assert.equal(page.posts[0].title, '旧标题', '空数据不应覆盖旧帖子');
  assert.equal(page.posts[0].content, '旧内容');
  assert.equal(page.posts[1].title, '另一条(已更新)', '有效的补拉结果应被采用');
});

test('补拉返回不同 id 的帖子时也不要替换', async () => {
  const { page, detailResults } = await makePatcher();
  detailResults[1] = { id: 99, title: '别人的帖子', content: 'x' };
  await page.patchUpdatedPosts([1]);
  assert.equal(page.posts[0].title, '旧标题');
});
