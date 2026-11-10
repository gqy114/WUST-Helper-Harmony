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
  assert.match(page, /UserApi\.getAppProfile\(\)/, '上传成功后应刷新账号资料');
  assert.match(page, /await storage\.setAvatarUrl\(profile\.avatarUrl\)/, '服务端头像地址没有保存');

  const api = await source(`${root}/net/UserApi.ets`);
  assert.match(api, /\/api\/v1\/auth\/me/, '缺少账号资料接口');
  assert.match(api, /static async getAppProfile\(\): Promise<AppProfile \| null>/, '缺少 getAppProfile');
});

test('上传失败时保留本地裁剪结果', async () => {
  const page = await source(`${root}/pages/profile/InfoSettingsPage.ets`);
  assert.match(page, /setAvatarUrl\(`file:\/\/\$\{localPath\}`\)/, '上传失败应保留本地头像');
  assert.match(page, /头像已更新，服务器同步失败/, '上传失败缺少提示');
});
