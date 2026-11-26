// 头像编辑：拖动/双指缩放、裁剪截图上传与资料刷新。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('头像用原图裁剪和缩放，辅助圆框不拦截拖动', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /PanGesture\(\{ fingers: 1, distance: 3 \}\)/);
  assert.match(page, /PinchGesture\(\{ fingers: 2 \}\)/);
  assert.match(page, /applyCropScale\(this\.cropStartScale \* event\.scale\)/);
  assert.match(page, /Circle\(\)[\s\S]+?\.hitTestBehavior\(HitTestMode\.None\)/);
  assert.match(page, /sourceCrop\(this\.rotatedWidth\(\), this\.rotatedHeight\(\)/);
  assert.match(page, /PhotoCropImage\.crop\(this\.cropImageUri, region, this\.cropRotation\)/);
  assert.doesNotMatch(page, /getComponentSnapshot/);
});

test('头像上传读取服务端业务响应，授权失效时恢复登录并重试一次', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /response\.code === 401/);
  assert.match(page, /ApiService\.loginAppAuthFromSavedCredentials\(storage\)/);
  assert.match(page, /response\.code !== 200 \|\| !updatedAvatar/);
  assert.match(page, /await storage\.setAvatarUrlForAccount\(sessionEpoch, sessionSid, updatedAvatar\)/);
  assert.match(page, /头像未能同步，请检查登录或网络后重试/);
  assert.doesNotMatch(page, /this\.avatarUrl = `file:/);
  const api = await source(`${root}/net/UserApi.ets`);
  assert.match(api, /multiFormDataList: \[\{ name: 'avatar',[^}]*data: jpeg/);
  assert.match(api, /Authorization: `Bearer \$\{token\}`/);
});

test('账号资料写入串行化：切号期间的旧写入不能覆盖新账号', async () => {
  const storage = await source(`${root}/store/AppStorage.ts`);
  assert.match(storage, /private commitProfileWrite\(/, '缺少串行提交队列');
  assert.match(storage, /if \(this\.sessionEpoch !== epoch\) return false;/, '队列执行时没有校验会话代次');
  assert.match(storage, /async setAvatarUrlForAccount\(epoch: number, sid: string, value: string\): Promise<boolean>/,
    '缺少带会话保护的头像写入');
  assert.match(storage, /private async getProfileValue\(key: string\): Promise<string>/, '资料没有按账号分 key');
  assert.match(storage, /`avatarUrl_\$\{account\}`/, '头像没有写入发起账号的分账号 key');
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  const writeIndex = page.indexOf('setAvatarUrlForAccount(sessionEpoch, sessionSid, updatedAvatar)');
  assert.ok(writeIndex > 0, '头像地址未持久化');
  assert.match(page, /await this\.uploadAvatar\(jpeg, sessionSid, sessionEpoch\);[\s\S]+?'头像已同步'/,
    '成功提示必须排在上传保存之后');
  assert.match(page, /if \(await this\.isAccountChanged\(storage, sessionSid, sessionEpoch\)\) \{\s*throw new Error\('account changed'\);\s*\}/,
    '写入后没有再次校验会话，可能向新账号误报成功');
});

test('读取账号信息期间切号：先取代次再读学号，读到一半切号则放弃', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  const epochIndex = page.indexOf('const sessionEpoch = storage.getSessionEpoch();');
  const sidIndex = page.indexOf('const sessionSid = (await storage.getStudentId()).trim();');
  assert.ok(epochIndex > 0 && sidIndex > epochIndex, '应先同步取代次再异步读学号');
  assert.match(page, /if \(await this\.isAccountChanged\(storage, sessionSid, sessionEpoch\)\) throw new Error\('account changed'\)/);
  assert.match(page, /账号已切换，本次头像修改已取消/);
});
async function createAvatarUploader(responses) {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  const method = page.match(/  private async uploadAvatar\([\s\S]*?\n  \}/)[0];
  let token = 'old';
  const tokens = [];
  const saved = [];
  const storage = {
    getAppAuthAccessToken: async () => token,
    setAvatarUrlForAccount: async (...args) => { saved.push(args); return true; },
  };
  const Upload = runInNewContext(stripTypeScriptTypes('class Upload {\n' + method + '\n}; Upload;'), {
    PreferenceStorage: { getInstance: () => storage },
    ApiService: { loginAppAuthFromSavedCredentials: async () => { token = 'new'; } },
    UserApi: { uploadAppAvatar: async (_, value) => { tokens.push(value); return responses.shift(); } },
  });
  const uploader = Object.assign(new Upload(), { isAccountChanged: async () => false, avatarUrl: 'old-avatar' });
  return { uploader, tokens, saved };
}

test('头像接口返回 401 时只重试一次，保存服务器返回的头像地址', async () => {
  const { uploader, tokens, saved } = await createAvatarUploader([
    { code: 401 }, { code: 200, data: { avatarUrl: 'https://example.test/avatar.jpg' } },
  ]);
  await uploader.uploadAvatar(new ArrayBuffer(4), 'sid', 7);
  assert.deepEqual(tokens, ['old', 'new']);
  assert.deepEqual(saved, [[7, 'sid', 'https://example.test/avatar.jpg']]);
});

test('上传业务失败或成功响应缺少地址时保留原头像', async () => {
  for (const response of [{ code: 500 }, { code: 200 }]) {
    const { uploader, saved } = await createAvatarUploader([response]);
    await assert.rejects(uploader.uploadAvatar(new ArrayBuffer(4), 'sid', 7), /avatar rejected/);
    assert.equal(uploader.avatarUrl, 'old-avatar');
    assert.deepEqual(saved, []);
  }
});

test('读取令牌期间发生切号时，中止头像上传', async () => {
  const { uploader, tokens, saved } = await createAvatarUploader([]);
  let checks = 0;
  uploader.isAccountChanged = async () => ++checks > 1;
  await assert.rejects(uploader.uploadAvatar(new ArrayBuffer(4), 'sid', 7), /account changed/);
  assert.deepEqual(tokens, []);
  assert.deepEqual(saved, []);
});
