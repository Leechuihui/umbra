<p align="center">
  <a href="https://github.com/Leechuihui/umbra">
    <img src="client/gui/public/icon_256x256.png" height="96">
    <h3 style="font-size: 1.7rem;" align="center">UMBRA</h3>
  </a>
</p>

<p align="center">
  Post exploitation framework · 后渗透测试框架
</p>

<p align="center">
  <b>English</b> · <a href="README.zh-CN.md">简体中文</a>
</p>

---

## About / 简介

**UMBRA** is a post-exploitation framework for advanced Red Team operations, built around a modern Electron + React desktop client and a Python team server. It ships with a fully bilingual interface (English / 中文) that can be switched at runtime.

**UMBRA** 是一款面向高级红队行动的后渗透测试框架，由 Electron + React 桌面客户端与 Python 团队服务器组成，界面支持中英文实时切换。

> Original work by **leechuihui** · 本项目为 **leechuihui** 原创作品

---

## Highlights / 核心特性

| Feature | 说明 |
| --- | --- |
| **Bilingual UI** | 中英文界面实时切换，自动记忆语言偏好 |
| **Themes** | 4 套原创配色：暗影青 / 余烬橙 / 深渊蓝 / 单色 |
| **Dashboard** | 作战仪表盘：会话、监听器、服务器、高权限占比、系统分布 |
| **Notebook** | 作战笔记：本地持久化，支持搜索 |
| **Command Palette** | 命令面板：`Ctrl+K` 模糊搜索直达任意面板与操作 |
| **Armory** | +550 个适配的 BOF 与 .NET 工具 |
| **Communication** | 自定义 C2，支持 Telegram、Discord 等外部平台 |
| **Runtime evasion** | 间接系统调用、栈欺骗、睡眠掩码、AMSI/ETW 补丁 |
| **Injections** | VirtualAlloc、section、module stomping 三种分配模式 |
| **LOTL** | 集成 +240 个原生 Windows 二进制（LOLBAS） |
| **Static evasion** | PE 自定义（图标、版本信息、时间戳、节区） |
| **Implants** | 跨平台：Windows / Linux / macOS（含 ARM） |
| **AI** | 集成 DeepSeek 及自定义 LLM 智能体 |
| **Reports** | 执行命令、IOC、失陷主机报告导出 |

---

## Requirements / 环境要求

| Component | Version |
| --- | --- |
| Python | **3.13.5** (server) |
| Node.js | **20+** (client build) |
| OS | Linux (server) · Windows / macOS / Linux (client) |

> The server is designed to run on **Linux**. The desktop client runs on Windows, macOS and Linux.
> 服务端建议运行在 **Linux**；桌面客户端支持 Windows / macOS / Linux。

---

## Installation / 安装

### Option A — One-command install (Linux)

```bash
git clone https://github.com/Leechuihui/umbra.git
cd umbra
sudo bash install.sh all
```

### Option B — Windows client

Run **as Administrator**:

```bat
install\windows.bat client
```

This installs Node.js + Python 3.13.5 if missing, builds the client, and creates a Start Menu shortcut.

### Option C — Manual build / 手动构建

```bash
# 1. Server dependencies
cd server
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. Client build
cd ../client/gui
npm install
npm run dist                  # produces dist/ installers
```

---

## Quick Start / 快速开始

### 1. Start the team server / 启动团队服务器

```bash
# Create an operator key first / 先创建操作员密钥
./umbra.py server key add admin

# Start the server (default 0.0.0.0:9000)
./umbra.py server start
```

Server listens on **`0.0.0.0:9000`** by default.

### 2. Launch the client / 启动客户端

```bash
./umbra.py client start
```

Or launch the built app directly:
- Windows: `client/gui/dist/win-unpacked/umbra.exe`
- macOS: `client/gui/dist/mac/umbra.app`
- Linux: `client/gui/dist/umbra.AppImage`

### 3. Connect / 连接服务器

1. Open the client → top bar **UMBRA → Servers**
2. Click **Add**, fill in:
   - **Host**: your server IP (e.g. `192.168.1.10`)
   - **Port**: `9000`
   - **Protocol**: `http` (or `https` if TLS enabled)
   - **Key**: the operator key from step 1
3. Click **Auth** → status turns green when connected

---

## CLI Reference / 命令参考

```
umbra.py <mode> <command> ...

MODES
    server                          Server mode
    client                          Client mode

COMMANDS
    help                            Show help
    version                         Show server + client version

    server start                    Start the team server
    client start                    Launch the desktop client

    server config list              List server configuration
    server config set <key> <value> Set a config value
    server config reset <key>       Reset a key to default
    server config load <file>       Load config from file
    server config create-tls        Generate self-signed cert + enable TLS

    server key list                 List operator keys
    server key add <name>           Create an operator key
    server key rem <name>           Remove an operator key

    server venv list                List installed Python packages
    server venv install <package>   Install a Python package
    server venv uninstall <package> Uninstall a Python package

    server db usage                 Show database information
    server db export <path>         Export database
    server db import <file>         Import database
```

### Common config keys / 常用配置项

| Key | Default | Description |
| --- | --- | --- |
| `server.host` | `0.0.0.0` | Bind address |
| `server.port` | `9000` | Listen port |
| `server.tls.tls` | `false` | Enable TLS |
| `server.keys.jwt.duration` | `7d` | Operator session lifetime |
| `server.runtime.workers` | `4` | Worker processes |
| `server.runtime.limit_concurrency` | `100` | Max concurrent requests |

Example / 示例:

```bash
./umbra.py server config set server.port 8443
./umbra.py server config create-tls
```

---

## Client Guide / 客户端指南

### Top bar menus / 顶栏菜单

