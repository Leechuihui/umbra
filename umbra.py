#!/usr/bin/env python3

# Copyright (C) 2026 leechuihui
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE in the repository root.

#⠀ ⠀⠀⠀⠀⠀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
#⠀ ⠀⠀⣠⣶⡿⠿⠛⠿⣷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
#⠀ ⠀⣰⣿⠋⠀⠀⠀⠀⠀⠹⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
#⠀ ⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⢿⣷⣦⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
#⠀ ⠀⠹⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠻⣷⣦⡀⠀⠀⠀⠀⠀  ~ UMBRA
#⠀ ⠀⠀⠙⣿⣷⣶⣤⠤⠀⠀⠀⠀⣴⣶⣄⠈⠻⣿⣆⠀⠀⠀⠀  Post exploitation framework  
#⠀ ⠀⣠⣾⣿⣃⣀⣀⠀⠀⠀⠀⠀⠙⠛⠛⠂⠀⠈⢿⣧⠀⠀⠀⠀⠀
#⠀ ⠚⠛⢛⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣤⣾⡿⠀⠀⠀⠀⠀
#⠀ ⢀⣴⣿⣿⣷⣶⣶⣶⠆⢀⣾⣿⡿⠿⠿⠛⠛⠋⠁⠀⠀⠀⠀⠀⠀
#⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⣴⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
#⠀ ⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀

import os
import re
import subprocess
import sys
from pathlib import Path

# VARIABLES ======================================================================================

root = Path(__file__).resolve().parent
umbra_cmd = Path(sys.argv[0]).name

server_root = root / "server"
client_root = root / "client" / "gui"

umbra_help = f"""USAGE:
    {umbra_cmd} <mode> <command> ...

MODES
    server                             Server mode
    client                             Client mode

COMMANDS
    help                               Show this help message
    version                            Show version of the server and client

    server start                       Start server
    client start                       Start client

    server config list                 List server config
    server config set <key> <value>    Set server config
    server config reset <key>          Reset server config to default
    server config load <file>          Load server config from file
    server config create-tls           Create a self signed cert and enable TLS

    server key list                    List operators keys
    server key add john                Create operator key
    server key rem john                Remove operator key

    server venv list                   List installed python packages
    server venv install <package>      Install a python package
    server venv uninstall <package>    Uninstall a python package
    
    server db usage                    Show database information
    server db export <path>            Export database to a file
    server db import <file>            Import database from a file
"""

# FUNCTIONS ======================================================================================


def is_root():
    if os.name == "nt":
        return False
    return os.geteuid() == 0


