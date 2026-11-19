#!/usr/bin/env python3
"""Drive the UMBRA renderer through the Chrome DevTools Protocol.

Uses real (trusted) mouse and keyboard events so Radix menus and React
controlled inputs behave exactly as if a person were clicking.

Usage:
    gui_driver.py <flow>

Flows are defined in FLOWS below. Every step logs what it did so the run can
be verified without looking at the screen.
"""

import json
import subprocess
import sys
import time
import urllib.request

try:
    from websocket import create_connection
except ImportError:
    print("missing websocket-client", file=sys.stderr)
    sys.exit(2)

PORT = 9222
BASE = f"http://127.0.0.1:{PORT}"


# --------------------------------------------------------------------------
# CDP plumbing
# --------------------------------------------------------------------------


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

    def key(self, key, code, keycode):
        base = {
            "key": key,
            "code": code,
            "windowsVirtualKeyCode": keycode,
            "nativeVirtualKeyCode": keycode,
        }
        self.send("Input.dispatchKeyEvent", {**base, "type": "rawKeyDown"})
        self.send("Input.dispatchKeyEvent", {**base, "type": "keyUp"})

    def escape(self):
        self.key("Escape", "Escape", 27)

    def click(self, x, y):
        self.send(
            "Input.dispatchMouseEvent",
            {"type": "mouseMoved", "x": x, "y": y, "button": "none"},
        )
        self.send(
            "Input.dispatchMouseEvent",
            {
                "type": "mousePressed",
                "x": x,
                "y": y,
                "button": "left",
                "buttons": 1,
                "clickCount": 1,
            },
        )
        time.sleep(0.05)
        self.send(
            "Input.dispatchMouseEvent",
            {
                "type": "mouseReleased",
                "x": x,
                "y": y,
                "button": "left",
                "buttons": 0,
                "clickCount": 1,
            },
        )

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


# --------------------------------------------------------------------------
# DOM helpers (run inside the page)
# --------------------------------------------------------------------------


def js_find_center(text, exact=True, tags=None):
    """Return {x, y, tag, text} for the first visible element matching text."""
    tag_filter = ""
    if tags:
        tag_filter = ",".join(tags)
    else:
        tag_filter = "button,[role='menuitem'],div,span,a,li"

    return (
        "(() => {"
        f"  const want = {json.dumps(text)};"
        f"  const exact = {str(exact).lower()};"
        f"  const els = Array.from(document.querySelectorAll({json.dumps(tag_filter)}));"
        "  for (const el of els) {"
        "    const t = (el.textContent || '').trim();"
        "    const hit = exact ? (t === want) : t.includes(want);"
        "    if (!hit) continue;"
        "    const r = el.getBoundingClientRect();"
        "    if (r.width < 2 || r.height < 2) continue;"
        "    const st = getComputedStyle(el);"
        "    if (st.visibility === 'hidden' || st.display === 'none' || st.pointerEvents === 'none') continue;"
        "    return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2),"
        "            tag: el.tagName, text: t.slice(0,40),"
        "            w: Math.round(r.width), h: Math.round(r.height)};"
        "  }"
        "  return null;"
        "})()"
    )


def js_body_text(limit=400):
    return f"document.body.innerText.slice(0,{limit})"


def js_list_menu_items():
    return (
        "(() => Array.from(document.querySelectorAll('[role=\"menuitem\"], [role=\"menu\"] div'))"
        ".map(el => (el.textContent||'').trim())"
        ".filter(t => t && t.length < 30)"
        ".slice(0, 30))()"
    )


def js_set_input(selector_index, value):
    """Set a React-controlled input/textarea by index and fire input events."""
    return (
        "(() => {"
        "  const els = Array.from(document.querySelectorAll('input, textarea'));"
        f"  const el = els[{selector_index}];"
        "  if (!el) return {error: 'no element at index'};"
        f"  const val = {json.dumps(value)};"
        "  const proto = el.tagName === 'TEXTAREA'"
        "    ? window.HTMLTextAreaElement.prototype"
        "    : window.HTMLInputElement.prototype;"
        "  const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;"
        "  setter.call(el, val);"
        "  el.dispatchEvent(new Event('input', {bubbles: true}));"
        "  el.dispatchEvent(new Event('change', {bubbles: true}));"
        "  return {ok: true, tag: el.tagName, len: el.value.length,"
        "          ph: el.placeholder || ''};"
        "})()"
    )


def js_describe_inputs():
    return (
        "(() => Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({"
        "  i, tag: el.tagName, type: el.type || '',"
        "  ph: el.placeholder || '', val: (el.value || '').slice(0, 24)"
        "})))()"
    )


# --------------------------------------------------------------------------
# Flow steps
# --------------------------------------------------------------------------


class Runner:
    def __init__(self, cdp):
        self.cdp = cdp
        self.log = []

    def note(self, msg):
        self.log.append(msg)
        print(f"  {msg}")

    def shot(self, name):
        path = f"/tmp/gui-{name}.png"
        try:
            subprocess.run(
                ["import", "-window", "root", path],
                check=False,
                capture_output=True,
                timeout=15,
                env={"DISPLAY": ":0", "XAUTHORITY": "/home/myroot/.Xauthority", "PATH": "/usr/bin:/bin"},
            )
            self.note(f"screenshot -> {path}")
        except Exception as e:
            self.note(f"screenshot failed: {e}")

    def click_text(self, text, exact=True, tags=None, label=None):
        info = self.cdp.js(js_find_center(text, exact=exact, tags=tags))
        if not info or info.get("__error"):
            self.note(f"NOT FOUND: {label or text}  ({info})")
            return False
        self.cdp.click(info["x"], info["y"])
        self.note(f"clicked {label or text} at ({info['x']},{info['y']}) tag={info['tag']}")
        return True

    def body(self, limit=300):
        t = self.cdp.js(js_body_text(limit))
        return t if isinstance(t, str) else str(t)


