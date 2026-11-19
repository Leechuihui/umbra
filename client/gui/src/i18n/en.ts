// English dictionary (default / source of truth)
const en = {
  // ---- Brand / metadata ----
  "brand.title": "UMBRA",
  "brand.full": "UMBRA Framework",
  "brand.tagline": "Post exploitation framework",
  "brand.product": "UMBRA client",
  "brand.exit.title": "Confirm exit",
  "brand.exit.body": "There are active sessions. Are you sure you want to quit?",
  "brand.exit.quit": "Quit",
  "brand.exit.cancel": "Cancel",
  "brand.browser-only.title": "Desktop app only",
  "brand.browser-only.body":
    "The UMBRA client is not supported in standard web browsers and must be run as a desktop application using Electron.",

  // ---- About panel ----
  "about.version": "Version",
  "about.platform": "Platform",
  "about.electron": "Electron",
  "about.electronBuildId": "ElectronBuildId",
  "about.chromium": "Chromium",
  "about.node": "Node",
  "about.author": "Author",
  "about.authorValue": "leechuihui",
  "about.copyright": "© 2026 UMBRA. All rights reserved.",

  // ---- Menus ----
  "menu.file": "File",
  "menu.view": "View",
  "menu.umbra": "UMBRA",
  "menu.tabs": "Tabs",
  "menu.help": "Help",

  "menu.servers": "Servers",
  "menu.listeners": "Listeners",
  "menu.implants": "Implants",
  "menu.network": "Network",
  "menu.agents": "Agents",
  "menu.nukescripts": "NukeScripts",
  "menu.reports": "Reports",
  "menu.reportFiles": "Files",
  "menu.iocs": "IOCs",
  "menu.queue": "Queue",
  "menu.logs": "Event Log",
  "menu.quit": "Quit",

  "menu.fullscreen": "Full Screen",
  "menu.zoomIn": "Zoom In",
  "menu.zoomOut": "Zoom Out",
  "menu.zoomReset": "Reset Zoom",
  "menu.devtools": "Devtools",

  "menu.terminal": "Terminal",
  "menu.fileBrowser": "File Browser",
  "menu.processes": "Processes",
  "menu.screenshot": "Screenshot",
  "menu.keylogger": "Keystrokes",
  "menu.credentials": "Credentials",
  "menu.sessions": "Sessions",
  "menu.graphs": "Attack Graph",
  "menu.agent": "AI Agent",
  "menu.fileServer": "File Server",
  "menu.nsDebugger": "NS Debugger",
  "menu.dashboard": "Dashboard",
  "menu.notes": "Notebook",
  "menu.commandPalette": "Command Palette",

  "menu.documentation": "Documentation",
  "menu.shortcuts": "Shortcuts",
  "menu.feedback": "Feedbacks",
  "menu.license": "License",
  "menu.about": "About",

  // ---- Nav items (descriptions) ----
  "nav.terminal.desc": "Interactive session console",
  "nav.fileBrowser.desc": "Browse files on the active host",
  "nav.processes.desc": "View and manage host processes",
  "nav.screenshot.desc": "Capture remote desktop view",
  "nav.keylogger.desc": "Capture keyboard events",
  "nav.credentials.desc": "Manage stored credentials",
  "nav.sessions.desc": "View active sessions",
  "nav.graphs.desc": "Visualize lateral movement and pivots",
  "nav.agent.desc": "AI-assisted session operations",
  "nav.fileServer.desc": "Team server file staging",
  "nav.newWorkspace": "New workspace",

  // ---- Empty workspace / context menu ----
  "empty.new": "New",
  "empty.umbra": "UMBRA",
  "empty.Keystrokes": "Keystrokes",
  "empty.Targets": "Targets",

  // ---- Toasts ----
  "toast.newSession": "New session",
  "toast.notification": "Notification",

  // ---- Theme ----
  "theme.label": "Theme",

  // ---- Language ----
  "lang.label": "Language",
  "lang.en": "English",
  "lang.zh": "中文",
} as const;

export type Dictionary = { [K in keyof typeof en]: string };
export default en;
