// 倒计时页考试列表：静态 import、失败可见提示、不输出令牌。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('考试列表使用静态 AppStorage 引用，不再动态 import', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /import \{ AppStorage \} from '\.\.\/\.\.\/store\/AppStorage';/, '缺少静态导入');
  assert.doesNotMatch(page, /await import\(/, '动态 import 在扩展进程/部分设备会失败');
});

test('考试获取失败时给出可见提示，而不是只留“没有内容”', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /@State private loadHint: string = '';/, '缺少失败提示状态');
  assert.match(page, /考试列表获取失败/, '失败只写日志，用户看不到原因');
  assert.match(page, /考试安排获取失败，请重新登录或稍后重试/, '缺少用户可读的失败提示');
  assert.match(page, /暂无倒计时或考试安排/, '空列表缺少说明');
});

test('诊断日志不输出令牌内容', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /hasToken=\$\{token\.length > 0\}/, '日志应只输出是否有令牌');
  assert.doesNotMatch(page, /console\.(info|warn|error)\([^)]*token\)/, '日志不能直接输出令牌');
});
