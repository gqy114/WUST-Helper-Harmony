// 桌面卡片锁定按钮：倒计时/日课表/周课表。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/widget/${path}`, import.meta.url), 'utf8');

test('倒计时和日课表锁定后停止自动轮换，仍可手动滑动', async () => {
  for (const file of ['CountdownWidgetCarousel.ets', 'DailyWidgetCarousel.ets']) {
    const page = await source(file);
    assert.match(page, /ic_widget_lock/, `${file} 缺少锁图标`);
    assert.match(page, /#61A5FA/, `${file} 激活态不是蓝色`);
    assert.match(page, /autoPlay\(!this\.locked/, `${file} 锁定后仍在自动轮换`);
  }
  const countdown = await source('CountdownWidgetCarousel.ets');
  assert.match(countdown, /this\.lockIcon\(15\)/, '2*2 倒计时的锁图标没有缩小');
  assert.match(countdown, /remainingDays/, '锁定后没有处理倒计时结束');
});

test('周课表只在非本周显示锁，锁定后不再 30 秒回本周', async () => {
  const page = await source('WeeklyWidgetCarousel.ets');
  assert.match(page, /ic_widget_lock/, '缺少锁图标');
  assert.match(page, /this\.displayIndex !== this\.currentPageIndex\(\)/, '非本周才显示锁');
  assert.match(page, /private toggleLock\(\)/, '缺少锁定切换');
  assert.match(page, /if \(this\.locked\) return;/, '锁定后仍会启动 30 秒回本周');
  assert.match(page, /else if \(this\.displayIndex !== this\.currentPageIndex\(\)\) \{\s*this\.startAutoReturn\(\);/, '取消锁定后没有恢复 30 秒逻辑');
});
