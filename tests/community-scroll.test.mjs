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

// ---------------------------------------------------------------------------
// 返回列表时的行为：不重新加载、恢复滚动位置、消费删除/更新记录
// ---------------------------------------------------------------------------

async function makeListPageHarness(state) {
  const pageSource = await source(`${root}/pages/campus/CampusWallPage.ets`);
  const extract = (name) => {
    const found = pageSource.match(new RegExp(`  (?:private )?(?:async )?${name}\\(\\)[^{]*\\{[\\s\\S]*?\\r?\\n  \\}`));
    assert.ok(found, `${name} 方法未找到`);
    return found[0];
  };
  const calls = { load: 0, patched: [], scrolled: [], key: null };
  const store = {
    consumeDeletedCampusPostIds: () => state.deleted || [],
    consumeUpdatedCampusPostIds: () => state.updated || [],
    consumeListReturnOffset: (key) => { calls.key = key; return state.offset; },
  };
  const timers = [];
  const served = state.served || [{ id: 1, title: 'a' }, { id: 2, title: 'b' }];
  const context = createContext({
    console,
    Array,
    JSON,
    CommunityNavigationStore: { getInstance: () => store },
    CampusWallApi: { list: async () => { calls.load += 1; return served; } },
    promptAction: { showToast: () => {} },
    setTimeout: (callback) => { timers.push(callback); },
  });
  // 连真实的 load() 一起抽出来：页面重建时 onPageShow 依赖 load 结束时恢复位置。
  const mod = new SourceTextModule(
    stripTypeScriptTypes(`export class TestPage {\n${extract('onPageShow')}\n${extract('restoreListOffset')}\n${extract('load')}\n}`, { mode: 'transform' }),
    { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  page.posts = (state.posts || []).slice();
  page.pageKey = 'campus-wall';
  page.pendingRestoreOffset = -1;
  page.requestGeneration = 0;
  page.loading = false;
  page.loadingMore = false;
  page.currentPage = 1;
  page.hasMore = true;
  page.pageSize = 20;
  page.patchUpdatedPosts = async (ids) => { calls.patched.push(ids); };
  page.listScroller = { scrollTo: (options) => { calls.scrolled.push(options.yOffset); } };
  return {
    page, calls,
    runTimers: () => { while (timers.length > 0) { const callback = timers.shift(); callback(); } },
  };
}

test('从详情返回：不重新加载、过滤删除项、补拉更新项，并按保存的偏移恢复滚动', async () => {
  const harness = await makeListPageHarness({
    offset: 640, deleted: [1], updated: [9],
    posts: [{ id: 1, title: 'a' }, { id: 2, title: 'b' }],
  });
  harness.page.onPageShow();

  assert.equal(harness.calls.load, 0, '返回时不应重新加载列表');
  assert.equal(harness.calls.key, 'campus-wall', '应按页面 key 读取偏移');
  assert.deepEqual(Array.from(harness.page.posts, (post) => post.id), [2], '删除的条目应被移除');
  assert.deepEqual(harness.calls.patched, [[9]], '更新过的帖子应补拉');
  harness.runTimers();
  assert.deepEqual(harness.calls.scrolled, [640], '应滚动回保存的位置');
});

test('首次进入（没有返回状态）时正常加载，且不触发滚动恢复', async () => {
  const harness = await makeListPageHarness({ offset: -1, posts: [] });
  harness.page.onPageShow();
  await new Promise((resolve) => setTimeout(resolve, 1));
  assert.equal(harness.calls.load, 1, '首次进入应加载');
  harness.runTimers();
  assert.deepEqual(harness.calls.scrolled, [], '没有保存位置时不应滚动');
});

test('页面被重建（列表为空）时先加载，加载完仍恢复到保存的位置', async () => {
  const harness = await makeListPageHarness({ offset: 300, posts: [] });
  harness.page.onPageShow();
  await new Promise((resolve) => setTimeout(resolve, 1));
  assert.equal(harness.calls.load, 1, '重建后需要重新加载数据');
  harness.runTimers();
  assert.deepEqual(harness.calls.scrolled, [300], '加载完成后应恢复滚动位置');
});

// ---------------------------------------------------------------------------
// 删除回复后的列表同步
// ---------------------------------------------------------------------------

async function makeDeleteHarness(actionTarget) {
  const pageSource = await source(`${root}/pages/campus/CampusPostDetailPage.ets`);
  const found = pageSource.match(/  private async confirmDelete\(\): Promise<void> \{[\s\S]*?\r?\n  \}/);
  assert.ok(found, 'confirmDelete 方法未找到');
  const events = [];
  const toasts = [];
  const context = createContext({
    console,
    CampusWallApi: { deletePost: async () => {}, deleteReply: async () => {} },
    CommunityNavigationStore: {
      getInstance: () => ({
        markCampusPostDeleted: (id) => { events.push(['deleted', id]); },
        markCampusPostUpdated: (id) => { events.push(['updated', id]); },
      }),
    },
    promptAction: { showToast: ({ message }) => toasts.push(message) },
    router: { back: () => { events.push(['back']); } },
  });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestPage {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  page.deleting = false;
  page.deleteDialogOpen = true;
  page.actionTarget = actionTarget;
  page.postId = 605;
  page.actionReplyId = 624;
  page.load = async () => {};
  return { page, events, toasts };
}

test('删除回复后标记帖子已更新（返回列表会补拉这条）', async () => {
  const { page, events } = await makeDeleteHarness('reply');
  await page.confirmDelete();
  assert.deepEqual(events, [['updated', 605]], '删除回复应标记帖子更新，而不是删除帖子');
  assert.equal(page.deleteDialogOpen, false);
});

test('删除帖子才是标记删除并返回上一页', async () => {
  const { page, events } = await makeDeleteHarness('post');
  await page.confirmDelete();
  assert.deepEqual(events, [['deleted', 605], ['back']], '删除帖子应标记删除并返回');
});
