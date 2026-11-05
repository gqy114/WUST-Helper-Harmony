import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = path => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');
const transform = code => stripTypeScriptTypes(code, { mode: 'transform' });
const ok = data => ({ response: { responseCode: 200 }, data: { code: 200, data } });

async function apiHarness() {
  const mock = { calls: [], response: ok({}) };
  const http = new SyntheticModule(['HttpRequest', 'RequestResult'], function () {
    this.setExport('RequestResult', undefined);
    this.setExport('HttpRequest', {
      request: async (url, method, options) => { mock.calls.push({ url, method, options }); return mock.response; },
      postJsonPinned: async (url, body) => { mock.calls.push({ url, method: 'POST', body, pinned: true }); return mock.response; }
    });
  });
  const mod = new SourceTextModule(transform(await source('net/PasswordRecoveryApi.ets')));
  await mod.link(() => http);
  await mod.evaluate();
  return { api: mod.namespace.PasswordRecoveryApi, mock };
}

test('all stages use one pinned HTTPS backend and the correct payloads', async () => {
  const { api, mock } = await apiHarness();
  mock.response = ok({ recovery_id: 'session', image_base64: 'image' });
  await api.captcha();
  mock.response = ok({ masked_phone: '***' });
  await api.identity('session', '123', 'name', 'identity', 'image-code');
  mock.response = ok({ cooldown_seconds: 60 });
  await api.sendCode('session');
  mock.response = ok({ verified: true });
  await api.verify('session', 'sms');
  mock.response = ok({ success: true });
  await api.reset('session', 'new-password');
  assert.deepEqual(mock.calls.map(c => c.url.split('/').at(-1)), ['captcha', 'identityAuth', 'sendCode', 'verify', 'reset']);
  assert.ok(mock.calls.every(c => c.url.startsWith('https://lyzyy.love:8081/UnderGraduate/Support/passwordRecovery/')));
  assert.equal(mock.calls[0].options.pinBackend, true);
  assert.ok(mock.calls.slice(1).every(c => c.pinned));
  assert.deepEqual(mock.calls[1].body, { recovery_id: 'session', user_id: '123', user_name: 'name', id_card: 'identity', captcha_code: 'image-code' });
  assert.deepEqual(mock.calls[4].body, { recovery_id: 'session', new_password: 'new-password' });
});

test('HTTP and business failures and incomplete success responses do not advance the process', async () => {
  const { api, mock } = await apiHarness();
  for (const bad of [
    { response: { responseCode: 503 }, data: { code: 200, data: { recovery_id: 'x', image_base64: 'y' } } },
    { response: { responseCode: 200 }, data: { code: 400, message: 'error', data: {} } },
    { response: { responseCode: 200 }, data: 'html' },
    ok({ recovery_id: '', image_base64: 'y' }),
    ok({ recovery_id: 'x', image_base64: 'a'.repeat(1048577) })
  ]) { mock.response = bad; await assert.rejects(api.captcha()); }
  mock.response = ok({ verified: false });
  await assert.rejects(api.verify('session', 'sms'));
  mock.response = ok({ success: false });
  await assert.rejects(api.reset('session', 'pw'));
});

