// 登录错误弹窗排版：提示文案不能带制表符/手动换行，否则鸿蒙上文字会错位换行。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const login = () => readFile(new URL('../entry/src/main/ets/pages/login/LoginPage.ets', import.meta.url), 'utf8');

test('错误提示文案没有制表符和硬换行', async () => {
  const page = await login();
  assert.doesNotMatch(page, /\\t\\t\\t\\t\\t/, '文案仍有制表符缩进');
  assert.match(page, /'该账号已三次登录"武科大助手"密码错误，您可以去帮助中心寻求帮助，也可联系相关管理员为您解决。'/,
    '三次错误文案不是单行');
  assert.match(page, /'该账号已五次或以上登录"武科大助手"密码错误，您可以去新版教务处官网查验此账号是否被锁定。'/,
    '锁定文案不是单行');
});

test('弹窗正文按正常段落排版', async () => {
  const page = await login();
  assert.match(page, /\.textAlign\(TextAlign\.Start\)/, '正文没有显式左对齐');
  assert.match(page, /\.lineHeight\(22\)/, '正文行高没有统一');
});