| Menu | Contents |
| --- | --- |
| **UMBRA** | Dashboard · Notebook · Servers · Listeners · Implants · Network · Agents · NukeScripts · Reports · IOCs · Queue · Event Log · Quit |
| **View** | Command Palette (`Ctrl+K`) · Full Screen · Zoom · DevTools |
| **Tabs** | Terminal · File Browser · Processes · Screenshot · Keystrokes · Credentials · Sessions · Attack Graph · AI Agent · File Server · NS Debugger |
| **Help** | Documentation · Feedback · License · About |

### Keyboard shortcuts / 快捷键

| Shortcut | Action |
| --- | --- |
| `Ctrl+K` | Command palette / 命令面板 |
| `Alt+T` | Terminal |
| `Alt+F` | File browser |
| `Alt+R` | Processes |
| `Alt+S` | Sessions |
| `Alt+A` | AI Agent |
| `Alt+K` | Credentials |
| `Shift+S` | Servers panel |
| `Shift+L` | Listeners panel |
| `Shift+I` | Implants panel |
| `Shift+N` | Network panel |
| `Shift+Q` | Queue panel |
| `Shift+E` | Event log |
| `Ctrl+Shift+W` | New workspace tab |
| `Ctrl+W` | Close active panel |
| `F1` | Documentation |
| `F11` | Full screen |

### Language & theme / 语言与主题

- **Language**: click the 🌐 icon in the top bar → English / 中文
- **Theme**: click the 🎨 icon → 4 palettes

Both are persisted locally and restored on next launch.

---

## Documentation / 文档

Full guides live in [`docs/`](docs/):

| Document | Contents |
|---|---|
| [docs/KALI.md](docs/KALI.md) | **Kali-specific**: install, start, connect, listeners, implants, troubleshooting, uninstall |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Why the three layers exist, auth design, C2 flow, evasion techniques, what you learn |
| [docs/USAGE.md](docs/USAGE.md) | Step-by-step install → first session, network scenarios, troubleshooting |
| [docs/WEBSERVER-PLAYBOOK.md](docs/WEBSERVER-PLAYBOOK.md) | **Webserver case playbook**: measured target facts, runnable code, a 55-minute video script, what UMBRA adds, what you learn |
| [docs/VIDEO-SCRIPT-WEBSERVER.md](docs/VIDEO-SCRIPT-WEBSERVER.md) | Real-scenario video script (shot-by-shot version) |
| [docs/VIDEO-SCRIPT-KALI.md](docs/VIDEO-SCRIPT-KALI.md) | **Kali walkthrough video script**: advantages → install → hands-on → what you learn |
| [docs/VIDEO-SCRIPT.md](docs/VIDEO-SCRIPT.md) | Full tutorial video script with shot list and recording checklist |

### Diagrams / 架构图

SVG vector diagrams, ready for slides and video overlays:

| Diagram | File |
|---|---|
| Three-layer architecture | [01-architecture.svg](docs/diagrams/01-architecture.svg) |
| Network topology & port forwarding | [02-network-topology.svg](docs/diagrams/02-network-topology.svg) |
| C2 communication flow (8 steps) | [03-c2-flow.svg](docs/diagrams/03-c2-flow.svg) |
| Post-exploitation capabilities | [04-post-exploitation.svg](docs/diagrams/04-post-exploitation.svg) |
| Quick start (5 steps) | [05-quickstart.svg](docs/diagrams/05-quickstart.svg) |

![Three-layer architecture](docs/diagrams/01-architecture.svg)

---

## Project Structure / 项目结构

```
umbra/
├── umbra.py                 # CLI entrypoint
├── install/                 # Platform installers
│   ├── linux.sh
│   ├── mac.sh
│   └── windows.bat
├── client/gui/              # Electron + React desktop client
│   ├── electron/            # Main process
│   ├── src/
│   │   ├── components/      # UI components
│   │   ├── i18n/            # EN / 中文 dictionaries
│   │   ├── theme/           # Theme system
│   │   └── api/             # Server API clients
│   └── public/              # Icons
├── server/                  # Python team server
│   ├── core/                # FastAPI app + C2 logic
│   ├── launcher/            # CLI command handlers
│   └── infra/               # Database, listeners, builds
└── implants/                # Implant source (Nim / Go)
```

---

## Troubleshooting / 常见问题

**Client shows "Desktop app only"**
> The client must run through Electron. Use `npm run dev` or the packaged binary, not a browser.

**"No servers configured"**
> Add a server via **UMBRA → Servers → Add**, then click **Auth**.

**Server won't start on port 9000**
> Port already in use. Change it: `./umbra.py server config set server.port 8443`

**Build fails on `npm install`**
> Ensure Node.js 20+. Delete `node_modules` and `package-lock.json`, then retry.

**Icons look wrong after build**
> Regenerate: `python scripts/gen_icons.py` (inside `client/gui`)

---

## Credits & License / 致谢与许可

**Author**: leechuihui ([@Leechuihui](https://github.com/Leechuihui))

Licensed under **GPLv3** — see [LICENSE](LICENSE).

Third-party components:

- [SGN](server/infra/bin/encoders/sgn/) — MIT (Ege Balcı)
- [Nim crypt utils](implants/linux/stageless/utils/crypt/utils/) — MIT (Eugene Kabanov)
- [LOLBAS reference](server/core/utils/messages/lolbins/reference/LOLBAS/) — GPLv3 (upstream LOLBAS dataset)

---

## Disclaimer / 免责声明

This tool is intended **exclusively** for authorized security testing, CTF competitions, and educational research. You must have explicit written permission from the system owner before use. Unauthorized access to computer systems is illegal.

本工具**仅供**授权安全测试、CTF 竞赛与教学研究使用。使用前必须获得目标系统所有者的明确书面授权。未经授权访问计算机系统属于违法行为。
