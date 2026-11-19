import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type ThemeId = "umbra" | "ember" | "abyss" | "mono";

export type Theme = {
  id: ThemeId;
  accent: string;
  accentDim: string;
  accentGlow: string;
  label: { en: string; zh: string };
};

/** Original accent palettes shipped with UMBRA. */
export const THEMES: Record<ThemeId, Theme> = {
  umbra: {
    id: "umbra",
    accent: "#5fe0c8",
    accentDim: "#2b7f72",
    accentGlow: "rgba(95, 224, 200, 0.25)",
    label: { en: "Umbra Teal", zh: "暗影青" },
  },
  ember: {
    id: "ember",
    accent: "#ff8a5c",
    accentDim: "#9c4a2c",
    accentGlow: "rgba(255, 138, 92, 0.25)",
    label: { en: "Ember", zh: "余烬橙" },
  },
  abyss: {
    id: "abyss",
    accent: "#8aa4ff",
    accentDim: "#41539c",
    accentGlow: "rgba(138, 164, 255, 0.25)",
    label: { en: "Abyss Blue", zh: "深渊蓝" },
  },
  mono: {
    id: "mono",
    accent: "#d8d8d8",
    accentDim: "#6a6a6a",
    accentGlow: "rgba(216, 216, 216, 0.22)",
    label: { en: "Monochrome", zh: "单色" },
  },
};

export const THEME_ORDER: ThemeId[] = ["umbra", "ember", "abyss", "mono"];

const STORAGE_KEY = "umbra-theme";

type ThemeContextValue = {
  themeId: ThemeId;
  theme: Theme;
  setTheme: (id: ThemeId) => void;
  cycleTheme: () => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function readStored(): ThemeId {
  try {
    const v = window.localStorage.getItem(STORAGE_KEY);
    if (v && v in THEMES) return v as ThemeId;
  } catch {
    /* ignore */
  }
  return "umbra";
}

function applyTheme(theme: Theme) {
  const root = document.documentElement;
  root.style.setProperty("--umbra-accent", theme.accent);
  root.style.setProperty("--umbra-accent-dim", theme.accentDim);
  root.style.setProperty("--umbra-accent-glow", theme.accentGlow);
  root.setAttribute("data-theme", theme.id);
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [themeId, setThemeId] = useState<ThemeId>(() => readStored());

  useEffect(() => {
    applyTheme(THEMES[themeId]);
  }, [themeId]);

  const setTheme = useCallback((id: ThemeId) => {
    setThemeId(id);
    try {
      window.localStorage.setItem(STORAGE_KEY, id);
    } catch {
      /* ignore */
    }
  }, []);

  const cycleTheme = useCallback(() => {
    setThemeId((prev) => {
      const next = THEME_ORDER[(THEME_ORDER.indexOf(prev) + 1) % THEME_ORDER.length];
      try {
        window.localStorage.setItem(STORAGE_KEY, next);
      } catch {
        /* ignore */
      }
      return next;
    });
  }, []);

  const value = useMemo<ThemeContextValue>(
    () => ({ themeId, theme: THEMES[themeId], setTheme, cycleTheme }),
    [themeId, setTheme, cycleTheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within a ThemeProvider");
  return ctx;
}
