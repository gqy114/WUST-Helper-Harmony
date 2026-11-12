import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const favorite = id => ({ kind: 'article', id, title: `test-${id}`, link: '', tag: '' });
async function makeFavorites(options = {}) {
  const state = { sid: 'A', reads: [], db: new Map([
    ['libraryFavorites_A', JSON.stringify([favorite(1)])],
    ['libraryFavorites_B', JSON.stringify([favorite(7)])],
    ['libraryFavorites_A_synced', true], ['libraryFavorites_B_synced', true],
    ['libraryFavoritesMigrationOwner', 'A']
  ]) };
  const storage = {
    getStudentId: async () => state.sid,
    getAppAuthAccessToken: async () => `fake-token-${state.sid}`,
    getSettingString: async (key, fallback) => {
      state.reads.push(key);
      const value = state.db.has(key) ? state.db.get(key) : fallback;
      if (options.onRead) await options.onRead(key, value, state);
      return value;
    },
    setSettingString: async (key, value) => {
      if (options.onWrite) await options.onWrite(key, value, state);
      state.db.set(key, value);
    },
    getSettingBool: async (key, fallback) => state.db.has(key) ? state.db.get(key) : fallback,
    setSettingBool: async (key, value) => { state.db.set(key, value); }
  };
  const context = createContext({ console, JSON, Array, Promise, Map, Set });
  const app = new SyntheticModule(['AppStorage'], function () { this.setExport('AppStorage', { getInstance: () => storage }); }, { context });
  const api = new SyntheticModule(['LibraryApi','LibraryFavoriteEntry'], function () {
    this.setExport('LibraryApi', {
      addFavorite: async () => true, removeFavorite: async () => true,
      listFavorites: async () => options.onList ? options.onList(state) : []
    });
    this.setExport('LibraryFavoriteEntry', undefined);
  }, { context });
  const source = await readFile(new URL('../entry/src/main/ets/store/LibraryFavorites.ets', import.meta.url), 'utf8');
  const module = new SourceTextModule(stripTypeScriptTypes(source, { mode: 'transform' }), { context });
  await module.link(name => name === './AppStorage' ? app : api); await module.evaluate();
  return { state, store: module.namespace.LibraryFavorites.getInstance() };
}

test('same-account list and toggle share the first load and preserve both edits', async () => {
  let signal, release;
  const blocked = new Promise(resolve => { signal = resolve; });
  const gate = new Promise(resolve => { release = resolve; });
  let first = true;
  const { state, store } = await makeFavorites({ onRead: async key => {
    if (key === 'libraryFavorites_A' && first) { first = false; signal(); await gate; }
  } });
  const reading = store.list(); await blocked;
  const saving = store.toggle(favorite(2));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(state.reads.filter(key => key === 'libraryFavorites_A').length, 1);
  release(); await reading; assert.equal(await saving, true);
  assert.equal(await store.toggle(favorite(3)), true);
  assert.deepEqual(JSON.parse(state.db.get('libraryFavorites_A')).map(item => item.id), [3, 2, 1]);
});

test('a stale account load cannot replace or reset the new account load', async () => {
  let signalA, signalB, releaseA, releaseB;
  const blockedA = new Promise(resolve => { signalA = resolve; });
  const blockedB = new Promise(resolve => { signalB = resolve; });
  const gateA = new Promise(resolve => { releaseA = resolve; });
  const gateB = new Promise(resolve => { releaseB = resolve; });
  let firstA = true, firstB = true;
  const { state, store } = await makeFavorites({ onRead: async key => {
    if (key === 'libraryFavorites_A' && firstA) { firstA = false; signalA(); await gateA; }
    if (key === 'libraryFavorites_B' && firstB) { firstB = false; signalB(); await gateB; }
  } });
  const old = store.list(); await blockedA;
  state.sid = 'B'; const current = store.list(); await blockedB;
  releaseA(); await old;
  const another = store.list(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(state.reads.filter(key => key === 'libraryFavorites_B').length, 1);
  releaseB(); await current; await another;
  assert.deepEqual(Array.from(await store.list(), item => item.id), [7]);
  assert.deepEqual(JSON.parse(state.db.get('libraryFavorites_A')).map(item => item.id), [1]);
});

test('a failed initial read can be retried', async () => {
  let first = true;
  const { store } = await makeFavorites({ onRead: async key => {
    if (key === 'libraryFavorites_A' && first) { first = false; throw new Error('temporary read failure'); }
  } });
  await assert.rejects(store.list(), /temporary read failure/);
  assert.deepEqual(Array.from(await store.list(), item => item.id), [1]);
});

test('switching accounts during a local save preserves the original pending operation', async () => {
  let signal, release;
  const blocked = new Promise(resolve => { signal = resolve; });
  const gate = new Promise(resolve => { release = resolve; });
  let armed = false;
  const { state, store } = await makeFavorites({ onWrite: async key => {
    if (armed && key === 'libraryFavorites_A') { armed = false; signal(); await gate; }
  } });
  await store.list(); armed = true;
  const saving = store.toggle(favorite(2));
  const cancelled = assert.rejects(saving, /favorite account changed/);
  await blocked;
  state.sid = 'B'; assert.deepEqual(Array.from(await store.list(), item => item.id), [7]);
  release(); await cancelled;
  const pendingA = JSON.parse(state.db.get('libraryFavorites_A_pending'));
  assert.deepEqual(pendingA.adds.map(item => item.id), [2]);
  assert.deepEqual(Array.from(await store.list(), item => item.id), [7]);
});

test('an old account queued toggle cannot run on the new account', async () => {
  let signal, release;
  const blocked = new Promise(resolve => { signal = resolve; });
  const gate = new Promise(resolve => { release = resolve; });
  const { state, store } = await makeFavorites({ onList: async () => { signal(); await gate; return []; } });
  const syncing = store.syncFromServer(); await blocked;
  const saving = store.toggle(favorite(2));
  const cancelled = assert.rejects(saving, /favorite account changed/);
  await new Promise(resolve => setImmediate(resolve));
  state.sid = 'B'; await store.list();
  release(); await syncing; await cancelled;
  assert.deepEqual(Array.from(await store.list(), item => item.id), [7]);
  assert.deepEqual(JSON.parse(state.db.get('libraryFavorites_B')).map(item => item.id), [7]);
});