async function pageHarness(options = {}) {
  const pageSource = await source('pages/login/PasswordRecoveryPage.ets');
  const start = pageSource.indexOf('  private showError(');
  const end = pageSource.indexOf('  @Builder', start);
  assert.ok(start >= 0 && end > start);
  const methods = pageSource.slice(start, end);
  const events = [];
  const mock = {
    studentId: options.savedStudentId ?? '123', graduate: options.graduate ?? false,
    resetFails: options.resetFails ?? false, clearFails: options.clearFails ?? false,
  };
  const storage = {
    getStudentId: async () => mock.studentId, getIsGraduate: async () => mock.graduate,
    setPassword: async value => { events.push(['password', value]); if (mock.clearFails) throw Error('store'); },
    setToken: async value => events.push(['token', value]), setIsLogin: async value => events.push(['isLogin', value])
  };
  const context = createContext({ Error, Date, Math, setInterval: () => 1, clearInterval: () => {},
    PreferencesStorage: { getInstance: () => storage }, promptAction: { showToast: e => events.push(['toast', e.message]) },
    PasswordRecoveryApi: {
      captcha: async () => ({ recovery_id: 'session', image_base64: 'iVBORw0KGgo=' }),
      identity: async () => ({ account: '123', masked_phone: '138****0000' }),
      sendCode: async () => 60,
      verify: async () => {},
      reset: async (id, password) => { events.push(['reset', id, password]); if (mock.resetFails) throw Error('timeout'); }
    } });
  const mod = new SourceTextModule(transform(`export class Page {\n${methods}\n}`), { context });
  await mod.link(() => {});
  await mod.evaluate();
  const page = new mod.namespace.Page();
  Object.assign(page, { studentId: '123', newPassword: 'new-password', confirmPassword: 'new-password',
    recoveryId: 'session', busy: false, stage: 2, resultMessage: '', cooldown: 0, countdownTimer: -1 });
  return { page, events };
}

test('identity, SMS, and new password flow advances only after each successful step', async () => {
  const { page, events } = await pageHarness();
  await page.loadCaptcha();
  assert.equal(page.stage, 0);
  assert.match(page.captchaImage, /^data:image\/png;base64,/);
  page.realName = '测试';
  page.idCard = 'test-identity';
  page.captchaCode = 'abcd';
  await page.verifyIdentity();
  assert.equal(page.stage, 1);
  assert.equal(page.idCard, '');
  await page.sendSms();
  assert.equal(page.cooldown, 60);
  page.smsCode = '123456';
  await page.verifySms();
  assert.equal(page.stage, 2);
  assert.equal(page.smsCode, '');
  page.newPassword = 'new-password';
  page.confirmPassword = 'new-password';
  await page.submitPassword();
  assert.equal(page.stage, 3);
  assert.equal(events.filter(e => e[0] === 'reset').length, 1);
});

test('successful reset stops old-password relogin before submitting and clears new password from state', async () => {
  const { page, events } = await pageHarness();
  await page.submitPassword();
  assert.deepEqual(events.map(e => e[0]), ['password', 'token', 'isLogin', 'reset']);
  assert.equal(page.stage, 3);
  assert.match(page.resultMessage, /修改成功/);
  assert.equal(page.newPassword, '');
  assert.equal(page.confirmPassword, '');
  assert.equal(page.recoveryId, '');
});

test('resetting a different account never clears the current account credentials', async () => {
  const { page, events } = await pageHarness({ savedStudentId: 'other' });
  await page.submitPassword();
  assert.deepEqual(events.map(e => e[0]), ['reset']);
});

test('a failed local cleanup prevents the network reset', async () => {
  const { page, events } = await pageHarness({ clearFails: true });
  await page.submitPassword();
  assert.ok(!events.some(e => e[0] === 'reset'));
  assert.equal(page.stage, 2);
});

test('an uncertain reset is not retried or reported successful', async () => {
  const { page, events } = await pageHarness({ resetFails: true });
  await page.submitPassword();
  assert.equal(events.filter(e => e[0] === 'reset').length, 1);
  assert.equal(page.stage, 3);
  assert.match(page.resultMessage, /无法确认/);
  assert.equal(page.newPassword, '');
});

test('invalid or mismatched new passwords never reach the network or clear saved credentials', async () => {
  for (const [password, confirmation] of [['', ''], [' new ', ' new '], ['one', 'two']]) {
    const { page, events } = await pageHarness();
    page.newPassword = password;
    page.confirmPassword = confirmation;
    await page.submitPassword();
    assert.deepEqual(events.map(e => e[0]), ['toast']);
    assert.equal(page.stage, 2);
  }
});
