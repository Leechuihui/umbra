import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  Bot,
  Bug,
  Camera,
  CodeXml,
  Cpu,
  FileText,
  Fingerprint,
  Folder,
  Globe,
  Headphones,
  Keyboard,
  KeyRound,
  Logs,
  Maximize2,
  MonitorIcon,
  Network,
  NotebookPen,
  Palette,
  Plus,
  Server,
  Share2,
  SquareChevronRight,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import { usePanelT } from "@/i18n/panels/hook";
import { useI18n } from "@/i18n/context";
import { useTheme } from "@/theme/context";
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandShortcut,
} from "@/components/ui/command";

/**
 * UMBRA original command palette (Ctrl/Cmd + K).
 *
 * A single fuzzy-search surface that opens any workspace panel, floats a
 * top-bar panel, or triggers a window action — without hunting through menus.
 */

type PaletteGroup = "panels" | "workspace" | "view";

type PaletteAction = {
  id: string;
  label: string;
  group: PaletteGroup;
  icon: React.ReactNode;
  shortcut?: string;
  run: () => void;
};

type PaletteActionSeed = Omit<PaletteAction, "group">;

export type CommandPaletteProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  openWindow: (type: string) => void;
  floatWindow: (type: string) => void;
  addTab: () => void;
};

export function CommandPalette({
  open,
  onOpenChange,
  openWindow,
  floatWindow,
  addTab,
}: CommandPaletteProps) {
  const t = usePanelT("palette");
  const { t: tMain } = useI18n();
  const { cycleTheme } = useTheme();
  const [query, setQuery] = useState("");

  useEffect(() => {
    if (!open) setQuery("");
  }, [open]);

  const sendWindow = (channel: string) => window.electronAPI?.send(channel);

  const actions = useMemo<PaletteAction[]>(() => {
    const panelActions: PaletteActionSeed[] = [
      { id: "dashboard", label: tMain("menu.dashboard"), icon: <Activity size={14} />, run: () => openWindow("dashboard") },
      { id: "notes", label: tMain("menu.notes"), icon: <NotebookPen size={14} />, run: () => openWindow("notes") },
      { id: "terminal", label: tMain("menu.terminal"), icon: <SquareChevronRight size={14} />, run: () => openWindow("terminal") },
      { id: "explorer", label: tMain("menu.fileBrowser"), icon: <Folder size={14} />, run: () => openWindow("explorer") },
      { id: "process", label: tMain("menu.processes"), icon: <Cpu size={14} />, run: () => openWindow("process") },
      { id: "screenshot", label: tMain("menu.screenshot"), icon: <Camera size={14} />, run: () => openWindow("screenshot") },
      { id: "keylogger", label: tMain("menu.keylogger"), icon: <Keyboard size={14} />, run: () => openWindow("keylogger") },
      { id: "credentials", label: tMain("menu.credentials"), icon: <KeyRound size={14} />, run: () => openWindow("credentials") },
      { id: "sessions", label: tMain("menu.sessions"), icon: <MonitorIcon size={14} />, run: () => openWindow("sessions") },
      { id: "graphs", label: tMain("menu.graphs"), icon: <Share2 size={14} />, run: () => openWindow("graphs") },
      { id: "agent", label: tMain("menu.agent"), icon: <Bot size={14} />, run: () => openWindow("agent") },
      { id: "fileServer", label: tMain("menu.fileServer"), icon: <Globe size={14} />, run: () => openWindow("fileServer") },
      { id: "nukescripts_output", label: tMain("menu.nsDebugger"), icon: <CodeXml size={14} />, run: () => openWindow("nukescripts_output") },
    ];

    const floatActions: PaletteActionSeed[] = [
      { id: "f-servers", label: tMain("menu.servers"), icon: <Server size={14} />, run: () => floatWindow("servers") },
      { id: "f-listeners", label: tMain("menu.listeners"), icon: <Headphones size={14} />, run: () => floatWindow("listeners") },
      { id: "f-implants", label: tMain("menu.implants"), icon: <Bug size={14} />, run: () => floatWindow("implants") },
      { id: "f-network", label: tMain("menu.network"), icon: <Network size={14} />, run: () => floatWindow("network") },
      { id: "f-agents", label: tMain("menu.agents"), icon: <Bot size={14} />, run: () => floatWindow("agents") },
      { id: "f-nukescripts", label: tMain("menu.nukescripts"), icon: <CodeXml size={14} />, run: () => floatWindow("nukescripts") },
      { id: "f-reports", label: tMain("menu.reports"), icon: <FileText size={14} />, run: () => floatWindow("reports") },
      { id: "f-iocs", label: tMain("menu.iocs"), icon: <Fingerprint size={14} />, run: () => floatWindow("iocs") },
      { id: "f-queue", label: tMain("menu.queue"), icon: <Logs size={14} />, run: () => floatWindow("queue") },
      { id: "f-logs", label: tMain("menu.logs"), icon: <FileText size={14} />, run: () => floatWindow("logs") },
    ];

    const viewActions: PaletteActionSeed[] = [
      { id: "v-newtab", label: tMain("nav.newWorkspace"), icon: <Plus size={14} />, run: addTab },
      { id: "v-theme", label: tMain("theme.label"), icon: <Palette size={14} />, run: cycleTheme },
      { id: "v-fullscreen", label: tMain("menu.fullscreen"), icon: <Maximize2 size={14} />, run: () => sendWindow("window:toggleFullscreen") },
      { id: "v-zoomin", label: tMain("menu.zoomIn"), icon: <ZoomIn size={14} />, run: () => sendWindow("window:zoomIn") },
      { id: "v-zoomout", label: tMain("menu.zoomOut"), icon: <ZoomOut size={14} />, run: () => sendWindow("window:zoomOut") },
    ];

    return [
      ...panelActions.map((a) => ({ ...a, group: "panels" as const })),
      ...floatActions.map((a) => ({ ...a, group: "workspace" as const })),
      ...viewActions.map((a) => ({ ...a, group: "view" as const })),
    ];
  }, [tMain, openWindow, floatWindow, addTab, cycleTheme]);

  const groups: { key: PaletteAction["group"]; label: string }[] = [
    { key: "panels", label: t("palette.groupPanels") },
    { key: "workspace", label: t("palette.groupWorkspace") },
    { key: "view", label: t("palette.groupView") },
  ];

  return (
    <CommandDialog
      open={open}
      onOpenChange={onOpenChange}
      title={t("palette.hint")}
      description={t("palette.placeholder")}
      className="w-[min(92vw,34rem)]"
    >
      <Command shouldFilter>
        <div className="p-2 border-b border-[#252525]">
          <CommandInput
            autoFocus
            value={query}
            onValueChange={setQuery}
            placeholder={t("palette.placeholder")}
            className="!h-8 text-[13px]"
          />
        </div>
        <CommandList className="max-h-[22rem] p-1">
          <CommandEmpty className="py-6 text-center text-[12px] text-[#666]">
            {t("palette.empty")}
          </CommandEmpty>
          {groups.map((group) => {
            const items = actions.filter((a) => a.group === group.key);
            if (!items.length) return null;
            return (
              <CommandGroup key={group.key} heading={group.label}>
                {items.map((action) => (
                  <CommandItem
                    key={action.id}
                    value={`${action.label} ${action.id}`}
                    onSelect={() => {
                      action.run();
                      onOpenChange(false);
                    }}
                    className="gap-2 px-2 py-1.5 text-[13px]"
                  >
                    <span className="text-[#888]">{action.icon}</span>
                    <span className="flex-1 truncate">{action.label}</span>
                    {action.shortcut && <CommandShortcut>{action.shortcut}</CommandShortcut>}
                  </CommandItem>
                ))}
              </CommandGroup>
            );
          })}
        </CommandList>
        <div className="flex items-center gap-3 border-t border-[#252525] px-3 py-1.5 text-[10.5px] text-[#555]">
          <span>↑↓ {t("palette.navigate")}</span>
          <span>↵ {t("palette.select")}</span>
          <span>Esc {t("palette.close")}</span>
        </div>
      </Command>
    </CommandDialog>
  );
}
