import { useImperativeHandle, useRef, type Ref } from "react";
import type { DockviewApi } from "dockview";
import type { Session } from "@/api/sessions";
import { getPanelT } from "@/i18n/panels/registry";

function panelAtPointer(api: DockviewApi, clientX: number, clientY: number) {
  const hit = document.elementFromPoint(clientX, clientY);
  if (!hit) return undefined;

  for (const panel of api.panels) {
    const content = panel.view?.content?.element;
    const tab = panel.view?.tab?.element;
    if (content && (content === hit || content.contains(hit))) return panel;
    if (tab && (tab === hit || tab.contains(hit))) return panel;
  }

  for (const group of api.groups) {
    const el = (group as { element?: HTMLElement }).element;
    if (el?.contains(hit)) return group.activePanel;
  }

  return undefined;
}

export type SessionSelectData = { host: Session; server: string } | null;

export type PanelOpenParams = { selectedHost?: SessionSelectData; windowType?: string };

export const pendingPanelParamsRef = {
  current: null as PanelOpenParams | null,
};

export interface WorkspaceProps {
  setWindows: (hasWindows: boolean) => void;
  pendingWindow?: string | null;
  pendingPanelParams?: PanelOpenParams | null;
  onWindowOpen?: () => void;
}

export type WorkspaceHandle = {
  openWindow: (windowType: string) => void;
  closeHoveredPanel: () => void;
};

const hostless_windows = new Set([
  "docs",
  "dashboard",
  "notes",
  "graphs",
  "sessions",
  "fileServer",
  "agent",
  "keylogger",
  "queue",
  "nukescripts",
  "credentials",
  "nukescripts_output",
  "listeners",
  "network",
  "servers",
  "implants",
  "logs",
  "agents",
  "iocs",
  "reports",
  "about",
]);

export function getPanelTitle(windowType: string): string {
  const t = getPanelT("workspace");
  const key = `workspace.title.${windowType}`;
  const translated = t(key, "");
  if (translated) return translated;
  return windowType.charAt(0).toUpperCase() + windowType.slice(1);
}

/** Resolve a panel's windowType from its params, falling back to a legacy title lookup. */
export function getWindowType(params: unknown, title?: string): string | undefined {
  const fromParams = (params as PanelOpenParams | undefined)?.windowType;
  if (fromParams) return fromParams;
  if (!title) return undefined;
  const t = getPanelT("workspace");
  const prefix = "workspace.title.";
  for (const key of Object.keys(hostless_windows)) {
    if (t(`${prefix}${key}`, "") === title) return key;
  }
  // Legacy English titles (params absent).
  const lower = title.toLowerCase();
  if (lower === "file browser") return "explorer";
  if (lower === "file server") return "fileServer";
  if (lower === "ai agent") return "agent";
  if (lower === "ns debugger") return "nukescripts_output";
  if (lower === "iocs") return "iocs";
  if (lower === "nukescripts") return "nukescripts";
  return lower.replace(/\s+/g, "");
}

export function shouldShowHostSelect(windowType: string | undefined): boolean {
  return !hostless_windows.has(windowType ?? "");
}

export function getPanelHeaderJustify(windowType: string | undefined): "left" | "between" {
  return hostless_windows.has(windowType ?? "") ? "left" : "between";
}

export function useWorkspace(
  { setWindows, pendingWindow, pendingPanelParams, onWindowOpen }: WorkspaceProps,
  ref: Ref<WorkspaceHandle>
) {
  const dockviewRef = useRef<DockviewApi | null>(null);
  const pointerRef = useRef({ x: 0, y: 0 });

  const addPanel = (windowType: string, panelParams?: PanelOpenParams | null) => {
    if (!dockviewRef.current) return;
    const params = panelParams ?? pendingPanelParamsRef.current;
    pendingPanelParamsRef.current = null;
    dockviewRef.current.addPanel({
      id: `${windowType}-${Date.now()}`,
      component: windowType,
      tabComponent: "header",
      title: getPanelTitle(windowType),
      position: { direction: "right" },
      // Always carry the windowType so the header can translate the title
      // without depending on locale-specific strings.
      params: { ...(params ?? {}), windowType },
    });
  };

  const closeHoveredPanel = () => {
    const api = dockviewRef.current;
    if (!api) return;
    const { x, y } = pointerRef.current;
    const panel = panelAtPointer(api, x, y) ?? api.activePanel ?? undefined;
    panel?.api.close();
  };

  useImperativeHandle(ref, () => ({
    openWindow: addPanel,
    closeHoveredPanel,
  }));

  const onWorkspacePointerMove = (e: React.PointerEvent) => {
    pointerRef.current = { x: e.clientX, y: e.clientY };
  };

  const onDockviewReady = (e: { api: any }) => {
    dockviewRef.current = e.api;
    e.api.onDidAddPanel(() => setWindows(e.api.panels.length > 0));
    e.api.onDidRemovePanel(() => setWindows(e.api.panels.length > 0));

    if (pendingWindow) {
      addPanel(pendingWindow, pendingPanelParams);
      onWindowOpen?.();
    }
  };

  return { onDockviewReady, onWorkspacePointerMove };
}
