// AI 问答：对话列表贴顶、用户消息有气泡、发送后清空输入框，AI 回答带标识。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const page = () => readFile(new URL('../entry/src/main/ets/pages/ai/AIAssistantPage.ets', import.meta.url), 'utf8');

test('AI 回答前有生成标识，页面有免责声明', async () => {
  const source = await page();
  assert.match(source, /Text\('【AI生成】'\)/, '缺少【AI生成】标识');
  assert.match(source, /以下内容由AI生成，可能存在错误，仅供参考。/, '缺少底部 AI 生成提示');
  assert.match(source, /aiBubble\(message\.text\)/, '缺少 AI 回答气泡');
});

test('对话用 List 贴顶，用户消息有气泡且发送后清空输入框', async () => {
  const source = await page();
  assert.match(source, /List\(\{ scroller: this\.listScroller \}\)/, '对话没有用 List 贴顶排列');
  assert.match(source, /userBubble\(message\.text\)/, '用户消息没有气泡');
  assert.match(source, /this\.messages = this\.messages\.concat\(\[\{ role: 'user', text: q \}\]\);/, '没有记录用户消息');
  assert.match(source, /this\.question = '';/, '发送后没有清空输入框');
});
