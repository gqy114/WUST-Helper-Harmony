import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

const source = await readFile(new URL('../entry/src/main/ets/utils/UpdateNotice.ts', import.meta.url), 'utf8');
const code = stripTypeScriptTypes(source, { mode: 'transform' });
const context = createContext({});
const module = new SourceTextModule(code, { context });
await module.link(() => { throw new Error('UpdateNotice has no imports'); });
await module.evaluate();
const { isUpdateNotice } = module.namespace;

test('反馈公告不会被当成检查更新弹窗', () => {
  assert.equal(isUpdateNotice({
    title: '问题反馈解决一站式 https://11408.online/WHQA/',
    context: '大家有相关的登陆问题或改密码的问题可以在这个网址查看并解决',
    platform: 0,
  }), false);
});

test('其他平台的更新公告不会在鸿蒙端误报', () => {
  assert.equal(isUpdateNotice({ title: 'IOS更新通知', context: '请更新到新版本', platform: 1 }), false);
  assert.equal(isUpdateNotice({ title: '安卓更新通知', context: '请安装新版', platform: 'android' }), false);
});

test('带版本号的鸿蒙更新公告可以打开更新弹窗', () => {
  assert.equal(isUpdateNotice({ title: '鸿蒙新版本 1.0.5', context: '请下载最新安装包', platform: 'harmony' }), true);
  assert.equal(isUpdateNotice({ title: '版本更新', versionName: '1.0.5' }), true);
});
