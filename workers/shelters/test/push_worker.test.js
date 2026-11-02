import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import { readFileSync } from "node:fs";
function worker() {
  const listeners = {},
    notifications = [],
    opened = [],
    messages = [],
    receipts = [];
  let windows = [];
  const scope = "https://app.test/app/";
  const self = {
    location: { origin: "https://app.test" },
    registration: {
      scope,
      showNotification: async (title, options) =>
        notifications.push({ title, options }),
    },
    addEventListener: (name, fn) => (listeners[name] = fn),
    clients: {
      matchAll: async () => windows,
      openWindow: async (url) => opened.push(url),
    },
  };
  vm.runInNewContext(
    readFileSync(
      new URL("../../../web/safe-worker.template.js", import.meta.url),
      "utf8",
    )
      .replace("__VERSION__", "unit")
      .replace("__FILES__", "{}"),
    {
      self,
      URL,
      Request,
      Response,
      Date,
      fetch: async (url, options) => {
        receipts.push({ url: String(url), options });
        return new Response("{}");
      },
      Uint8Array,
      crypto,
    },
  );
  return {
    self,
    notifications,
    opened,
    messages,
    receipts,
    setWindows(value) {
      windows = value;
    },
    async send(name, fields) {
      let promise;
      listeners[name]({ ...fields, waitUntil: (p) => (promise = p) });
      await promise;
    },
  };
}
const id = "11111111-1111-4111-8111-111111111111";
test("push always displays, reports only valid receipts, and relays to visible app", async () => {
  const w = worker();
  w.setWindows([
    {
      url: "https://app.test/app/",
      visibilityState: "visible",
      postMessage: (d) => w.messages.push(d),
    },
  ]);
  await w.send("push", {
    data: {
      json: () => ({
        protocolVersion: 1,
        type: "test",
        deliveryId: id,
        receiptToken: "a".repeat(43),
        expiresAt: Date.now() + 120000,
      }),
    },
  });
  assert.match(w.notifications[0].title, /테스트/);
  assert.match(w.notifications[0].options.body, /실제 경보가 아닙니다/);
  assert.equal(w.receipts.length, 1);
  assert.equal(w.receipts[0].url, "https://app.test/api/push/receipt");
  assert.equal(w.messages[0].deliveryId, id);
  await w.send("push", {
    data: {
      json: () => ({
        protocolVersion: 1,
        type: "civil",
        deliveryId: id,
        expiresAt: Date.now() - 1000,
        url: "https://evil.test",
      }),
    },
  });
  assert.match(w.notifications[1].options.body, /지난 알림/);
  assert.equal(w.receipts.length, 1);
  assert.equal(w.messages.length, 1);
  await w.send("push", {
    data: {
      json: () => {
        throw Error("malformed");
      },
    },
  });
  assert.equal(w.notifications.length, 3);
});
test("notification click focuses only own app or opens fixed app URL; payload URL is ignored", async () => {
  const w = worker();
  let closed = 0;
  await w.send("notificationclick", {
    notification: {
      data: { deliveryId: id, url: "https://evil.test" },
      close: () => closed++,
    },
  });
  assert.equal(w.opened[0], "https://app.test/app/?notice=" + id);
  let focused = 0;
  w.setWindows([
    {
      url: "https://evil.test/app/",
      focus: async () => {
        throw Error("foreign window");
      },
    },
    {
      url: "https://app.test/app/",
      focus: async () => focused++,
      postMessage: (d) => w.messages.push(d),
    },
  ]);
  await w.send("notificationclick", {
    notification: { data: { deliveryId: id }, close: () => closed++ },
  });
  assert.equal(focused, 1);
  assert.equal(w.messages[0].deliveryId, id);
  assert.equal(w.opened.length, 1);
  assert.equal(closed, 2);
});
