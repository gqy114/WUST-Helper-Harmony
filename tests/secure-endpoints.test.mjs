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
