#!/usr/bin/env python3
"""Minimal Chrome DevTools Protocol driver for the UMBRA renderer.

Usage:
    cdp.py eval '<javascript>'
    cdp.py targets

Connects to the first page target on the local DevTools port and evaluates
JavaScript in it, printing the result. This lets the GUI be driven and
inspected without relying on screenshots.
"""

import json
import sys
import urllib.request

try:
    from websocket import create_connection
except ImportError:
    print("missing websocket-client (pip install websocket-client)", file=sys.stderr)
    sys.exit(2)

PORT = 9222
BASE = f"http://127.0.0.1:{PORT}"


def list_targets():
    with urllib.request.urlopen(f"{BASE}/json/list", timeout=5) as r:
        return json.load(r)


def pick_page(targets):
    for t in targets:
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl"):
            return t
    return None


class CDP:
    def __init__(self, ws_url):
        self.ws = create_connection(ws_url, timeout=20)
        self.next_id = 0

    def send(self, method, params=None):
        self.next_id += 1
        msg_id = self.next_id
        payload = {"id": msg_id, "method": method}
        if params:
            payload["params"] = params
        self.ws.send(json.dumps(payload))

        # Read until we get the reply for this id (skip events).
        while True:
            raw = self.ws.recv()
            if not raw:
                raise RuntimeError("websocket closed")
            data = json.loads(raw)
            if data.get("id") == msg_id:
                return data

    def eval(self, expression, await_promise=True):
        res = self.send(
            "Runtime.evaluate",
            {
                "expression": expression,
                "returnByValue": True,
                "awaitPromise": await_promise,
                "userGesture": True,
            },
        )
        result = res.get("result", {})
        if "exceptionDetails" in result:
            detail = result["exceptionDetails"]
            text = detail.get("exception", {}).get("description") or detail.get("text")
            return {"error": text}
        return result.get("result", {}).get("value")

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    cmd = sys.argv[1]

    targets = list_targets()
    if cmd == "targets":
        for t in targets:
            print(f"{t.get('type')}\t{t.get('title')}\t{t.get('url', '')[:70]}")
        return 0

    page = pick_page(targets)
    if not page:
        print("no page target found", file=sys.stderr)
        return 1

    cdp = CDP(page["webSocketDebuggerUrl"])
    try:
        if cmd in ("eval", "evalfile"):
            if len(sys.argv) < 3:
                print(f"{cmd} needs an argument", file=sys.stderr)
                return 1
            if cmd == "evalfile":
                with open(sys.argv[2], encoding="utf-8") as f:
                    expr = f.read()
            else:
                expr = sys.argv[2]
            value = cdp.eval(expr)
            if isinstance(value, (dict, list)):
                print(json.dumps(value, indent=2, ensure_ascii=False))
            else:
                print(value)
            return 0

        print(f"unknown command: {cmd}", file=sys.stderr)
        return 1
    finally:
        cdp.close()


if __name__ == "__main__":
    sys.exit(main())
