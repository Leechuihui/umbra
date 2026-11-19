import { useCallback } from "react";
import { panelDict, type PanelName, type PanelKey } from "./registry";

/**
 * Returns a translation function scoped to a panel's dictionary.
 *
 * Usage:
 *   const t = usePanelT("servers");
 *   t("servers.add");
 *
 * Falls back to the key (or an explicit English fallback) when a panel key is
 * missing, so untranslated panels degrade gracefully.
 */
export function usePanelT<N extends PanelName>(
  name: N,
): (key: PanelKey<N> | string, fallback?: string) => string {
  return useCallback(
    (key: PanelKey<N> | string, fallback?: string) => {
      const dict = panelDict(name) as Record<string, string>;
      const value = dict[key as string];
      return (value ?? fallback ?? key) as string;
    },
    [name],
  );
}
