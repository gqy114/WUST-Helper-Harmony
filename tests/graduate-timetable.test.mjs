// 研究生课表回归测试：
// 1) 研究生登录必须先走 Go 后端（与课表同一套凭据校验），旧 8009 只做回退；
// 2) 旧 8009 失败时外层 code 仍是 200，必须按 payload.status/login_error 判定失败；
// 3) 登录成功后必须把学号密码写进 AppStorage，否则课表接口拿不到凭据；
// 4) 切换账号要清掉上一个账号的课表存档，研究生不能看到本科生的课表。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });
const root = '../entry/src/main';

async function createApiService(handler) {
  const calls = [];
  const context = createContext({ console });
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', {
      postJson: async (url, body) => {
        calls.push({ url, body });
        return { response: { responseCode: 200 }, data: handler(url, body) };
      },
    });
  });
  const storage = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => ({ getUseMock: async () => false }) });
  });
  const model = new SyntheticModule(
    ['BaseResponse', 'TokenDataContent', 'GraduateLoginDataContent', 'AppAuthDataContent'],
    function () {
      // 这些只有类型意义，运行时不需要实现。
      for (const name of ['BaseResponse', 'TokenDataContent', 'GraduateLoginDataContent', 'AppAuthDataContent']) {
        this.setExport(name, undefined);
      }
    });
  const api = new SourceTextModule(transform(await source(`${root}/ets/net/ApiService.ts`)));
  await api.link((name) => {
    if (name === './HttpRequest') return http;
    if (name === '../store/AppStorage') return storage;
    if (name === '../model/BaseResponse') return model;
    throw new Error(`Unexpected import: ${name}`);
  });
  await api.evaluate();
  return { calls, api: api.namespace.ApiService, context };
}

test('研究生登录首选 Go 后端，凭据口径与课表接口一致', async () => {
  const { calls, api } = await createApiService(() => ({
    code: 200,
    msg: 'ok',
    data: { studentNumber: '20240001', name: '李四', college: '计算机学院', major: '软件工程' },
  }));
  const resp = await api.loginGraduate('20240001', 'pwd');
  assert.match(calls[0].url, /\/Graduate\/Support\/loginPage/);
  assert.deepEqual(calls[0].body, { student_id: '20240001', password: 'pwd' });
  assert.equal(resp.code, 200);
  assert.equal(resp.data.name, '李四');
  assert.equal(resp.data.studentNumber, '20240001');
});

test('旧 8009 服务在外层 code=200 时也可能登录失败，必须识别 status/login_error', async () => {
  const { api } = await createApiService((url) => {
    if (url.includes('/Graduate/Support/loginPage')) {
      return { code: 500, message: '学校网关统一认证：invalid password', data: null };
    }
    return {
      code: 200,
      message: '验证码识别失败，请重试',
      data: {
        status: 'failure',
        data: null,
        login_error: '请求异常：获取验证码失败',
        message: '登录失败',
      },
    };
  });
  const resp = await api.loginGraduate('20240001', 'wrong-password');
  assert.notEqual(resp.code, 200);
  assert.match(String(resp.msg), /invalid password/);
  assert.equal(resp.data, undefined);
});

test('旧 8009 登录成功时取包装层里的 data 字段', async () => {
  const { api } = await createApiService((url) => {
    if (url.includes('/Graduate/Support/loginPage')) {
      return { code: 500, message: '学校网关统一认证：invalid password', data: null };
    }
    return {
      code: 200,
      data: { status: 'success', data: { studentNumber: '20240001', name: '李四' }, login_error: '' },
    };
  });
  const resp = await api.loginGraduate('20240001', 'pwd');
  assert.equal(resp.code, 200);
  assert.equal(resp.data.name, '李四');
});

test('研究生登录成功后必须落盘学号密码（课表接口依赖它现登录）', async () => {
  const login = await source(`${root}/ets/pages/login/LoginPage.ets`);
  assert.match(login, /await this\.saveLoginData\(`grad_\$\{sid\}`, resp\.msg/);
  // 旧实现只把 token 写进 StorageUtil，AppStorage 里没有密码，课表请求必然失败。
  assert.doesNotMatch(login, /StorageUtil\.saveLoginInfo\('grad_'/);
  const save = login.slice(login.indexOf('private async saveLoginData'));
  assert.match(save, /setPassword\(pwd\)/);
  assert.match(save, /setStudentId\(sid\)/);
});

test('切换账号必须清掉上一个账号的课表存档', async () => {
  const login = await source(`${root}/ets/pages/login/LoginPage.ets`);
  assert.match(login, /prevSid !== sid/);
  assert.match(login, /setCurrentCourses\(\[\]\)/);
  assert.match(login, /setPhysicalExperimentCourses\(\[\]\)/);
});

test('研究生课表 401 不再刷新本科教务 Token，而是展示后端原因', async () => {
  const course = await source(`${root}/ets/pages/course/CoursePage.ets`);
  assert.match(course, /!retried && !isGraduate && await TeachingSessionService\.ensureSession\(true\)/);
  assert.match(course, /this\.errorMsg = responseMsg \|\| \(isGraduate/);
  assert.doesNotMatch(course, /!retried && await TeachingSessionService\.ensureSession\(true\)/);
});
