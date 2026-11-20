import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = await readFile(new URL('../entry/src/main/ets/net/VolunteerApi.ets', import.meta.url), 'utf8');
const apiCode = stripTypeScriptTypes(source, { mode: 'transform' });

async function loadPageData(records, summary = {}) {
  const response = (data) => ({ data: { code: 0, data }, response: { responseCode: 200 } });
  const http = {
    request: async (url, method) => {
      assert.ok(url.endsWith('/login/mobile'));
      assert.equal(method, 'POST');
      return response('volunteer-test-token');
    },
    get: async (url) => {
      const path = new URL(url).pathname;
      if (path.endsWith('/volunteer/public/sumTime')) return response(summary);
      if (path.endsWith('/volunteer/public/volunteerTime')) return response({ list: records, totalPage: 1 });
      if (path.endsWith('/recruit/list')) return response([]);
      assert.fail('Unexpected request: ' + path);
    },
  };
  const imports = {
    './HttpRequest': ['HttpRequest', http],
    '../store/AppStorage': [
      'AppStorage',
      { getInstance: () => ({ getAppAuthAccessToken: async () => 'app-test-token' }) },
    ],
    './ApiService': ['ApiService', {}],
  };
  const context = createContext({ console });
  const module = new SourceTextModule(apiCode, { context });
  await module.link((path) => {
    assert.ok(imports[path], 'Unexpected import: ' + path);
    const [name, value] = imports[path];
    return new SyntheticModule([name], function () { this.setExport(name, value); }, { context });
  });
  await module.evaluate();
  return module.namespace.VolunteerApi.getPageData();
}

test('工时状态优先于审核附带字段，8、2、0.5 小时均计入已认证', async () => {
  const data = await loadPageData([
    { activityName: '活动一', volunteerTime: 8, volunteerStatus: 5, auditStatus: 0 },
    { activityName: '活动二', volunteerTime: '2.0', volunteerStatus: '5', volunteerStatusName: '待审核' },
    { activityName: '活动三', volunteerTime: '0.5', status: '5', auditStatusName: '待认证' },
  ], { timePassed: '10.5', timeToBePassed: '0', activityJoined: 3 });

  assert.deepEqual(Array.from(data.logs, (log) => log.certified), [true, true, true]);
  assert.deepEqual({ ...data.summary }, { certifiedHours: 10.5, uncertifiedHours: 0, participatedCount: 3 });
});

test('明确的未认证状态不受其他字段中的通过状态影响', async () => {
  const data = await loadPageData([
    { volunteerTime: 2, volunteerStatus: 0, status: 5, volunteerStatusName: '已认证' },
    { volunteerTime: 1.5, volunteerStatus: '4', auditStatusName: '审核通过' },
    { volunteerTime: 1, status: 'uncertified', statusName: '未认证' },
    { volunteerTime: 0.5, status: 'not approved', auditStatusName: '待审核' },
  ]);

  assert.deepEqual(Array.from(data.logs, (log) => log.certified), [false, false, false, false]);
  assert.deepEqual({ ...data.summary }, { certifiedHours: 0, uncertifiedHours: 5, participatedCount: 4 });
});

test('跳过空白状态值，并兼容仅返回审核文案或无状态字段的旧明细', async () => {
  const data = await loadPageData([
    { volunteerTime: 1, volunteerStatus: ' ', status: ' 5 ', auditStatusName: '待审核' },
    { volunteerTime: 2, volunteerStatus: null, auditStatusName: '审核通过' },
    { volunteerTime: 0.5, volunteerStatusName: '', auditStatusName: '待审核' },
    { volunteerTime: 1 },
  ]);

  assert.deepEqual(Array.from(data.logs, (log) => log.certified), [true, true, false, true]);
  assert.deepEqual({ ...data.summary }, { certifiedHours: 4, uncertifiedHours: 0.5, participatedCount: 4 });
});
