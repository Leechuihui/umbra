import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { getT } from "@/i18n/context";
import {
  Activity,
  Bot,
  Bug,
  Camera,
  CodeXml,
  Cpu,
  Folder,
  Globe,
  Headphones,
  Keyboard,
  KeyRound,
  MonitorIcon,
  Network,
  NotebookPen,
  Plus,
  Scale,
  Server,
  Share2,
  SquareChevronRight,
  Logs,
  FileText,
} from "lucide-react";
import { PanelMenuShell, type PanelCustomMenuItem } from "@/components/ui/rigth-click-menu.tsx";

export type EmptyMenuRuntime = {
  openWindow: (windowType: string) => void;
  floatWindow: (windowType: string) => void;
};

export const emptyMenuRuntimeRef: { current: EmptyMenuRuntime | null } = { current: null };

const open = (t: string) => () => emptyMenuRuntimeRef.current?.openWindow(t);
const float = (t: string) => () => emptyMenuRuntimeRef.current?.floatWindow(t);

const leaf = (label: string, icon?: LucideIcon, onClick?: () => void): PanelCustomMenuItem => ({
  kind: "action",
  label,
  icon,
  onClick,
});

const group = (label: string, items: PanelCustomMenuItem[], icon?: LucideIcon): PanelCustomMenuItem => ({
  kind: "action",
  label,
  icon,
  items,
});

const sep = (): PanelCustomMenuItem => ({ kind: "separator" });

export function buildEmptyWorkspaceMenuItems(): PanelCustomMenuItem[] {
  const t = getT();
  return [
    group(
      t("empty.new"),
      [
        leaf(t("menu.dashboard"), Activity, open("dashboard")),
        leaf(t("menu.notes"), NotebookPen, open("notes")),
        sep(),
        leaf(t("menu.terminal"), SquareChevronRight, open("terminal")),
        leaf(t("menu.fileBrowser"), Folder, open("explorer")),
        leaf(t("menu.processes"), Cpu, open("process")),
        sep(),
        leaf(t("menu.screenshot"), Camera, open("screenshot")),
        leaf(t("menu.keylogger"), Keyboard, open("keylogger")),
        leaf(t("menu.credentials"), KeyRound, open("credentials")),
        sep(),
        leaf(t("empty.Targets"), MonitorIcon, open("sessions")),
        leaf(t("menu.graphs"), Share2, open("graphs")),
        sep(),
        leaf(t("menu.agent"), Bot, open("agent")),
        leaf(t("menu.fileServer"), Globe, open("fileServer")),
        sep(),
        leaf(t("menu.nsDebugger"), CodeXml, open("nukescripts_output")),
      ],
      Plus
    ),
    group(t("empty.umbra"), [
      leaf(t("menu.servers"), Server, float("servers")),
      leaf(t("menu.listeners"), Headphones, float("listeners")),
      leaf(t("menu.implants"), Bug, float("implants")),
      leaf(t("menu.network"), Network, float("network")),
      sep(),
      leaf(t("menu.agents"), Bot, float("agents")),
      leaf(t("menu.nukescripts"), CodeXml, float("nukescripts")),
      sep(),
      group(
        t("menu.reports"),
        [leaf(t("menu.reportFiles"), undefined, float("reports")), leaf(t("menu.iocs"), undefined, float("iocs"))],
        Scale
      ),
      sep(),
      leaf(t("menu.queue"), Logs, float("queue")),
      leaf(t("menu.logs"), FileText, float("logs")),
    ]),
  ];
}

export function EmptyViewShell({ children }: { children: ReactNode }) {
  return <PanelMenuShell kind="emptyWorkspace">{children}</PanelMenuShell>;
}