def has_libfuse2():
    """True when the AppImage runtime can mount itself (needs libfuse2).

    Kali and other modern distros only ship libfuse3, so the AppImage must be
    extracted before it can run. Checked via ldconfig, then by probing the
    usual library paths.
    """
    if os.name == "nt":
        return True
    try:
        out = subprocess.run(
            ["ldconfig", "-p"],
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout
        if "libfuse.so.2" in out:
            return True
    except (OSError, subprocess.SubprocessError):
        pass

    for path in (
        "/usr/lib/x86_64-linux-gnu/libfuse.so.2",
        "/usr/lib/aarch64-linux-gnu/libfuse.so.2",
        "/usr/lib64/libfuse.so.2",
        "/usr/lib/libfuse.so.2",
        "/lib/x86_64-linux-gnu/libfuse.so.2",
    ):
        if os.path.exists(path):
            return True
    return False


def client():
    if os.name == "nt":
        if not (client_root / "dist" / "win-unpacked" / "umbra.exe").is_file():
            print(f"[ \x1b[38;2;255;48;48mERROR\x1b[0m ] Client executable not found: {client_root / 'dist' / 'win-unpacked' / 'umbra.exe'}", file=sys.stderr)
            sys.exit(1)
        os.execv(str(client_root / "dist" / "win-unpacked" / "umbra.exe"), [str(client_root / "dist" / "win-unpacked" / "umbra.exe")])

    if sys.platform == "darwin":
        app = client_root / "dist" / "mac" / "umbra.app" / "Contents" / "MacOS" / "umbra"
        if not app.is_file():
            app = client_root / "dist" / "mac-arm64" / "umbra.app" / "Contents" / "MacOS" / "umbra"
        if not app.is_file():
            print(f"[ \x1b[38;2;255;48;48mERROR\x1b[0m ] Client app not found: {client_root / 'dist' / 'mac' / 'umbra.app'}", file=sys.stderr)
            sys.exit(1)
        os.execv(str(app), [str(app)])

    gui = Path("/usr/local/bin/umbra-gui")
    if os.access(gui, os.X_OK):
        os.execv(gui, [str(gui)])

    if not os.access(client_root / "dist" / "umbra.AppImage", os.X_OK):
        print(f"[ \x1b[38;2;255;48;48mERROR\x1b[0m ] Client AppImage not found: {client_root / 'dist' / 'umbra.AppImage'}", file=sys.stderr)
        sys.exit(1)

    # Fix display for root user
    env = os.environ.copy()
    if is_root():
        env["DISPLAY"] = env.get("DISPLAY") or ":0"
        sudo_user = env.get("SUDO_USER", "")
        if sudo_user:
            env["XAUTHORITY"] = f"/home/{sudo_user}/.Xauthority"

    # Start
    appimage = client_root / "dist" / "umbra.AppImage"
    argv = [str(appimage)]
    if is_root():
        argv.append("--no-sandbox")

    # Kali and other modern distros ship libfuse3 only. The AppImage runtime
    # needs libfuse2, so fall back to extracting before running.
    if not has_libfuse2():
        print("[ info ] libfuse2 not found; using --appimage-extract-and-run")
        argv.insert(1, "--appimage-extract-and-run")

    os.execve(str(appimage), argv, env)


def server(argv):
    # Validations
    if not server_root.is_dir():
        print(f"[ \x1b[38;2;255;48;48mERROR\x1b[0m ] Server dir not found: {server_root}", file=sys.stderr)
        sys.exit(1)

    venv_python = server_root / "venv" / "bin" / "python3"

    if not os.access(venv_python, os.X_OK):
        print(f"[ \x1b[38;2;255;48;48mERROR\x1b[0m ] Venv python not found: {venv_python}", file=sys.stderr)
        sys.exit(1)

    env = os.environ.copy()
    env["PYTHONPATH"] = f"{server_root}:{server_root / 'core'}"

    # Start
    main_py = server_root / "main.py"
    os.execve(
        str(venv_python),
        [str(venv_python), str(main_py), *argv],
        env,
    )


def version():
    sv = ""
    cv = ""
    version_py = server_root / "version.py"
    if version_py.is_file():
        for line in version_py.read_text().splitlines():
            m = re.match(r'^\s*__version__\s*=\s*"([^"]*)"', line)
            if m:
                sv = m.group(1)
                break
    package_json = client_root / "package.json"
    if package_json.is_file():
        for line in package_json.read_text().splitlines():
            m = re.search(r'.*"version"\s*:\s*"([^"]*)"', line)
            if m:
                cv = m.group(1)
                break
    if not sv:
        sv = "unknown"
    if not cv:
        cv = "unknown"
    print(f"client\t{cv}")
    print(f"server\t{sv}")


# MAIN LOGIC =====================================================================================


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    args_spaced = f" {' '.join(args)} " if args else " "

    if len(args) == 0 or " help " in args_spaced:
        print(umbra_help)
        return 0

    if len(args) >= 2 and args[0] == "client" and args[1] == "start":
        if is_root():
            print("[ \x1b[38;2;255;48;48mERROR\x1b[0m ] The client must not be executed with sudo", file=sys.stderr)
            return 1
        client()
        return 0

    if len(args) >= 1 and args[0] == "server":
        if is_root():
            print("[ \x1b[38;2;255;48;48mERROR\x1b[0m ] The server must not be executed with sudo", file=sys.stderr)
            return 1
        server(args[1:])
        return 0

    if len(args) >= 1 and args[0] == "version":
        version()
        return 0

    print(umbra_help, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
