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
  assert.match(page, /没有获取到考试安排：可能登录已失效，或本学期没有考试/, '空列表不能直接断言没有考试');
  assert.match(page, /登录状态已失效，请重新登录后查看考试安排/, '无令牌时缺少登录失效提示');
});

test('诊断日志不输出令牌内容', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /hasToken=\$\{hasToken\}/, '日志应只输出是否有令牌');
  assert.doesNotMatch(page, /console\.(info|warn|error)\([^)]*token\)/, '日志不能直接输出令牌');
});

test('部分失败不会被当成“暂无”，且其它倒计时存在时也能看到提示', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /this\.examFailed = true;/, '考试失败没有记录状态');
  assert.match(page, /this\.customFailed = true;/, '自定义倒计时失败没有记录状态');
  assert.match(page, /if \(this\.examFailed\) \{[\s\S]*?考试安排获取失败/, '考试失败时应显示失败原因');
  assert.match(page, /if \(this\.customFailed\) \{[\s\S]*?hints\.push/, '自定义失败应显示对应原因');
  assert.match(page, /hints\.push\(hasToken/, '空列表提示应按是否有令牌区分');
  const hintRows = page.match(/if \(this\.loadHint\.length > 0\) \{/g) || [];
  assert.ok(hintRows.length >= 2, '列表非空时也要显示失败提示');
});

test('倒计时按离现在远近排序，已结束置底并灰显', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /private isEndedCountdown\(value: string\): boolean/, '缺少结束判断');
  assert.match(page, /return timestamp < startOfToday;/, '当天不应算结束');
  assert.match(page, /if \(endedA !== endedB\) return endedA \? 1 : -1;/, '已结束项没有置底');
  assert.match(page, /return endedA \? stampB - stampA : stampA - stampB;/, '未结束项没有按最近优先');
  assert.match(page, /this\.eventCount = this\.events\.filter/, '正在进行数量没有排除已结束项');
  assert.match(page, /Text\('已结束'\)/, '已结束项没有显示已结束');
  assert.match(page, /#9B9B9B/, '已结束项文字没有变灰');
  assert.match(page, /List\(\) \{ ListItem\(\)/, '倒计时列表没有用 List 顶对齐');
  assert.match(page, /\.margin\(\{ top: -40 \}\)/, '第一张卡片没有越过绿色区域');
});

test('倒计时天数按日历日期差计算，不向上取整', async () => {
  const page = await source('entry/src/main/ets/pages/countdown/CountdownPage.ets');
  assert.match(page, /const startOfEvent = new Date\(event\.getFullYear\(\), event\.getMonth\(\), event\.getDate\(\)\)\.getTime\(\);/, '没有按日期计算');
  assert.match(page, /Math\.round\(\(startOfEvent - startOfToday\) \/ 86400000\)/, '仍在向上取整');
  assert.doesNotMatch(page, /Math\.ceil\(\(timestamp - startOfToday\) \/ 86400000\)/, '仍会把今天算成 1 天');
});
