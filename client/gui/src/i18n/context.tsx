import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import en, { type Dictionary } from "./en";
import zh from "./zh";

export type Locale = "en" | "zh";

const STORAGE_KEY = "UMBRA-locale";

const dictionaries: Record<Locale, Dictionary> = { en, zh };

/** Current locale accessor for non-hook callers (e.g. plain builders). */
let currentLocale: Locale = "en";
export function getLocale(): Locale {
  return currentLocale;
}
/** Translate without a hook, using the latest known locale. */
export function getT(): (key: keyof Dictionary, fallback?: string) => string {
  return (key: keyof Dictionary, fallback?: string) => {
    const value = dictionaries[currentLocale][key];
    return (value ?? fallback ?? key) as string;
  };
}

type I18nContextValue = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  toggleLocale: () => void;
  t: (key: keyof Dictionary, fallback?: string) => string;
};

const I18nContext = createContext<I18nContextValue | null>(null);

function readStoredLocale(): Locale {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored === "en" || stored === "zh") return stored;
  } catch {
    /* ignore */
  }
  return "en";
}

function detectLocale(): Locale {
  const stored = readStoredLocale();
  if (stored !== "en") {
    currentLocale = stored;
    return stored;
  }
  try {
    const nav = navigator.language?.toLowerCase() ?? "";
    if (nav.startsWith("zh")) {
      currentLocale = "zh";
      return "zh";
    }
  } catch {
    /* ignore */
  }
  return "en";
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(() => detectLocale());

  const setLocale = useCallback((next: Locale) => {
    currentLocale = next;
    setLocaleState(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* ignore */
    }
    document.documentElement.setAttribute("lang", next);
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute("lang", locale);
  }, [locale]);

  const toggleLocale = useCallback(() => {
    setLocale(locale === "en" ? "zh" : "en");
  }, [locale, setLocale]);

  const t = useCallback(
    (key: keyof Dictionary, fallback?: string): string => {
      const dict = dictionaries[locale];
      const value = dict[key];
      if (value != null) return value as string;
      return fallback ?? key;
    },
    [locale],
  );

  const value = useMemo<I18nContextValue>(
    () => ({ locale, setLocale, toggleLocale, t }),
    [locale, setLocale, toggleLocale, t],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must be used within an I18nProvider");
  }
  return ctx;
}

export function useT(): (key: keyof Dictionary, fallback?: string) => string {
  return useI18n().t;
}
