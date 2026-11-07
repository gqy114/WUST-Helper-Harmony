import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

async function makePage() {
  const source = await readFile(new URL('../entry/src/main/ets/pages/campus/SecondHandBookDetailPage.ets', import.meta.url), 'utf8');
  const names = ['contactParts', 'openSellerContact', 'copyContact', 'contactActionLabel', 'copyAndOpenContact', 'openReplyTo'];
  const methods = names.map((name) => {
    const found = source.match(new RegExp(`  private (?:async )?${name}\\([^\\n]*\\)(?:: [^\\n{]+)? \\{[\\s\\S]*?\\r?\\n  \\}`));
    assert.ok(found, `method ${name} missing`);
    return found[0];
  });
  const calls = [], toasts = [];
  const mock = { calls, toasts, failCopy: false, failOpen: false };
  const context = createContext({
    pasteboard: {
      MIMETYPE_TEXT_PLAIN: 'text/plain',
      createData: (type, value) => ({ type, value }),
      getSystemPasteboard: () => ({ setData: async (data) => { if (mock.failCopy) throw new Error('copy'); calls.push({ kind: 'copy', value: data.value }); } })
    },
    promptAction: { showToast: ({ message }) => toasts.push(message) },
    getContext: () => ({ startAbility: async (want) => { if (mock.failOpen) throw new Error('open'); calls.push({ kind: 'open', action: want.action, uri: want.uri }); } })
  });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestPage {\n${methods.join('\n')}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  Object.assign(page, { listing: {}, contactOpen: false, replyOpen: false, replyTargetName: '', replyTargetExcerpt: '' });
  return { page, mock };
}

test('missing contact opens the dialog and does not copy anything', async () => {
  const { page, mock } = await makePage();
  page.openSellerContact();
  assert.equal(page.contactOpen, true);
  await page.copyContact();
  assert.equal(mock.calls.length, 0);
});

test('QQ contact is copied before opening the app', async () => {
  const { page, mock } = await makePage();
  page.listing = { contact: 'QQ：123456' };
  assert.equal(page.contactActionLabel(), '复制并打开 QQ');
  await page.copyAndOpenContact();
  assert.equal(mock.calls[0].kind, 'copy');
  assert.equal(mock.calls[0].value, '123456');
  assert.equal(mock.calls[1].uri, 'mqq://');
});

test('phone contact opens the dialer after copying, without placing a call', async () => {
  const { page, mock } = await makePage();
  page.listing = { contact: '电话：123456' };
  await page.copyAndOpenContact();
  assert.equal(mock.calls[0].value, '123456');
  assert.equal(mock.calls[1].action, 'ohos.want.action.dial');
  assert.equal(mock.calls[1].uri, 'tel:123456');
});

test('copy failure does not open the other app; open failure preserves copied value', async () => {
  const { page, mock } = await makePage();
  page.listing = { contact: '微信：test-id' };
  mock.failCopy = true;
  await page.copyAndOpenContact();
  assert.equal(mock.calls.length, 0);
  mock.failCopy = false;
  mock.failOpen = true;
  await page.copyAndOpenContact();
  assert.equal(mock.calls[0].value, 'test-id');
  assert.match(mock.toasts.at(-1), /已复制/);
});

test('reply target uses a bounded excerpt while keeping the existing draft', async () => {
  const { page } = await makePage();
  page.replyText = '草稿';
  page.openReplyTo({ displayName: '小明', content: '长'.repeat(60) });
  assert.equal(page.replyOpen, true);
  assert.equal(page.replyText, '草稿');
  assert.equal(page.replyTargetName, '小明');
  assert.equal(page.replyTargetExcerpt, '长'.repeat(48) + '…');
});
