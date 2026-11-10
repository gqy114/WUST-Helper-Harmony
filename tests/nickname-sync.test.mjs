// 昵称修改：先写服务端，社区和其他设备才同步。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('修改昵称会调用服务端接口，而不是只写本地', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /UserApi\.updateAppDisplayName\(value\)/, '没有调用服务端修改昵称');
  // 本地保存排在服务端调用之后，避免服务端失败时本地先覆盖。
  const syncIndex = page.indexOf('UserApi.updateAppDisplayName(value)');
  const localIndex = page.indexOf('setUserName(value)');
  assert.ok(syncIndex > 0 && localIndex > syncIndex, '应先同步服务端再保存本地');
  assert.match(page, /已保存到本机，服务器同步失败/, '服务端失败时要明确提示未同步');
});

test('应用令牌为空时先用已保存凭据恢复', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /getAppAuthAccessToken\(\)/, '没有读取应用令牌');
  assert.match(page, /ApiService\.loginAppAuthFromSavedCredentials\(storage\)/, '缺少令牌恢复');
});

test('UserApi 提供昵称修改接口并使用登录令牌', async () => {
  const api = await source(`${root}/net/UserApi.ets`);
  assert.match(api, /static async updateAppDisplayName\(displayName: string\): Promise<boolean>/, '缺少 updateAppDisplayName');
  assert.match(api, /\/api\/v1\/profile\/display-name/, '接口路径不对');
  assert.match(api, /Authorization: `Bearer \$\{token\}`/, '缺少登录令牌');
  assert.match(api, /const body: DisplayNameBody = \{ displayName \}/, '请求体缺少 displayName');
});
