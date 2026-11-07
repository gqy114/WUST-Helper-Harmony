// 敏感请求 HTTPS 约束：所有携带学校学号/密码/令牌的接口都必须显式 secure。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const root = '../entry/src/main/ets/net';

test('物理实验：学号与密码只走 HTTPS', async () => {
  const code = await source(`${root}/PhysicalExperimentApi.ets`);
  assert.match(code, /undefined, true,\s*\n\s*\);/);
});

test('第二课堂：学号与密码只走 HTTPS', async () => {
  const code = await source(`${root}/SecondClassroomApi.ets`);
  assert.match(code, /\}, undefined, undefined, true\);/);
});

test('培养方案（研究生）：学号与密码只走 HTTPS', async () => {
  const training = await source(`${root}/TrainingPlanApi.ets`);
  assert.match(training, /\}, undefined, undefined, true\);/);
  const cultivation = await source(`${root}/CultivationPlanApi.ets`);
  assert.match(cultivation, /\}, undefined, undefined, true\);/);
});

test('学生信息解析：登录与解析都只走 HTTPS', async () => {
  const code = await source(`${root}/UserApi.ets`);
  assert.match(code, /headers: \{ Accept: 'application\/json' \}, secure: true \}/);
  assert.match(code, /\}, undefined, true\);/);
  assert.match(code, /secure: true,\s*\n\s*\}\);/);
});

test('公共请求层：带认证头的请求自动按敏感处理', async () => {
  const code = await source(`${root}/HttpRequest.ts`);
  // 只要 header 里有 Authorization / Cookie / Token，就只允许 HTTPS，
  // 不再依赖每个调用方记得传 secure。
  assert.match(code, /private static needsSecure\(/);
  assert.match(code, /key === 'authorization' \|\| key === 'cookie' \|\| key === 'token'/);
  assert.match(code, /HttpRequest\.needsSecure\(options, header\)/);
});

test('校园代理请求把原始认证头打包进 body，也必须走 HTTPS', async () => {
  const code = await source(`${root}/HttpRequest.ts`);
  // 改写前先用原始 header 判断敏感性，代理信封一律按敏感处理。
  assert.match(code, /let secureRequest = HttpRequest\.needsSecure\(options, header\);/);
  assert.match(code, /secureRequest = true;/);
  assert.match(code, /backendTargets\(requestUrl, options\?\.pinBackend \?\? false, secureRequest\)/);
});