def flow_open_server_form(cdp):
    r = Runner(cdp)

    print("=== step 1: close the command palette ===")
    r.note(f"before: {r.body(120)!r}")
    cdp.escape()
    time.sleep(0.6)
    after = r.body(120)
    r.note(f"after escape: {after!r}")
    if "命令面板" in after:
        r.note("palette still open, clicking outside")
        cdp.click(20, 700)
        time.sleep(0.6)
        r.note(f"after outside click: {r.body(120)!r}")

    print()
    print("=== step 2: open the UMBRA menu ===")
    ok = r.click_text("UMBRA", exact=True, tags=["div"], label="UMBRA menu")
    if not ok:
        # fall back to the aria-haspopup trigger
        info = cdp.js(
            "(() => {"
            "  const els = Array.from(document.querySelectorAll('[aria-haspopup=\"menu\"]'));"
            "  const el = els.find(e => (e.textContent||'').trim() === 'UMBRA');"
            "  if (!el) return null;"
            "  const r = el.getBoundingClientRect();"
            "  return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)};"
            "})()"
        )
        if info:
            cdp.click(info["x"], info["y"])
            r.note(f"clicked UMBRA trigger at ({info['x']},{info['y']})")
        else:
            r.note("could not find the UMBRA menu trigger")
            return r

    time.sleep(0.8)
    items = cdp.js(js_list_menu_items())
    r.note(f"menu items: {items}")
    r.shot("menu-open")

    print()
    print("=== step 3: click Servers ===")
    clicked = False
    for label in ("服务器", "Servers", "服务器管理"):
        if r.click_text(label, exact=False, tags=["[role='menuitem']", "div"], label=label):
            clicked = True
            break
    if not clicked:
        r.note("Servers item not found in the menu")
        return r

    time.sleep(1.0)
    r.note(f"panel body: {r.body(300)!r}")
    r.shot("servers-panel")

    print()
    print("=== step 4: click Add ===")
    for label in ("添加", "Add", "新建"):
        if r.click_text(label, exact=True, tags=["button"], label=label):
            break
    time.sleep(1.0)
    r.note(f"form body: {r.body(400)!r}")
    inputs = cdp.js(js_describe_inputs())
    r.note(f"inputs: {inputs}")
    r.shot("server-form")

    return r


def flow_fill_and_auth(cdp, key_line):
    r = Runner(cdp)

    print("=== step 1: describe the form ===")
    inputs = cdp.js(js_describe_inputs())
    r.note(f"inputs: {inputs}")
    if not isinstance(inputs, list) or not inputs:
        r.note("no inputs found - is the Add Server form open?")
        return r

    print()
    print("=== step 2: fill the key textarea ===")
    # The key textarea is the first textarea in the form.
    idx = None
    for item in inputs:
        if item.get("tag") == "TEXTAREA":
            idx = item["i"]
            break
    if idx is None:
        r.note("no textarea found for the key")
        return r
    res = cdp.js(js_set_input(idx, key_line))
    r.note(f"key textarea [{idx}]: {res}")

    print()
    print("=== step 3: fill host and port ===")
    inputs = cdp.js(js_describe_inputs())
    host_idx = port_idx = None
    for item in inputs:
        if item.get("tag") != "INPUT":
            continue
        ph = item.get("ph") or ""
        if ph == "127.0.0.1":
            host_idx = item["i"]
        elif ph == "9000":
            port_idx = item["i"]

    if host_idx is not None:
        r.note(f"host [{host_idx}]: {cdp.js(js_set_input(host_idx, '127.0.0.1'))}")
    else:
        r.note("host input not found by placeholder")

    if port_idx is not None:
        r.note(f"port [{port_idx}]: {cdp.js(js_set_input(port_idx, '9000'))}")
    else:
        r.note("port input not found by placeholder")

    time.sleep(0.4)
    r.note(f"inputs now: {cdp.js(js_describe_inputs())}")
    r.shot("form-filled")

    print()
    print("=== step 4: click Auth ===")
    clicked = False
    for label in ("认证", "Auth", "Authenticate"):
        if r.click_text(label, exact=True, tags=["button"], label=label):
            clicked = True
            break
    if not clicked:
        r.note("Auth button not found")
        return r

    time.sleep(3.0)
    r.note(f"after auth: {r.body(400)!r}")
    r.shot("after-auth")

    return r


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    flow = sys.argv[1]

    targets = list_targets()
    page = pick_page(targets)
    if not page:
        print("no page target", file=sys.stderr)
        return 1

    cdp = CDP(page["webSocketDebuggerUrl"])
    try:
        if flow == "open-server-form":
            r = flow_open_server_form(cdp)
        elif flow == "fill-and-auth":
            if len(sys.argv) < 3:
                print("fill-and-auth needs the key line", file=sys.stderr)
                return 1
            r = flow_fill_and_auth(cdp, sys.argv[2])
        elif flow == "inspect":
            print(cdp.js(js_body_text(800)))
            print()
            print(json.dumps(cdp.js(js_describe_inputs()), indent=2, ensure_ascii=False))
            return 0
        else:
            print(f"unknown flow: {flow}", file=sys.stderr)
            return 1

        print()
        print("=== summary ===")
        print(f"  steps logged: {len(r.log)}")
        return 0
    finally:
        cdp.close()


if __name__ == "__main__":
    sys.exit(main())
