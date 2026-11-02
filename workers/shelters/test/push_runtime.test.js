import test from "node:test";
import assert from "node:assert/strict";
import { build } from "esbuild";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";
import { encode64 } from "../src/web_push.ts";

test("real Workers runtime encrypts and sends Apple request, reads official data, and rejects redirects without forwarding credentials", async () => {
  const bundled = await build({
    stdin: {
      contents: `
 import {sendApplePush} from './src/web_push.ts';
 import {fetchOfficial} from './src/official_alerts.ts';
 export default {async fetch(request){const data=await request.json();const status=await sendApplePush(data.subscription,{type:'test',body:'QA synthetic only'},data.vapid,60,'qa');const source=await fetchOfficial('synthetic-test-key',Date.now());return Response.json({status,state:source.state,complete:source.complete});}};
 `,
      resolveDir: process.cwd(),
    },
    bundle: true,
    format: "esm",
    platform: "browser",
    target: "es2022",
    write: false,
  });
  let apple = 0,
    official = 0,
    redirect = false;
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      workers: [
        {
          name: "qa-push",
          modules: true,
          script: bundled.outputFiles[0].text,
          compatibilityDate: "2026-10-01",
          outboundService: async (request) => {
            const url = new URL(request.url);
            if (url.hostname === "web.push.apple.com") {
              apple++;
              assert.equal(
                request.headers.get("content-encoding"),
                "aes128gcm",
              );
              assert.match(request.headers.get("authorization"), /^vapid t=/);
              assert.equal((await request.arrayBuffer()).byteLength, 4096);
              return new Response(null, { status: 201 });
            }
            assert.equal(url.hostname, "www.safetydata.go.kr");
            official++;
            if (redirect)
              return Response.redirect("https://untrusted.example/", 302);
            return Response.json({
              header: { resultCode: "00" },
              totalCount: 0,
              body: [],
            });
          },
        },
      ],
    }),
  );
  try {
    const pair = await crypto.subtle.generateKey(
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["sign", "verify"],
    );
    const jwk = await crypto.subtle.exportKey("jwk", pair.privateKey);
    const ecdh = await crypto.subtle.generateKey(
      { name: "ECDH", namedCurve: "P-256" },
      true,
      ["deriveBits"],
    );
    const data = {
      vapid: {
        publicKey: encode64(
          new Uint8Array(await crypto.subtle.exportKey("raw", pair.publicKey)),
        ),
        privateKey: jwk.d,
        subject: "mailto:qa@example.test",
      },
      subscription: {
        endpoint: "https://web.push.apple.com/synthetic-runtime-only",
        expirationTime: null,
        keys: {
          p256dh: encode64(
            new Uint8Array(
              await crypto.subtle.exportKey("raw", ecdh.publicKey),
            ),
          ),
          auth: encode64(crypto.getRandomValues(new Uint8Array(16))),
        },
      },
    };
    const send = () =>
      mf.dispatchFetch("https://local.test/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
    const response = await send();
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      status: 201,
      state: "source_observed",
      complete: true,
    });
    assert.equal(apple, 1);
    assert.equal(official, 1);
    redirect = true;
    const rejected = await (await send()).json();
    assert.equal(rejected.state, "source_redirect_rejected");
    assert.equal(official, 2);
    assert.equal(apple, 2);
  } finally {
    await mf.dispose();
  }
});
