import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('同一学号重新保存登录态不清空电表，也不跳过余额查询', async () => {
  const page = await source('pages/main/ElectricityPage.ets');
  const start = page.indexOf('private async isRoomSessionCurrent()');
  const block = page.slice(start, page.indexOf('private async refreshBalances()', start));
  assert.doesNotMatch(block, /getSessionEpoch\(\) === this\.roomEpoch/, '仍按 session epoch 判断，重登会清空');
  assert.match(block, /account === this\.roomAccount[\s\S]*?return true/, '同学号没有直接返回 true');
  assert.match(block, /this\.roomEpoch = storage\.getSessionEpoch\(\)/, '没有同步新的 session epoch');
});
