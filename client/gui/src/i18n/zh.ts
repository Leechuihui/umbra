// Chinese (Simplified) dictionary
import type { Dictionary } from "./en";

const zh: Dictionary = {
  // ---- Brand / metadata ----
  "brand.title": "UMBRA",
  "brand.full": "UMBRA 框架",
  "brand.tagline": "后渗透测试框架",
  "brand.product": "UMBRA 客户端",
  "brand.exit.title": "确认退出",
  "brand.exit.body": "存在活动会话，确定要退出吗？",
  "brand.exit.quit": "退出",
  "brand.exit.cancel": "取消",
  "brand.browser-only.title": "仅限桌面应用",
  "brand.browser-only.body":
    "UMBRA 客户端不支持在普通网页浏览器中运行，必须使用 Electron 作为桌面应用程序运行。",

  // ---- About panel ----
  "about.version": "版本",
  "about.platform": "平台",
  "about.electron": "Electron",
  "about.electronBuildId": "Electron 构建 ID",
  "about.chromium": "Chromium",
  "about.node": "Node",
  "about.author": "作者",
  "about.authorValue": "leechuihui",
  "about.copyright": "© 2026 UMBRA。保留所有权利。",

  // ---- Menus ----
  "menu.file": "文件",
  "menu.view": "视图",
  "menu.umbra": "UMBRA",
  "menu.tabs": "标签页",
  "menu.help": "帮助",

  "menu.servers": "服务器",
  "menu.listeners": "监听器",
  "menu.implants": "植入体",
  "menu.network": "网络",
  "menu.agents": "智能体",
  "menu.nukescripts": "Nuke 脚本",
  "menu.reports": "报告",
  "menu.reportFiles": "文件",
  "menu.iocs": "IOC 指标",
  "menu.queue": "队列",
  "menu.logs": "事件日志",
  "menu.quit": "退出",

  "menu.fullscreen": "全屏",
  "menu.zoomIn": "放大",
  "menu.zoomOut": "缩小",
  "menu.zoomReset": "重置缩放",
  "menu.devtools": "开发者工具",

  "menu.terminal": "终端",
  "menu.fileBrowser": "文件浏览器",
  "menu.processes": "进程",
  "menu.screenshot": "屏幕截图",
  "menu.keylogger": "键盘记录",
  "menu.credentials": "凭据",
  "menu.sessions": "会话",
  "menu.graphs": "攻击图谱",
  "menu.agent": "AI 智能体",
  "menu.fileServer": "文件服务器",
  "menu.nsDebugger": "NS 调试器",
  "menu.dashboard": "作战仪表盘",
  "menu.notes": "作战笔记",
  "menu.commandPalette": "命令面板",

  "menu.documentation": "文档",
  "menu.shortcuts": "快捷键",
  "menu.feedback": "反馈",
  "menu.license": "许可证",
  "menu.about": "关于",

  // ---- Nav items (descriptions) ----
  "nav.terminal.desc": "交互式会话控制台",
  "nav.fileBrowser.desc": "浏览活动主机上的文件",
  "nav.processes.desc": "查看并管理主机进程",
  "nav.screenshot.desc": "捕获远程桌面视图",
  "nav.keylogger.desc": "捕获键盘事件",
  "nav.credentials.desc": "管理已存储的凭据",
  "nav.sessions.desc": "查看活动会话",
  "nav.graphs.desc": "可视化横向移动与代理跳转",
  "nav.agent.desc": "AI 辅助会话操作",
  "nav.fileServer.desc": "团队服务器文件暂存",
  "nav.newWorkspace": "新建工作区",

  // ---- Empty workspace / context menu ----
  "empty.new": "新建",
  "empty.umbra": "UMBRA",
  "empty.Keystrokes": "键盘记录",
  "empty.Targets": "目标",

  // ---- Toasts ----
  "toast.newSession": "新会话",
  "toast.notification": "通知",

  // ---- Theme ----
  "theme.label": "主题",

  // ---- Language ----
  "lang.label": "语言",
  "lang.en": "English",
  "lang.zh": "中文",
} as const;

export default zh;
