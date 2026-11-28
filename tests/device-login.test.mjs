// 本科设备登录协议：WebSocket + RSA-OAEP + AES-256-GCM + 学校请求转发。
import { test } from 'node:test';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/net/${path}`, import.meta.url), 'utf8');

test('设备登录使用新后端、RSA-OAEP 和 AES-256-GCM', async () => {
  const ws = await source('UndergradDeviceLogin.ts');
  assert.match(ws, /wss:\/\/port\.happylandmc\.cc:52145\/UnderGraduate\/Support\/deviceLogin\/connect/);
  assert.match(ws, /Platform: 'harmony'/);
  assert.match(ws, /wust-device-to-server-v1/);
  assert.match(ws, /wust-server-to-device-v1/);
  assert.match(ws, /SESSION_TIMEOUT_MS: number = 180000/);
  const crypto = await source('DeviceLoginCrypto.ts');
  assert.match(crypto, /RSA2048\|PKCS1_OAEP\|SHA256\|MGF1_SHA256/);
  assert.match(crypto, /AES256\|GCM\|NoPadding/);
});

test('学校请求转发只允许指定教务域名且不跟随重定向', async () => {
  const ws = await source('UndergradDeviceLogin.ts');
  for (const host of ['auth.wust.edu.cn', 'portal.wust.edu.cn', 'bkjx.wust.edu.cn']) {
    assert.match(ws, new RegExp(host.replace(/\./g, '\\.')));
  }
  assert.match(ws, /autoRedirect: false/);
  assert.match(ws, /Accept-Encoding'\] = 'identity'/);
  assert.match(ws, /MAX_BODY_BYTES: number = 10 \* 1024 \* 1024/);
});

test('本科登录优先设备登录，失败回退旧登录；可用 Cookie 换 App 会话', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/login/LoginPage.ets', import.meta.url), 'utf8');
  assert.match(page, /UndergradDeviceLogin\.login\(sid, pwd\)/);
  assert.match(page, /ApiService\.loginUndergrad\(sid, pwd\)/, '设备登录失败时没有回退');
  assert.match(page, /saveDeviceAppAuth/, '没有保存设备登录返回的 App 会话');
  const restore = await source('ApiService.ts');
  assert.match(restore, /UndergradDeviceLogin\.complete\(studentId, cookie\)/);
  assert.match(restore, /if \(outcome\.code !== 401\) return;/);
  const launch = await readFile(new URL('../entry/src/main/ets/pages/splash/LaunchPage.ets', import.meta.url), 'utf8');
  assert.match(launch, /ApiService\.loginAppAuthFromSavedCredentials\(storage\)/);
});

async function loadApi(device, storage) {
  const context = createContext({ console });
  const code = stripTypeScriptTypes(await source('ApiService.ts'), { mode: 'transform' });
  const module = new SourceTextModule(code, { context });
  const dependencies = {
    './UndergradDeviceLogin': { UndergradDeviceLogin: device },
    '../store/AppStorage': { AppStorage: { getInstance: () => storage } },
    './HttpRequest': { HttpRequest: {} },
    '../model/BaseResponse': { BaseResponse: undefined, TokenDataContent: undefined,
      GraduateLoginDataContent: undefined, AppAuthDataContent: undefined },
  };
  await module.link(path => {
    const exports = dependencies[path];
    assert.ok(exports, path);
    return new SyntheticModule(Object.keys(exports), function () {
      for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
    }, { context });
  });
  await module.evaluate();
  return module.namespace.ApiService;
}

test('启动和业务并发恢复时共用一次 Cookie 换会话，无需保存密码', async () => {
  const events = [];
  const storage = {
    getSessionEpoch: () => 1,
    isSessionCurrent: epoch => epoch === 1,
    getStudentId: async () => 'A',
    getIsGraduate: async () => false,
    getUseMock: async () => false,
    getToken: async () => 'cookie-A',
    getPassword: async () => assert.fail('Cookie 已恢复，不应读密码'),
    setAppAuthTokensIfSession: async (...args) => { events.push(args); return true; },
  };
  const api = await loadApi({
    complete: async (...args) => {
      events.push(args);
      return { code: 200, data: { appAuth: { accessToken: 'app-A' } } };
    },
  }, storage);
  await Promise.all([api.loginAppAuthFromSavedCredentials(storage), api.loginAppAuthFromSavedCredentials(storage)]);
  assert.deepEqual(events, [['A', 'cookie-A'], [1, 'A', 'app-A', '', 0, 0]]);
});

test('Cookie 失效时走新设备登录，切号后不读取密码', async () => {
  for (const switched of [false, true]) {
    let epoch = 1;
    let logins = 0;
    const storage = {
      getSessionEpoch: () => epoch,
      isSessionCurrent: requested => requested === epoch,
      getStudentId: async () => 'A',
      getIsGraduate: async () => false,
      getUseMock: async () => false,
      getToken: async () => 'expired-cookie',
      getPassword: async () => {
        assert.equal(switched, false);
        return 'pwd-A';
      },
      setTeachingSessionIfCurrent: async (_epoch, _sid, token) => token === 'new-cookie',
      setAppAuthTokensIfSession: async (_epoch, _sid, accessToken) => accessToken === 'app-A',
    };
    const api = await loadApi({
      complete: async () => {
        if (switched) epoch++;
        return { code: 401 };
      },
      login: async (sid, password) => {
        assert.deepEqual([sid, password], ['A', 'pwd-A']);
        logins++;
        return { code: 200, data: { token: 'new-cookie', appAuth: { accessToken: 'app-A' } } };
      },
    }, storage);
    await api.loginAppAuthFromSavedCredentials(storage);
    assert.equal(logins, switched ? 0 : 1);
  }
});

async function loadDeviceLogin(socket, remote = {}, exposeRelay = false) {
  const context = createContext({ console, setTimeout, clearTimeout });
  const sourceCode = await source('UndergradDeviceLogin.ts');
  const code = stripTypeScriptTypes(sourceCode + '\nexport { relaySchoolRequest };', { mode: 'transform' });
  const module = new SourceTextModule(code, { context });
  const imports = {
    '@kit.NetworkKit': { webSocket: { createWebSocket: () => socket }, http: {} },
    '@kit.ArkTS': { url: { URL } },
    '@kit.RemoteCommunicationKit': { rcp: remote },
    '@kit.BasicServicesKit': { BusinessError: undefined },
    './DeviceLoginCrypto': {
      aesGcmDecrypt: () => assert.fail('unexpected decrypt'),
      aesGcmEncrypt: async () => new Uint8Array(16),
      base64Decode: () => new Uint8Array(16),
      base64Encode: () => 'encoded',
      bytesToString: () => assert.fail('unexpected binary frame'),
      encryptSessionKey: async () => 'encrypted-key',
      randomBytes: length => new Uint8Array(length),
      stringToBytes: value => new TextEncoder().encode(value),
    },
  };
  await module.link(path => {
    const exports = imports[path];
    assert.ok(exports, path);
    return new SyntheticModule(Object.keys(exports), function () {
      for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
    }, { context });
  });
  await module.evaluate();
  return exposeRelay ? module.namespace.relaySchoolRequest : module.namespace.UndergradDeviceLogin;
}

test('设备登录只在发送凭据前断开时允许回退', async () => {
  for (const submitted of [false, true]) {
    const callbacks = new Map();
    let sent = 0;
    const device = await loadDeviceLogin({
      on: (event, callback) => callbacks.set(event, callback),
      connect: async () => {
        if (submitted) await callbacks.get('message')(undefined, '{"kind":"key","public_key":"test"}');
        else callbacks.get('error')();
        return true;
      },
      send: async () => {
        if (++sent === 2) callbacks.get('close')();
        return true;
      },
      close: async () => true,
    });
    await assert.rejects(device.login('test-id', 'test-password'), error =>
      device.canFallback(error) === !submitted);
    assert.equal(sent, submitted ? 2 : 0);
  }
});

test('新接口超时或返回 503 时回退旧 App 登录，切号后不提交保存的密码', async () => {
  for (const outage of ['timeout', '503', 'account changed']) {
    let epoch = 1;
    let fallbackCalls = 0;
    const storage = {
      getSessionEpoch: () => epoch,
      isSessionCurrent: requested => requested === epoch,
      getStudentId: async () => 'A',
      getIsGraduate: async () => false,
      getUseMock: async () => false,
      getToken: async () => 'cookie-A',
      getPassword: async () => 'pwd-A',
      setAppAuthTokensIfSession: async (_epoch, _sid, access) => access === 'legacy-token',
    };
    const api = await loadApi({ complete: async () => {
      if (outage === '503') return { code: 503 };
      if (outage === 'account changed') epoch++;
      throw new Error('timeout');
    } }, storage);
    api.loginAppAuth = async (sid, password) => {
      assert.deepEqual([sid, password], ['A', 'pwd-A']);
      fallbackCalls++;
      return { code: 200, data: { accessToken: 'legacy-token' } };
    };
    await api.loginAppAuthFromSavedCredentials(storage);
    assert.equal(fallbackCalls, outage === 'account changed' ? 0 : 1);
  }
});

test('设备代理把 302、Location 和多个 Cookie 原样交给后端', async () => {
  const calls = [];
  const remote = {
    Request: class {},
    createSession: () => ({
      fetch: async request => {
        calls.push(request.configuration.transfer.autoRedirect);
        return { statusCode: 302, headers: { location: '/next', 'set-cookie': ['a=1', 'b=2'] } };
      },
      close() {},
    }),
  };
  const relay = await loadDeviceLogin({}, remote, true);
  const result = await relay({ id: 1, url: 'https://auth.wust.edu.cn/start', method: 'POST' });
  assert.equal(result.status_code, 302);
  assert.deepEqual(Array.from(result.headers.location), ['/next']);
  assert.deepEqual(Array.from(result.headers['set-cookie']), ['a=1', 'b=2']);
  assert.deepEqual(calls, [false]);
});
