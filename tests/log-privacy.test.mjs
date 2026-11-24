// 日志隐私：学生资料、学号、令牌和完整响应体不得写入日志。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('UserApi 日志只保留阶段、状态码、耗时和错误类型', async () => {
  const api = await source('net/UserApi.ets');
  assert.match(api, /getStudentInfoPage start/);
  assert.match(api, /elapsedMs=\$\{Date\.now\(\) - startedAt\}/);
  assert.match(api, /hasFields=/);
  assert.doesNotMatch(api, /studentId=\$\{/);
  assert.doesNotMatch(api, /JSON\.stringify\((normalized|parsedInfo)\)/);
  assert.match(api, /type=\$\{error instanceof Error \? error\.name : typeof error\}/);
});

test('登录与个人资料页不再输出令牌、学号或完整资料', async () => {
  const login = await source('pages/login/LoginPage.ets');
  assert.doesNotMatch(login, /login token saved: ' \+ tdata\.token/);
  const info = await source('pages/profile/InfoSettingsPage.ets');
  assert.doesNotMatch(info, /studentId=\$\{this\.studentId\}/);
  assert.doesNotMatch(info, /JSON\.stringify\(data\)/);
  assert.match(info, /apply profile fields=/);
});
