import servers from "./servers";
import listeners from "./listeners";
import network from "./network";
import reports from "./reports";
import iocs from "./iocs";
import queue from "./queue";
import downloads from "./downloads";
import nukescripts from "./nukescripts";
import agents from "./agents";
import implants from "./implants";
import workspace from "./workspace";
import dashboard from "./dashboard";
import notes from "./notes";
import palette from "./palette";

import { getLocale } from "../context";

/**
 * Panel-level i18n registry.
 *
 * Each panel module exports `{ en, zh }` dictionaries keyed by panel-prefixed
 * string keys (e.g. "servers.add"). This registry aggregates them by the
 * current locale so panels can render translated strings via `usePanelT`.
 */
type PanelDictMap = {
  servers: typeof servers;
  listeners: typeof listeners;
  network: typeof network;
  reports: typeof reports;
  iocs: typeof iocs;
  queue: typeof queue;
  downloads: typeof downloads;
  nukescripts: typeof nukescripts;
  agents: typeof agents;
  implants: typeof implants;
  workspace: typeof workspace;
  dashboard: typeof dashboard;
  notes: typeof notes;
  palette: typeof palette;
};

const modules: PanelDictMap = {
  servers,
  listeners,
  network,
  reports,
  iocs,
  queue,
  downloads,
  nukescripts,
  agents,
  implants,
  workspace,
  dashboard,
  notes,
  palette,
};

export type PanelName = keyof PanelDictMap;
export type PanelKey<N extends PanelName> = keyof PanelDictMap[N]["en"];

/** Resolve the current-locale dictionary for a panel. */
export function panelDict<N extends PanelName>(name: N): PanelDictMap[N]["en"] {
  const mod = modules[name];
  const dict = getLocale() === "zh" ? mod.zh : mod.en;
  return dict as PanelDictMap[N]["en"];
}

/**
 * Non-hook translator scoped to a panel. Returns a function that resolves keys
 * from the current-locale dictionary. Use in plain functions, builders, and
 * module-level code where React hooks are unavailable.
 */
export function getPanelT<N extends PanelName>(name: N): (key: PanelKey<N> | string, fallback?: string) => string {
  return (key: PanelKey<N> | string, fallback?: string) => {
    const dict = panelDict(name) as Record<string, string>;
    const value = dict[key as string];
    return (value ?? fallback ?? key) as string;
  };
}

export default modules;
