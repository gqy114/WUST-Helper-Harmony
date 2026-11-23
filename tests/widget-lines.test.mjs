// 小组件课程行的边界行为：0 / 3 / 4 / 5 门时分别应显示什么。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });

async function loadWidget() {
  const context = createContext({ console });
  const storage = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => ({}) });
  });
  const model = new SyntheticModule(['CourseData', 'isCourseInWeek', 'getCourseColor', 'PERIOD_COUNT', 'TIME_SLOTS'], function () {
    this.setExport('CourseData', undefined);
    this.setExport('isCourseInWeek', (course) => course.weekRanges !== '1-2');
    this.setExport('getCourseColor', () => '#2196f3');
    this.setExport('PERIOD_COUNT', 12);
    this.setExport('TIME_SLOTS', [
      { start: '08:20', end: '10:00', startPeriod: 1, endPeriod: 2 },
      { start: '10:20', end: '12:00', startPeriod: 3, endPeriod: 4 },
      { start: '14:00', end: '15:40', startPeriod: 5, endPeriod: 6 },
    ]);
  });
  const widget = new SourceTextModule(transform(await source('../entry/src/main/ets/widget/WidgetData.ets')));
  await widget.link((name) => {
    if (name === '../store/AppStorage') return storage;
    if (name === '../model/CourseModel') return model;
    throw new Error(`Unexpected import: ${name}`);
  });
  await widget.evaluate();
  return widget.namespace.WidgetData;
}

const makeCourses = (count) => {
  const list = [];
  for (let i = 0; i < count; i++) {
    list.push({
      courseName: `课程${i + 1}`, teacher: '', location: '', dayOfWeek: (i % 7) + 1,
      startPeriod: i + 1, endPeriod: i + 1, weekRanges: '1-16', color: '#fff',
    });
  }
  return list;
};

test('四门课程：四行全部显示，不应被截断', async () => {
  const WidgetData = await loadWidget();
  const snapshot = WidgetData.courseSnapshot(makeCourses(4), 10, 'weekly', '#1ec98d');
  assert.match(snapshot.line0, /课程1/);
  assert.match(snapshot.line3, /课程4/, `第四门应显示，实际 line3=${snapshot.line3}`);
  assert.doesNotMatch(snapshot.line0 + snapshot.line3, /还有/);
});

test('日课表从最近课程开始按节次循环，只包含当天本周课程', async () => {
  const WidgetData = await loadWidget();
  const template = makeCourses(1)[0];
  const courses = [1, 3, 5].map((startPeriod) => ({
    ...template, courseName: `课${startPeriod}`, startPeriod, endPeriod: startPeriod + 1,
    location: '教一楼', teacher: '王老师',
  }));
  courses.push({ ...courses[0], courseName: '其他星期', dayOfWeek: 2 });
  courses.push({ ...courses[0], courseName: '其他周', weekRanges: '1-2' });
  const at = (hour, minute) => WidgetData.courseSnapshot(courses, 13, 'daily', '#123456',
    new Date(2026, 10, 23, hour, minute));
  const order = (snapshot) => JSON.parse(snapshot.dailyCourses).map((course) => course.name);
  assert.deepEqual(order(at(7, 0)), ['课1', '课3', '课5']);
  assert.deepEqual(order(at(10, 10)), ['课3', '课5', '课1']);
  assert.deepEqual(order(at(11, 0)), ['课3', '课5', '课1']);
  assert.deepEqual(order(at(18, 0)), ['课5', '课1', '课3']);
  const snapshot = at(11, 0);
  assert.equal(snapshot.title, '11月23日');
  assert.equal(snapshot.dailyWeekday, '第13周 周一');
  assert.deepEqual(JSON.parse(snapshot.dailyCourses)[0], {
    name: '课3', start: '10:20', end: '12:00', details: '教一楼 · 王老师',
  });
  assert.deepEqual(JSON.parse(WidgetData.courseSnapshot([], 13, 'daily', '#123456').dailyCourses), []);
});

test('周课表网格保留完整周次、周日、晚课和同节次不同课程', async () => {
  const WidgetData = await loadWidget();
  const courses = makeCourses(7);
  courses[6].startPeriod = 10;
  courses[6].endPeriod = 12;
  courses.push({ ...courses[6], courseName: '同时间课程', color: undefined });
  courses.push({ ...courses[6], courseName: '非本周课程', weekRanges: '1-2' });
  const grid = JSON.parse(WidgetData.courseSnapshot(courses, 10, 'weekly', '#1ec98d').weeklyCourses);
  assert.equal(grid.length, 8);
  assert.deepEqual(grid.slice(-2).map(({ day, start, end, lane, lanes }) => [day, start, end, lane, lanes]),
    [[7, 10, 12, 0, 2], [7, 10, 12, 1, 2]]);
  assert.equal(grid.at(-1).color, '#2196f3');
});

test('五门课程：显示三门 + 还有两门提示', async () => {
  const WidgetData = await loadWidget();
  const snapshot = WidgetData.courseSnapshot(makeCourses(5), 10, 'weekly', '#1ec98d');
  assert.match(snapshot.line2, /课程3/);
  assert.equal(snapshot.line3, '还有 2 门课程');
});

test('三门与零门：不出现溢出提示', async () => {
  const WidgetData = await loadWidget();
  const three = WidgetData.courseSnapshot(makeCourses(3), 10, 'weekly', '#1ec98d');
  assert.match(three.line2, /课程3/);
  assert.equal(three.line3, '');
  const zero = WidgetData.courseSnapshot([], 10, 'daily', '#1ec98d');
  assert.equal(zero.line0, '');
  assert.match(zero.subtitle, /没有课程/);
});
