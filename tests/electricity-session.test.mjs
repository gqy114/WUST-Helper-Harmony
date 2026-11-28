import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('同一学号重新保存登录态不清空电表，也不跳过余额查询', async () => {
  const page = await source('pages/main/ElectricityPage.ets');
  const start = page.indexOf('private async isRoomSessionCurrent()');
  const block = page.slice(start, page.indexOf('private async refreshBalances()', start));
  assert.doesNotMatch(block, /getSessionEpoch\(\) === this\.roomEpoch/, '仍按 session epoch 判断，重登会清空');
  assert.match(block, /account === this\.roomAccount[\s\S]*?return true/, '同学号没有直接返回 true');
  assert.match(block, /this\.roomEpoch = storage\.getSessionEpoch\(\)/, '没有同步新的 session epoch');
});

test('云端无电表且缓存读取期间同账号重登时，页面重读本地电表', async () => {
  const code = await source('pages/main/ElectricityPage.ets');
  const load = code.slice(code.indexOf('  private async loadSavedRooms()'), code.indexOf('  private async localSavedRooms()'));
  let epoch = 1;
  let reads = 0;
  const writes = [];
  const storage = { getSessionEpoch: () => epoch, getStudentId: async () => 'A' };
  const context = createContext({
    console,
    AppStorage: { getInstance: () => storage },
    ElectricityApi: {
      savedRooms: async () => [],
      electricity: async () => ({ remaining: '11', unit: '度' }),
    },
  });
  const pageMod = new SourceTextModule(stripTypeScriptTypes('export class Page { ' + load + ' }', { mode: 'transform' }), { context });
  await pageMod.link(() => {});
  await pageMod.evaluate();
  const page = new pageMod.namespace.Page();
  page.isRoomSessionCurrent = async () => { page.roomEpoch = epoch; return true; };
  page.localSavedRooms = async () => {
    if (++reads === 1) { epoch++; return []; }
    return [{ id: 'local-room', name: '本地电表' }];
  };
  page.saveLocalRooms = async version => writes.push([version, Array.from(page.savedRooms, room => room.id)]);
  await page.loadSavedRooms();
  assert.equal(reads, 2);
  assert.deepEqual(writes, [[2, ['local-room']]]);
  assert.equal(page.balances[0].remaining, '11');
});
