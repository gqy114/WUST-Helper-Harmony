import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { getTimeSlotsByCampus } from '../entry/src/main/ets/model/CourseModel.ts';

const source = (name) => readFile(new URL('../entry/src/main/ets/' + name, import.meta.url), 'utf8');

test('周课卡片的桌面与预览都使用已保存的校区', async () => {
  const [page, data, card, settings, grid] = await Promise.all([
    source('pages/course/CoursePage.ets'), source('widget/WidgetData.ets'),
    source('widget/WidgetCard.ets'), source('pages/profile/WidgetSettingsPage.ets'),
    source('widget/WeeklyWidgetGrid.ets'),
  ]);
  assert.match(page, /setSettingString\('courseCampus', campus\)/);
  assert.match(data, /getSettingString\('courseCampus'/);
  assert.match(card, /WeeklyWidgetCarousel\(\{[^}]*campus: this\.campus/);
  assert.match(settings, /WeeklyWidgetCarousel\(\{[^}]*campus: this\.snapshot\?\.campus/);
  assert.match(grid, /ForEach\(getTimeSlotsByCampus\(this\.campus\)/);
  assert.equal(getTimeSlotsByCampus('青山校区')[0].start, '08:00');
  assert.equal(getTimeSlotsByCampus('黄家湖校区')[0].start, '08:20');
});

test('周课块的分栏数变化后，ArkUI 重建旧课块并应用新宽度', async () => {
  const grid = await source('widget/WeeklyWidgetGrid.ets');
  const key = grid.split('}, (course: WeeklyWidgetCourse) => ')[1]?.split('\n')[0];
  assert.ok(key?.includes('${course.lanes}'));
  assert.match(grid, /\.width\([^\n]+\/ course\.lanes\}%/);
});

test('周课表滑到非本周后 30 秒自动回到本周', async () => {
  const carousel = await source('widget/WeeklyWidgetCarousel.ets');
  assert.match(carousel, /setTimeout\(\(\) => \{/, '没有自动回到本周的定时器');
  assert.match(carousel, /\}, 30000\);/, '定时器不是 30 秒');
  assert.match(carousel, /swiperController\.changeIndex\(this\.currentPageIndex\(\), true\)/, '没有切回本周');
  assert.match(carousel, /onChange\(\(index: number\) => this\.onPageChanged\(index\)\)/, '没有监听滑动');
  assert.match(carousel, /clearTimeout/, '再次滑动时没有重置计时');
});

test('周课表刷新后按内容重建页面，避免复用旧课程', async () => {
  const carousel = await source('widget/WeeklyWidgetCarousel.ets');
  assert.ok(carousel.includes('${index}-${gridIndex}-${this.pages.grids['), '页面 key 没有包含课程内容');
  assert.ok(!carousel.includes('=> String(index))'), '仍在用固定 index 作为 key');
});
