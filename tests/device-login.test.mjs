// 本科设备登录协议：WebSocket + RSA-OAEP + AES-256-GCM + 学校请求转发。
import { test } from 'node:test';
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
  assert.match(ws, /maxRedirects: 0/);
  assert.match(ws, /Accept-Encoding'\] = 'identity'/);
  assert.match(ws, /MAX_BODY_BYTES: number = 10 \* 1024 \* 1024/);
});

test('本科登录优先设备登录，失败回退旧登录；可用 Cookie 换 App 会话', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/login/LoginPage.ets', import.meta.url), 'utf8');
  assert.match(page, /UndergradDeviceLogin\.login\(sid, pwd\)/);
  assert.match(page, /ApiService\.loginUndergrad\(sid, pwd\)/, '设备登录失败时没有回退');
  assert.match(page, /saveDeviceAppAuth/, '没有保存设备登录返回的 App 会话');
  const restore = await source('DeviceAuthRestore.ts');
  assert.match(restore, /UndergradDeviceLogin\.complete\(studentId, cookie\)/);
  assert.match(restore, /if \(outcome\.code !== 401\) return;/, 'complete 非 401 错误不应密码重登');
  assert.match(restore, /ApiService\.loginAppAuthFromSavedCredentials\(storage\)/);
});
