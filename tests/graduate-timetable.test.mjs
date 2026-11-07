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

test('主服务不可用（非密码错误）时回退旧 8009 并取包装层里的 data', async () => {
  const { api } = await createApiService((url) => {
    if (url.includes('/Graduate/Support/loginPage')) {
      // 传输/服务级失败，不是凭据被拒绝，允许回退。
      return { code: 503, message: 'service unavailable', data: null };
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
  assert.match(login, /resetCourseCache\(\)/);
  // setCurrentCourses([]) 会把旧 currentCourses 里的实验课迁移回来，切号必须用专用清空。
  assert.doesNotMatch(login, /setCurrentCourses\(\[\]\)/);
  // 磁盘删了但内存 CourseStore 还在，断网时仍会显示上一个账号的课表。
  assert.match(login, /CourseStore\.getInstance\(\)\.setCourses\(\[\]\)/);
});

test('主服务明确拒绝凭据后不再请求旧服务（避免加速锁定）', async () => {
  const { calls, api } = await createApiService(() => ({
    code: 500,
    message: '学校网关统一认证：invalid password',
    data: null,
  }));
  const resp = await api.loginGraduate('20240001', 'wrong-password');
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /\/Graduate\/Support\/loginPage/);
  assert.notEqual(resp.code, 200);
});

test('code=200 但没有用户信息时按失败处理', async () => {
  const { api } = await createApiService(() => ({ code: 200, message: 'Success', data: null }));
  const resp = await api.loginGraduate('20240001', 'pwd');
  assert.notEqual(resp.code, 200);
});

test('旧服务明确拒绝凭据时也不再尝试下一个旧服务', async () => {
  const { calls, api } = await createApiService((url) => {
    if (url.includes('/Graduate/Support/loginPage')) {
      return { code: 503, message: 'service unavailable', data: null };
    }
    // 第一个旧服务明确返回密码错误
    return { code: 200, data: { status: 'failure', login_error: '密码错误', message: '登录失败' } };
  });
  const resp = await api.loginGraduate('20240001', 'wrong-password');
  assert.equal(calls.length, 2, '主服务 + 第一个旧服务后应停止');
  assert.notEqual(resp.code, 200);
});

test('含学号密码的课表请求只允许 HTTPS', async () => {
  const course = await source(`${root}/ets/net/CourseApi.ets`);
  // 不允许把研究生课表回退到 http 备用节点。
  assert.doesNotMatch(course, /http:\/\/port\.happylandmc\.cc/);
  assert.match(course, /postJson<CourseApiEnvelope>\(urls\[i\], body, headers, 45000, true\)/);
  const http = await source(`${root}/ets/net/HttpRequest.ts`);
  assert.match(http, /secure: boolean = false/);
  assert.match(http, /startsWith\('https:\/\/'\)/);
  // 未识别域名的 http:// 地址也要被 secure 拒绝，不能再原样返回。
  assert.doesNotMatch(http, /if \(!matched\) return \[\{ url, index: -1 \}\];/);
});

test('课表档案与所选档案按账号隔离，切换账号不会载入别人的档案', async () => {
  const storage = await source(`${root}/ets/store/AppStorage.ts`);
  assert.match(storage, /private async archiveKey\(base: string\): Promise<string>/);
  assert.match(storage, /archiveKey\('courseArchives'\)/);
  assert.match(storage, /archiveKey\('currentArchiveId'\)/);
  // 旧版本只有全局 key，升级时迁移到当前账号，而不是继续共享。
  assert.match(storage, /const legacy = await this\.getStr\('courseArchives', ''\);/);
});

test('研究生课表 401 不再刷新本科教务 Token，而是展示后端原因', async () => {
  const course = await source(`${root}/ets/pages/course/CoursePage.ets`);
  assert.match(course, /!retried && !isGraduate && await TeachingSessionService\.ensureSession\(true\)/);
  assert.match(course, /this\.errorMsg = responseMsg \|\| \(isGraduate/);
  assert.doesNotMatch(course, /!retried && await TeachingSessionService\.ensureSession\(true\)/);
});
