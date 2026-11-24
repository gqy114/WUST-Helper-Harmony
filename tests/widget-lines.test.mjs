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
  const model = new SourceTextModule(transform(await source('../entry/src/main/ets/model/CourseModel.ts')));
  const widget = new SourceTextModule(transform((await source('../entry/src/main/ets/widget/WidgetData.ets')).replace('CourseData, ', '')));
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
  assert.match(grid.at(-1).color, /^#[0-9a-f]{6}$/i);
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

test('青山 10:05 从 10:10 上课的第二门开始轮播', async () => {
  const WidgetData = await loadWidget();
  const first = { ...makeCourses(1)[0], endPeriod: 2 };
  const second = { ...first, courseName: '第二门', startPeriod: 3, endPeriod: 4 };
  const snapshot = WidgetData.courseSnapshot([first, second], 13, 'daily', '#123456',
    new Date(2026, 10, 23, 10, 5), '青山校区');
  assert.deepEqual(JSON.parse(snapshot.dailyCourses).map(({ name, start, end }) => [name, start, end]), [
    ['第二门', '10:10', '11:50'], [first.courseName, '08:00', '09:40'],
  ]);
});

test('仍有考试时，新建自定义倒计时也加入桌面卡片轮换', async () => {
  const WidgetData = await loadWidget();
  const storage = {
    getStudentId: async () => 'student',
    getSemester: async () => '2026-2027-1',
    getSettingString: async (key, fallback) => {
      if (key === 'widgetCountdowns') return JSON.stringify([
        { title: '已结束活动', date: '2020-01-01' },
        { title: '刚添加的倒计时', date: '2099-06-02' },
      ]);
      if (key === 'widgetExamCountdowns_student_2026-2027-1') return JSON.stringify([
        { title: '待考课程', date: '2099-06-01 14:00' },
      ]);
      return fallback;
    },
  };
  const snapshot = await WidgetData.build(storage, false, 'countdown');
  assert.deepEqual(JSON.parse(snapshot.countdownSlides).map(slide => slide.title),
    ['待考课程', '刚添加的倒计时']);
});

test('考试当日考完仍显示 0 天，隔天移出轮换，保留日期时间与开始天数', async () => {
  const WidgetData = await loadWidget();
  const items = [
    { title: '昨日考试', date: '2026-11-23 16:00' },
    { title: '今天上午考试', date: '2026-11-24 08:20', startedOn: '2026-11-21' },
    { title: '明天考试', date: '2026-11-25 14:00' },
    { title: '无效日期', date: '2026-11-31 08:20' },
  ];
  const snapshot = (date) => WidgetData.countdownSnapshot(items, '#123456', date);
  assert.deepEqual(JSON.parse(snapshot(new Date(2026, 10, 24, 23, 59)).countdownSlides), [
    { title: '今天上午考试', date: '2026-11-24 08:20', elapsed: '3', remaining: '0' },
    { title: '明天考试', date: '2026-11-25 14:00', elapsed: '—', remaining: '1' },
  ]);
  assert.deepEqual(JSON.parse(snapshot(new Date(2026, 10, 25)).countdownSlides).map(s => s.title), ['明天考试']);
  assert.deepEqual(JSON.parse(snapshot(new Date(2026, 10, 26)).countdownSlides), []);
});

test('周课表以本周为默认滑页，前后周各自显示课程并共用相同网格', async () => {
  const WidgetData = await loadWidget();
  const [template] = makeCourses(1);
  const snapshot = WidgetData.courseSnapshot([
    { ...template, courseName: '上周课程', weekRanges: '12' },
    { ...template, courseName: '本周之后课程', weekRanges: '13-14' },
  ], 13, 'weekly', '#123456');
  const { grids, weekGridIndexes } = JSON.parse(snapshot.weeklyPages);
  const names = (week) => JSON.parse(grids[weekGridIndexes[week - 1]]).map(c => c.name);
  assert.equal(snapshot.weeklyCurrentWeek, 13);
  assert.deepEqual(names(12), ['上周课程']);
  assert.deepEqual(names(13), ['本周之后课程']);
  assert.deepEqual(names(15), []);
  assert.equal(weekGridIndexes[12], weekGridIndexes[13]);
  assert.equal(weekGridIndexes.length, 25);
});

test('快捷功能电量显示真实零值，缺少读数时显示占位', async () => {
  const WidgetData = await loadWidget();
  const snapshot = (rooms) => WidgetData.build({
    getSettingString: async (key, fallback) => key === 'electricityRooms' ? JSON.stringify(rooms) : fallback,
  }, false, 'quick');
  const zero = await snapshot([{ name: '1630 房间', remaining: 0 }]);
  assert.equal(zero.title, '1630 房间');
  assert.equal(zero.subtitle, '0度');
  assert.equal((await snapshot([{ name: '1630 房间' }])).subtitle, '—');
  assert.equal((await snapshot([])).title, '未绑定房间');
});

test('快捷按钮在浅蓝底上使用深色文字保证可读性', async () => {
  const card = await source('../entry/src/main/ets/widget/WidgetCard.ets');
  const block = card.slice(card.indexOf('private quickTile'), card.indexOf('private quickContent'));
  assert.match(block, /fontColor\('#123A66'\)/, '快捷按钮文字不是深色');
  assert.doesNotMatch(block, /fontColor\(Color\.White\)/, '快捷按钮仍是白字');
});

test('房间名和电量数字在浅蓝底上使用深色文字', async () => {
  const card = await source('../entry/src/main/ets/widget/WidgetCard.ets');
  assert.match(card, /Text\(this\.title\)\.fontSize\(11\)\.fontColor\('#123A66'\)/, '房间名不是深色');
  assert.match(card, /Text\(this\.subtitle\)\.fontSize\(18\)\.fontWeight\(FontWeight\.Medium\)\.fontColor\('#123A66'\)/, '电量数字不是深色');
});
