// AI 问答：每条回答前必须有【AI生成】标识，底部有免责声明。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const page = () => readFile(new URL('../entry/src/main/ets/pages/ai/AIAssistantPage.ets', import.meta.url), 'utf8');

test('AI 回答前有生成标识，页面有免责声明', async () => {
  const source = await page();
  assert.match(source, /Text\('【AI生成】'\)/, '缺少【AI生成】标识');
  assert.match(source, /以下内容由AI生成，可能存在错误，仅供参考。/, '缺少底部 AI 生成提示');
  assert.match(source, /Text\(this\.answer\)/, '缺少回答正文');
});
