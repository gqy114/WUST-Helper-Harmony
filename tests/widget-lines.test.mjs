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
  const model = new SyntheticModule(['CourseData', 'isCourseInWeek'], function () {
    this.setExport('CourseData', undefined);
    this.setExport('isCourseInWeek', () => true);
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
