#!/usr/bin/env python3
"""Fill the Add Server form on the UMBRA client and click Auth.

Reads the operator key from disk, injects it into the renderer through the
DevTools protocol, fills host/port, then clicks the Auth button. Every step
is verified by reading the DOM back.
"""

import json
import sys
import time
import urllib.request

from websocket import create_connection

PORT = 9222
BASE = f"http://127.0.0.1:{PORT}"
KEY_FILE = "/home/myroot/umbra/admin.key"


def list_targets():
    with urllib.request.urlopen(f"{BASE}/json/list", timeout=5) as r:
        return json.load(r)


def pick_page(targets):
    for t in targets:
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl"):
            return t
    return None


class CDP:
    def __init__(self, url):
        self.ws = create_connection(url, timeout=30)
        self.i = 0

    def send(self, method, params=None):
        self.i += 1
        mid = self.i
        payload = {"id": mid, "method": method}
        if params:
            payload["params"] = params
        self.ws.send(json.dumps(payload))
        while True:
            raw = self.ws.recv()
            if not raw:
                raise RuntimeError("websocket closed")
            data = json.loads(raw)
            if data.get("id") == mid:
                return data

    def js(self, expr):
        r = self.send(
            "Runtime.evaluate",
            {
                "expression": expr,
                "returnByValue": True,
                "awaitPromise": True,
                "userGesture": True,
            },
        )
        res = r.get("result", {})
        if "exceptionDetails" in res:
            d = res["exceptionDetails"]
            return {"__error": d.get("exception", {}).get("description") or d.get("text")}
        return res.get("result", {}).get("value")

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


SET_FIELD = """
(() => {
  const idx = %d;
  const val = %s;
  const els = Array.from(document.querySelectorAll('input, textarea'));
  const el = els[idx];
  if (!el) return {error: 'no element at index ' + idx};
  const proto = el.tagName === 'TEXTAREA'
    ? window.HTMLTextAreaElement.prototype
    : window.HTMLInputElement.prototype;
  const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
  setter.call(el, val);
  el.dispatchEvent(new Event('input', {bubbles: true}));
  el.dispatchEvent(new Event('change', {bubbles: true}));
  return {ok: true, tag: el.tagName, len: el.value.length, ph: el.placeholder || ''};
})()
"""

CLICK_BUTTON = """
(() => {
  const want = %s;
  const el = Array.from(document.querySelectorAll('button'))
    .find((b) => (b.textContent || '').trim() === want);
  if (!el) return {error: 'button not found: ' + want};
  const r = el.getBoundingClientRect();
  const cx = Math.round(r.x + r.width / 2);
  const cy = Math.round(r.y + r.height / 2);
  const mk = (type, Ctor, extra) => el.dispatchEvent(new Ctor(type, Object.assign({
    bubbles: true, cancelable: true, composed: true,
    clientX: cx, clientY: cy,
  }, extra)));
  mk('pointerover', PointerEvent, {pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0, buttons: 0});
  mk('pointerdown', PointerEvent, {pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0, buttons: 1});
  mk('mousedown', MouseEvent, {button: 0, buttons: 1});
  mk('pointerup', PointerEvent, {pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0, buttons: 0});
  mk('mouseup', MouseEvent, {button: 0, buttons: 0});
  el.click();
  return {ok: true, disabled: el.disabled, rect: {x: cx, y: cy}};
})()
"""

DESCRIBE = """
(() => Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({
  i, tag: el.tagName, type: el.type || '',
  ph: el.placeholder || '', val: (el.value || '').slice(0, 24),
})))()
"""


def main():
    try:
        with open(KEY_FILE, encoding="utf-8") as f:
            key_line = f.readline().strip()
    except OSError as e:
        print(f"cannot read {KEY_FILE}: {e}")
        return 1

    if not key_line or key_line.count(":") < 2:
        print(f"key file does not look like user:pass:secret -> {key_line[:40]!r}")
        return 1

    parts = key_line.split(":")
    print(f"key loaded: user={parts[0]} pass_len={len(parts[1])} secret_len={len(parts[2])}")

    page = pick_page(list_targets())
    if not page:
        print("no page target")
        return 1

    cdp = CDP(page["webSocketDebuggerUrl"])
    try:
        print("\n=== 1. current form fields ===")
        print(json.dumps(cdp.js(DESCRIBE), indent=2, ensure_ascii=False))

        print("\n=== 2. fill the key textarea (index 1) ===")
        print(cdp.js(SET_FIELD % (1, json.dumps(key_line))))

        print("\n=== 3. fill host (index 2) ===")
        print(cdp.js(SET_FIELD % (2, json.dumps("127.0.0.1"))))

        print("\n=== 4. fill port (index 3) ===")
        print(cdp.js(SET_FIELD % (3, json.dumps("9000"))))

        time.sleep(0.5)

        print("\n=== 5. fields after filling ===")
        print(json.dumps(cdp.js(DESCRIBE), indent=2, ensure_ascii=False))

        print("\n=== 6. click Auth ===")
        res = cdp.js(CLICK_BUTTON % json.dumps("认证"))
        print(res)

        if isinstance(res, dict) and res.get("disabled"):
            print("  Auth button is disabled - the form is not considered valid")
            return 1

        print("\n=== 7. wait for the auth round-trip ===")
        for attempt in range(1, 11):
            time.sleep(1)
            body = cdp.js("document.body.innerText")
            if isinstance(body, str):
                if "认证成功" in body or "Authenticated" in body:
                    print(f"  success message seen after {attempt}s")
                    break
                if "失败" in body or "Failed" in body or "Invalid" in body:
                    print(f"  failure message after {attempt}s")
                    break
            print(f"  ...{attempt}s")

        print("\n=== 8. final panel state ===")
        body = cdp.js("document.body.innerText")
        print(body[:900] if isinstance(body, str) else body)

        print("\n=== 9. buttons now ===")
        btns = cdp.js(
            "Array.from(document.querySelectorAll('button')).map(b => (b.textContent||'').trim()).filter(Boolean)"
        )
        print(btns)

        return 0
    finally:
        cdp.close()


if __name__ == "__main__":
    sys.exit(main())
