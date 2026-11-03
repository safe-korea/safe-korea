import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';

function client({ cold = false, expired = false } = {}) {
  const nodes = new Map(), calls = [], listeners = {};
  const node = id => {
    if (!nodes.has(id)) nodes.set(id, {
      id, value: '', dataset: {}, open: false,
      replaceChildren() {}, add() {}, addEventListener() {},
      showModal() { this.open = true; }, close() { this.open = false; },
    });
    return nodes.get(id);
  };
  const window = { safeKorPushReceiver() {} };
  const credential = { id: 'device', capability: 'private-fixture', region: '11' };
  const id = '11111111-1111-4111-8111-111111111111';
  const location = new URL('https://app.test/app/' + (cold ? '?notice=' + id : ''));
  vm.runInNewContext(readFileSync(new URL('../../../web/push-client.js', import.meta.url), 'utf8'), {
    window, location, URL, Option: function () {},
    document: { getElementById: node, baseURI: location.href, addEventListener() {} },
    history: { replaceState() {} },
    localStorage: { getItem: key => key.endsWith('registration.v1') ? JSON.stringify(credential) : 'decided' },
    navigator: { vendor: '', userAgent: '', serviceWorker: { addEventListener: (name, fn) => listeners[name] = fn } },
    matchMedia: () => ({ matches: true }), isSecureContext: true,
    clearInterval() {}, queueMicrotask() {},
    fetch: async (url, options) => {
      const path = url.pathname.split('/').pop();
      const body = options.body ? JSON.parse(options.body) : null;
      calls.push({ path, body });
      const value = path === 'config' ? { regions: [{ code: '11', name: '서울특별시' }] }
        : path === 'status' ? { lastTest: { received_at: 1, opened_at: null } }
        : expired ? { error: 'notice_expired' } : { type: 'test' };
      return { ok: !(path === 'notice' && expired), json: async () => value };
    },
  });
  return { window, nodes, calls, id, send(activation) {
    listeners.message({ source: { scriptURL: 'https://app.test/app/safe-worker.js' }, data: { type: 'SAFEKOR_OPEN_NOTICE', deliveryId: id, activation } });
  } };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('foreground receipt and actual notification click produce distinct status and requests', async () => {
  const c = client();
  c.send('foreground'); await settle();
  assert.equal(c.calls.find(x => x.path === 'notice').body.openedFromNotification, false);
  assert.match(c.nodes.get('push-status').textContent, /알림센터에서 알림을 눌러/);
  c.send('notificationclick'); await settle();
  assert.equal(c.calls.filter(x => x.path === 'notice').at(-1).body.openedFromNotification, true);
  assert.match(c.nodes.get('push-status').textContent, /수신·열기 확인 완료/);
  assert.equal(c.nodes.get('push-region').value, '11');
});

test('cold notification launch preserves activation while initializing notification settings', async () => {
  const c = client({ cold: true }); c.window.safeKorPushReady(); await settle();
  assert.equal(c.calls.find(x => x.path === 'notice').body.openedFromNotification, true);
  assert.equal(c.nodes.get('push-region').value, '11');
  assert.match(c.nodes.get('push-status').textContent, /수신·열기 확인 완료/);
});

test('expired notification keeps expiry warning but restores saved region controls', async () => {
  const c = client({ expired: true }); c.send('notificationclick'); await settle();
  assert.equal(c.nodes.get('push-region').value, '11');
  assert.match(c.nodes.get('push-status').textContent, /지난 알림/);
  assert.equal(c.nodes.get('push-status').dataset.state, 'error');
});
