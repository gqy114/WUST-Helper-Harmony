// 头像编辑：拖动/双指缩放、裁剪截图上传与资料刷新。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('裁剪器支持单指拖动与双指缩放', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /GestureGroup\(GestureMode\.Parallel/, '缺少组合手势');
  assert.match(page, /PanGesture\(\{ fingers: 1, distance: 1 \}\)/, '缺少单指拖动');
  assert.match(page, /PinchGesture\(\{ fingers: 2 \}\)/, '缺少双指缩放');
  assert.match(page, /\.translate\(\{ x: this\.cropOffsetX, y: this\.cropOffsetY \}\)/, '拖动没有作用到图片位置');
  assert.match(page, /applyCropScale\(this\.cropStartScale \* event\.scale\)/, '缩放没有作用到图片大小');
  assert.match(page, /private cropPanLimitX\(\): number/, '缺少平移边界计算');
  assert.match(page, /private rotateCrop\(\): void/, '旋转应重新收拢平移范围');
});

test('裁剪结果按裁剪框截图，而不是直接上传相册原图', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /\.id\('avatarCropBox'\)/, '裁剪框缺少 id，无法截图');
  assert.match(page, /getComponentSnapshot\(\)\.get\('avatarCropBox'\)/, '没有截取裁剪框');
  assert.match(page, /packer\.packing\(snapshot, options\)/, '截图没有编码成图片');
  assert.match(page, /cacheDir\}\/avatar_\$\{Date\.now\(\)\}\.jpg/, '裁剪结果没有落到应用缓存');
  assert.doesNotMatch(page, /files: \[\{[^}]*uri: localUri/, '不能把相册临时 URI 直接交给上传服务');
});

test('上传使用应用缓存路径和登录令牌，成功后拉取服务端头像地址', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /uri: `internal:\/\/cache\/\$\{fileName\}`/, '上传应使用应用沙箱路径');
  assert.match(page, /'Authorization': `Bearer \$\{token\}`/, '上传缺少登录令牌');
  assert.match(page, /UserApi\.getAppProfile\((?:token)?\)/, '上传成功后应刷新账号资料');
  assert.match(page, /await storage\.setAvatarUrlForAccount\(sessionEpoch, sessionSid, updatedAvatar\)/, '服务端头像地址没有保存');

  const api = await source(`${root}/net/UserApi.ets`);
  assert.match(api, /\/api\/v1\/auth\/me/, '缺少账号资料接口');
  assert.match(api, /static async getAppProfile\(tokenSnapshot\?: string\): Promise<AppProfile \| null>/, '缺少 getAppProfile');
});

test('上传失败时恢复原头像，不把本地预览误当成同步成功', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /const previousAvatar = \(await storage\.getAvatarUrl\(\)\)\.trim\(\)/, '裁剪前没有记录原头像');
  assert.match(page, /this\.avatarUrl = previousAvatar/, '上传失败没有恢复界面头像');
  assert.match(page, /await storage\.setAvatarUrlForAccount\(sessionEpoch, sessionSid, previousAvatar\)/, '上传失败没有恢复持久化头像');
  assert.doesNotMatch(page, /setAvatarUrl\(`file:\/\/\$\{localPath\}`\)/, '上传失败不能持久化本地预览');
  assert.match(page, /头像同步失败，已恢复原头像/, '上传失败缺少明确提示');
});
test('上传后必须确认服务端头像已更新，否则按失败处理', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /states\[0\]\.responseCode !== 0/, '没有校验上传任务结果');
  assert.match(page, /(?:const|let) profileBeforeUpload = await UserApi\.getAppProfile\(token\)/, '上传前没有获取服务端头像基线');
  assert.match(page, /updatedAvatar === serverAvatarBeforeUpload/, '没有按服务端旧头像确认是否变化');
  assert.match(page, /avatar not updated on server/, '未更新时没有按失败处理');
});

test('上传前读不到服务端头像时按失败处理，不能冒成功', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /if \(!profileBeforeUpload\) throw new Error\('cannot read avatar baseline'\)/, '基线缺失时没有按失败处理');
  const baselineReads = page.match(/await UserApi\.getAppProfile\(token\)/g) || [];
  assert.ok(baselineReads.length >= 2, '基线读取失败时应当重试一次');
});

test('头像上传绑定账号会话，切号后不写入新账号', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /const sessionSid = \(await storage\.getStudentId\(\)\)\.trim\(\)/, '没有固定发起操作的学号');
  assert.match(page, /private async isAccountChanged\(storage: PreferenceStorage, sid: string, epoch: number\)/,
    '缺少统一的账号变化判断');
  assert.match(page, /账号已切换，本次头像修改已取消/, '切号后没有明确提示');
  assert.match(page, /throw new Error\('account changed'\)/, '切号后没有中止旧操作');
  const beforeRead = page.indexOf('const sessionSid = (await storage.getStudentId())');
  const baselineRead = page.indexOf('UserApi.getAppProfile(token)');
  assert.ok(beforeRead > 0 && baselineRead > beforeRead, '资料查询应在会话快照之后');
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
  const toastIndex = page.indexOf("'头像已同步'");
  assert.ok(writeIndex > 0 && toastIndex > writeIndex, '成功提示必须排在最终写入之后');
  assert.match(page, /if \(await this\.isAccountChanged\(storage, sessionSid, sessionEpoch\)\) \{\s*throw new Error\('account changed'\);\s*\}/,
    '写入后没有再次校验会话，可能向新账号误报成功');
});
