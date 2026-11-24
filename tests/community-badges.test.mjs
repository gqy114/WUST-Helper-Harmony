import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../entry/src/main/ets/pages/main/MainPage.ets', import.meta.url), 'utf8');
const polling = source.match(/  private async loadCommunityBadges\(\)[\s\S]+?(?=  private setCommunityUnread)/)[0];
const mark = source.match(/  private async markCommunitySeen\([\s\S]+?(?=  private openCardItem)/)[0];
const tag = source.match(/  private communityTag\([\s\S]+?(?=  private communityBadgeCount)/)[0];
const code = stripTypeScriptTypes('class Page {\n' + polling + mark + tag + '\n}\nPage;', { mode: 'transform' });

function createPage() {
  let account = 'A';
  let epoch = 0;
  const prefs = new Map([['communityLastSeen_wall', 999]]);
  const requests = [];
  const counts = new Map();
  const storage = {
    getSessionEpoch: () => epoch,
    getStudentId: async () => account,
    getIsLogin: async () => !!account,
    getSettingNumber: async (key, fallback) => prefs.get(key) ?? fallback,
    setSettingNumber: async (key, value) => { prefs.set(key, value); },
  };
  const api = {
    async postUnreadCount(tag, since) {
      requests.push({ tag, since });
      return { count: 82, checkedAt: 1795551111000 };
    },
    async notificationUnreadCount() {
      requests.push({ tag: 'messages' });
      return { count: 6, checkedAt: 1795551111000 };
    },
  };
  const Page = runInNewContext(code, { AppStorage: { getInstance: () => storage }, CampusWallApi: api,
    console, TAG: 'test' });
  const page = Object.assign(new Page(), {
    communityBadgeTimer: 1, communityBadgeAccount: '', communityCheckedAt: new Map(),
    communitySeenRevision: new Map(), communityMessagesPolledAt: 0, communityPostsPolledAt: 0,
    communityMessageRevision: 0,
    setCommunityUnread: (key, value) => counts.set(key, value),
    communityKey: () => 'wall',
  });
  return { page, api, counts, prefs, requests, setAccount: (value) => { account = value; epoch++; } };
}

test('按账号建立已读基线，精确显示超过一页的未读数，短时间进入首页不重复请求', async () => {
  const { page, counts, prefs, requests, setAccount } = createPage();
  await page.loadCommunityBadges();
  assert.equal(counts.get('wall'), 0);
  assert.equal(prefs.get('communityBadgeSeenAt_A_wall'), 1795551111000);
  assert.equal(requests.length, 6);
  assert.ok(requests.some(item => item.tag === 'book_trade'));
  assert.ok(requests.some(item => item.tag === 'lost_found'));
  await page.loadCommunityBadges();
  assert.equal(requests.length, 6);
  page.communityPostsPolledAt = 0;
  await page.loadCommunityBadges();
  assert.equal(requests.length, 11);
  assert.equal(counts.get('wall'), 82);
  assert.equal(requests[6].since, 1795551111000);
  setAccount('B');
  await page.loadCommunityBadges();
  assert.equal(counts.get('wall'), 0);
  assert.ok(prefs.has('communityBadgeSeenAt_A_wall') && prefs.has('communityBadgeSeenAt_B_wall'));
});

test('旧账号迟到的响应不写入新账号，打开栏目时在途刷新不把红点加回来', async () => {
  const { page, api, counts, prefs, setAccount } = createPage();
  let release;
  const pending = new Promise(resolve => { release = resolve; });
  const loadNotifications = api.notificationUnreadCount;
  api.notificationUnreadCount = async () => pending;
  api.postUnreadCount = async () => pending;
  const refresh = page.loadCommunityBadges();
  await new Promise(resolve => setImmediate(resolve));
  setAccount('B');
  release({ count: 37, checkedAt: 1795551111000 });
  await refresh;
  assert.equal(prefs.size, 1);
  assert.equal(page.communityMessageUnread, 0);
  api.notificationUnreadCount = loadNotifications;

  api.postUnreadCount = async () => ({ count: 27, checkedAt: 1795551112000 });
  await page.loadCommunityBadges();
  assert.equal(counts.get('wall'), 0);
  page.communityPostsPolledAt = 0;
  const next = new Promise(resolve => { release = resolve; });
  api.postUnreadCount = async () => next;
  const second = page.loadCommunityBadges();
  await new Promise(resolve => setImmediate(resolve));
  await page.markCommunitySeen({ title: '校园墙' });
  release({ count: 27, checkedAt: 1795551113000 });
  await second;
  assert.equal(counts.get('wall'), 0);
  assert.equal(prefs.get('communityBadgeSeenAt_B_wall'), 1795551112000);
});

test('聚合接口可用时一次请求拿齐六个未读数', async () => {
  const { page, api, counts, requests, prefs } = createPage();
  api.badges = async (wall, lost, team, help, book) => {
    requests.push({ tag: 'aggregate', wall, lost, team, help, book });
    return { wall: 12, lost: 3, team: 4, help: 5, book: 6, messages: 7, checkedAt: 1795551114000 };
  };
  await page.loadCommunityBadges();
  assert.equal(requests.filter(item => item.tag === 'aggregate').length, 1);
  assert.equal(requests.filter(item => item.tag === 'messages').length, 0);
  assert.equal(counts.get('wall'), 0);
  assert.equal(page.communityMessageUnread, 7);
  assert.equal(prefs.get('communityBadgeSeenAt_A_wall'), 1795551114000);
  page.communityPostsPolledAt = 0;
  await page.loadCommunityBadges();
  assert.equal(counts.get('wall'), 12);
  assert.equal(counts.get('book'), 6);
});
