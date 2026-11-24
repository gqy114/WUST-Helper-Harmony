import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';

const source = await readFile(new URL('../entry/src/main/ets/net/DynamicScheduleApi.ets', import.meta.url), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import .+\r?\n/gm, ''), { mode: 'transform' });
const inviteToken = 'ab'.repeat(32);
const grantId = 'cd'.repeat(32);

function loadApi(data, token = 'test-app-token') {
  const requests = [];
  const http = {
    postRawJson: async (url, body, headers) => {
      requests.push({ url, body: JSON.parse(body), headers });
      return { response: { responseCode: 200 }, data };
    },
    get: async (url, headers) => {
      requests.push({ url, headers });
      return { response: { responseCode: 200 }, data };
    }
  };
  const storage = { getInstance: () => ({ getAppAuthAccessToken: async () => token }) };
  const load = new Function('HttpRequest', 'AppStorage',
    code.replace(/^export /gm, '') + '\nreturn { DynamicScheduleApi, readScheduleQrToken };');
  return { ...load(http, storage), requests };
}

test('课表扫码识别安卓路径式二维码和鸿蒙查询参数式二维码', () => {
  const { readScheduleQrToken } = loadApi({});
  assert.equal(readScheduleQrToken('wusthelper://schedule/' + inviteToken), inviteToken);
  assert.equal(readScheduleQrToken('wusthelper://dynamic-schedule?token=' + inviteToken), inviteToken);
  assert.equal(readScheduleQrToken('wusthelper://schedule/' + inviteToken + '/other'), '');
  assert.equal(readScheduleQrToken('https://example.test/schedule/' + inviteToken), '');
  assert.equal(readScheduleQrToken('wusthelper://schedule?student=example'), '');
});

test('兑换后生成独立档案，课程落在对应的大节和周次，刷新使用授权 ID', async () => {
  const { DynamicScheduleApi, requests } = loadApi({
    code: 200, data: {
      grantId, semester: '2026-2027-1', name: '测试同学',
      courses: [{ className: '线性代数', teacher: '测试教师', classroom: '测试教室',
        weekDay: 3, section: 2, endSection: 3, startWeek: 2, endWeek: 8 }]
    }
  });
  const archive = await DynamicScheduleApi.redeemInvite(inviteToken);
  assert.equal(archive.id, 'shared_' + grantId);
  assert.equal(archive.isMine, false);
  assert.deepEqual(archive.courses[0], {
    courseName: '线性代数', teacher: '测试教师', location: '测试教室',
    dayOfWeek: 3, startPeriod: 3, endPeriod: 6, weekRanges: '2-8'
  });
  assert.match(requests[0].url, /\/api\/v1\/schedules\/redeem$/);
  assert.deepEqual(requests[0].body, { token: inviteToken });
  assert.equal(requests[0].headers.Authorization, 'Bearer test-app-token');
  assert.deepEqual(await DynamicScheduleApi.getSharedSchedule(archive.id), archive);
  assert.equal(requests[1].url.endsWith('/shared/' + grantId), true);
});

test('过期、登录失效和空响应显示可处理的错误，无账号时不发送请求', async () => {
  for (const [response, message] of [
    [{ code: 410 }, /二维码已过期/],
    [{ code: 401 }, /登录已失效/],
    [{ code: 200, data: null }, /响应无效/]
  ]) {
    await assert.rejects(loadApi(response).DynamicScheduleApi.redeemInvite(inviteToken), message);
  }
  const loggedOut = loadApi({}, '');
  await assert.rejects(loggedOut.DynamicScheduleApi.redeemInvite(inviteToken), /请先登录/);
  assert.equal(loggedOut.requests.length, 0);
});

test('快速连切两个共享档案时只允许第一个切换，避免覆盖我的课表', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/course/CourseArchivePage.ets', import.meta.url), 'utf8');
  assert.match(page, /private switching: boolean = false;/, '缺少切换互斥标记');
  assert.match(page, /if \(this\.switching\) return;/, '切换时没有拦截并发点击');
  assert.match(page, /finally \{\s*this\.switching = false;/, '切换结束后没有释放互斥');
});

test('导入期间切换档案会丢弃旧导入，且切换档案会更新学期与开学日期', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/course/CourseArchivePage.ets', import.meta.url), 'utf8');
  assert.match(page, /const importEpoch = this\.archiveEpoch;/, '没有记录导入开始时的档案代次');
  assert.match(page, /if \(importEpoch !== this\.archiveEpoch\)/, '切换档案后没有丢弃旧导入');
  assert.match(page, /private termStartForSemester\(semester: string\): string/, '缺少按学期计算开学日期');
  assert.match(page, /setSettingString\('archiveSemester', archive\.semester\)/, '切换档案没有记录档案学期');
  assert.doesNotMatch(page, /storage\.setSemester\(archive\.semester\)/, '切换档案不应覆盖 App 当前学期');
  assert.match(page, /setSettingString\('archiveTermStartDate', termStart\)/, '切换档案没有记录档案开学日期');
  const course = await readFile(new URL('../entry/src/main/ets/pages/course/CoursePage.ets', import.meta.url), 'utf8');
  assert.match(course, /getSettingString\('archiveTermStartDate'/, '课表页没有读取档案开学日期');
});
