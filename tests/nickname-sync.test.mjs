// 昵称修改：先写服务端，社区和其他设备才同步。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('修改昵称会调用服务端接口，而不是只写本地', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /UserApi\.updateAppDisplayName\(value, token\)/, '没有调用服务端修改昵称');
  // 本地保存排在同步调用之后，避免服务端失败时本地先覆盖。
  const syncIndex = page.indexOf('const synced = await this.syncDisplayName');
  const localIndex = page.indexOf('await storage.setUserNameForAccount(session.epoch, session.sid, value)');
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
  assert.match(api, /static async updateAppDisplayName\(displayName: string, tokenSnapshot\?: string\): Promise<boolean>/, '缺少 updateAppDisplayName');
  assert.match(api, /\/api\/v1\/profile\/display-name/, '接口路径不对');
  assert.match(api, /Authorization: `Bearer \$\{token\}`/, '缺少登录令牌');
  assert.match(api, /const body: DisplayNameBody = \{ displayName \}/, '请求体缺少 displayName');
});
test('令牌恢复失败也要保存本地昵称，并明确提示未同步', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /private async syncDisplayName\(/, '缺少独立的同步方法');
  const syncCall = page.indexOf('const synced = await this.syncDisplayName');
  const localSave = page.indexOf('await storage.setUserNameForAccount(session.epoch, session.sid, value)');
  assert.ok(syncCall > 0 && localSave > syncCall, '本地保存不能被同步失败挡住');
  assert.match(page, /本地保存失败，请重试/, '本地保存失败要有单独提示');
  const syncBody = page.slice(page.indexOf('private async syncDisplayName'), page.indexOf('build()'));
  assert.match(syncBody, /restore app auth failed/, '恢复令牌失败应被同步方法内部捕获');
  assert.match(syncBody, /return false/, '同步失败应返回 false 而不是抛出');
});

test('令牌可能过期时会恢复后重试一次', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  const matches = page.match(/await UserApi\.updateAppDisplayName\(value, token\)/g) || [];
  assert.ok(matches.length >= 2, '缺少失败后重试');
  assert.match(page, /令牌可能已失效/, '重试原因没有注释说明');
});

test('改昵称期间切号：旧昵称不发给新账号，也不写进新账号', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /interface NicknameSession/, '缺少会话快照');
  assert.match(page, /const session: NicknameSession = \{/, '保存开始时没有固定账号');
  assert.match(page, /private async isAccountChanged\(/, '缺少切号检查方法');
  assert.match(page, /账号已切换，本次改名已取消/, '切号后缺少明确提示');
  assert.match(page, /UserApi\.updateAppDisplayName\(value, token\)/, '没有使用会话快照令牌发送');
});

test('昵称写入串行化：切号期间的旧写入不能覆盖新账号', async () => {
  const storage = await source(`${root}/store/AppStorage.ts`);
  assert.match(storage, /private commitProfileWrite\(/, '缺少串行提交队列');
  assert.match(storage, /if \(this\.sessionEpoch !== epoch\) return false;/, '队列执行时没有校验会话代次');
  assert.match(storage, /async setUserNameForAccount\(epoch: number, sid: string, value: string\): Promise<boolean>/,
    '缺少带会话保护的昵称写入');
  assert.match(storage, /`userName_\$\{account\}`/, '昵称没有写入发起账号的分账号 key');
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  assert.match(page, /if \(!\(await storage\.setUserNameForAccount\(session\.epoch, session\.sid, value\)\)\)/,
    '本地昵称没有使用会话保护的写入');
  const writeIndex = page.indexOf('setUserNameForAccount(session.epoch, session.sid, value)');
  const toastIndex = page.indexOf("'昵称已修改，社区同步生效'");
  assert.ok(writeIndex > 0 && toastIndex > writeIndex, '成功提示必须排在最终写入之后');
});

test('读取账号信息期间切号：昵称不会发给新账号', async () => {
  const page = await source(`${root}/pages/profile/EditNamePage.ets`);
  const epochIndex = page.indexOf('const sessionEpoch = storage.getSessionEpoch();');
  const sidIndex = page.indexOf('const sessionSid = (await storage.getStudentId()).trim();');
  const tokenIndex = page.indexOf('const sessionToken = (await storage.getAppAuthAccessToken()).trim();');
  assert.ok(epochIndex > 0 && sidIndex > epochIndex && tokenIndex > sidIndex, '读取顺序应为代次→学号→令牌');
  assert.match(page, /account changed while reading session, nickname save cancelled/, '读取期间切号没有放弃');
  assert.match(page, /if \(storage\.getSessionEpoch\(\) !== sessionEpoch \|\|/, '读取后没有复核会话');
  const guardIndex = page.indexOf('account changed while reading session, nickname save cancelled');
  const syncIndex = page.indexOf('const synced = await this.syncDisplayName');
  assert.ok(guardIndex > 0 && syncIndex > guardIndex, '会话校验必须在同步/写入之前');
});