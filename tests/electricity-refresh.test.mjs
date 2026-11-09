import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

async function createPage(query) {
  const source = await readFile(new URL('../entry/src/main/ets/pages/main/ElectricityPage.ets', import.meta.url), 'utf8');
  const method = source.match(/  private async refreshBalances\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
  assert.ok(method);
  const messages = [];
  const context = createContext({ ElectricityApi: { electricity: query }, promptAction: { showToast: (value) => messages.push(value.message) } });
  const module = new SourceTextModule(stripTypeScriptTypes(`export class Page {\n${method}\n}`, { mode: 'transform' }), { context });
  await module.link(() => { throw new Error('Unexpected import'); });
  await module.evaluate();
  const page = new module.namespace.Page();
  Object.assign(page, { loading: false, refreshing: false, showAdd: false,
    savedRooms: [{ id: 'room', name: '寝室' }, { id: 'ac', name: '空调' }],
    balances: [{ id: 'room', name: '寝室', type: '', remaining: '10', unit: '度' },
      { id: 'ac', name: '空调', type: '', remaining: '20', unit: '度' }] });
  return { page, messages };
}

test('刷新查询所有已保存电表并更新余额', async () => {
  const calls = [];
  const { page, messages } = await createPage(async (id) => { calls.push(id); return { remaining: id === 'room' ? '11' : '21', unit: '度' }; });
  await page.refreshBalances();
  assert.deepEqual(calls, ['room', 'ac']);
  assert.deepEqual(Array.from(page.balances, item => item.remaining), ['11', '21']);
  assert.equal(messages.at(-1), '电费已刷新');
  assert.equal(page.refreshing, false);
});

test('部分刷新失败保留旧余额并提示，允许后续重试', async () => {
  let fail = true;
  const { page, messages } = await createPage(async (id) => {
    if (id === 'ac' && fail) throw new Error('network');
    return { remaining: id === 'room' ? '11' : '21', unit: '度' };
  });
  await page.refreshBalances();
  assert.deepEqual(Array.from(page.balances, item => item.remaining), ['11', '20']);
  assert.match(messages.at(-1), /1个电表刷新失败/);
  fail = false;
  await page.refreshBalances();
  assert.deepEqual(Array.from(page.balances, item => item.remaining), ['11', '21']);
});

test('请求未完成时重复点击不会发起第二次刷新', async () => {
  let release;
  let calls = 0;
  const wait = new Promise(resolve => { release = resolve; });
  const { page } = await createPage(async () => { calls++; await wait; return { remaining: '1', unit: '度' }; });
  const first = page.refreshBalances();
  await page.refreshBalances();
  assert.equal(calls, 1);
  release();
  await first;
  assert.equal(calls, 2);
});
