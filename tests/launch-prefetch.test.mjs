// 启动页体验回归测试：
// 1) 启动页 1.5s 内点击任意位置可以跳过；
// 2) 启动页展示期间会预取第一屏数据（课表或主页，取决于「课表作为首页」设置）；
// 3) 预取到的课表会被课表页直接复用，不会首屏再等一次网络。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const root = '../entry/src/main';

test('启动页：点击任意位置立即跳过，不点击保持 1.5s', async () => {
  const code = await source(`${root}/ets/pages/splash/LaunchPage.ets`);
  assert.match(code, /setTimeout\(\(\) => this\.handleNavigation\(\), 1500\)/);
  // 根容器和开屏图都要能命中点击，兼容安全区域/不同渲染设备。
  assert.match(code, /\.onClick\(\(\) => \{[\s\S]{0,220}this\.handleNavigation\(\);/);
  assert.match(code, /private async handleNavigation/);
});

test('启动页：展示期间启动预取任务', async () => {
  const code = await source(`${root}/ets/pages/splash/LaunchPage.ets`);
  assert.match(code, /LaunchPrefetchService\.start\(\)/);
});

test('预取：按「课表作为首页」决定预取课表还是主页', async () => {
  const code = await source(`${root}/ets/service/LaunchPrefetchService.ets`);
  assert.match(code, /getCourseAsHome\(\)/);
  assert.match(code, /prefetchCourse/);
  assert.match(code, /HomeContentApi\.preload\(\)/);
  assert.match(code, /getGraduateCourseTable/);
  assert.match(code, /getCourseTable/);
  assert.match(code, /setCurrentCourses\(list, writeMarker\)/);
});

test('课表页：预取刚完成时不再重复请求', async () => {
  const code = await source(`${root}/ets/pages/course/CoursePage.ets`);
  // 复用预取结果前必须同时匹配账号、身份和学期，不能只看时间戳。
  assert.match(code, /LaunchPrefetchService\.coursePrefetchedRecently\(prefetchSid, prefetchGraduate, this\.currentSemester\)/);
});

test('主页内容：预取后 60 秒内复用缓存', async () => {
  const code = await source(`${root}/ets/net/HomeContentApi.ets`);
  assert.match(code, /static async preload\(\)/);
  assert.match(code, /CACHE_TTL_MS/);
  assert.match(code, /bannersCache/);
  assert.match(code, /noticesCache/);
});
