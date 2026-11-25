import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('校园资讯筛选来源和栏目都从后端获取', async () => {
  const api = await source('net/CampusNewsApi.ets');
  assert.match(api, /static async colleges\(\): Promise<NewsCollege\[\]>/, '缺少来源接口');
  assert.match(api, /static async categories\(collegeId: string = ''\): Promise<NewsCategory\[\]>/, '缺少栏目接口');
  assert.match(api, /\/colleges/, '没有请求 colleges');
  assert.match(api, /\/categories/, '没有请求 categories');
  const page = await source('pages/campus/CampusPage.ets');
  assert.doesNotMatch(page, /材料科学与工程学院/, '页面写死了学院列表');
  assert.match(page, /await CampusNewsApi\.colleges\(\)/, '来源没有从后端加载');
  assert.match(page, /await CampusNewsApi\.categories\(id\)/, '栏目没有按来源从后端加载');
});

test('筛选按钮位于搜索左侧，全部来源时栏目给出提示', async () => {
  const page = await source('pages/campus/CampusPage.ets');
  const filter = page.indexOf("'筛选校园资讯'");
  const search = page.indexOf("app.media.search");
  assert.ok(filter > 0 && search > filter, '筛选按钮不在搜索左侧');
  assert.match(page, /先选择学校或学院/, '全部来源时缺少选择提示');
  assert.match(page, /CampusNewsApi\.articles\(this\.page, PAGE_SIZE, this\.collegeId, this\.categoryUrl\)/, '筛选条件没有传给文章接口');
  assert.match(page, /this\.filterRow\('全部来源'/, '缺少全部来源选项');
});
