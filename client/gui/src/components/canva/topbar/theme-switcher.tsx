import { Palette, Check } from "lucide-react";
import { useI18n } from "@/i18n/context";
import { useTheme, THEMES, THEME_ORDER } from "@/theme/context";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

/** Original accent-theme picker for the UMBRA top bar. */
export default function ThemeSwitcher() {
  const { locale, t } = useI18n();
  const { themeId, setTheme } = useTheme();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          title={t("theme.label")}
          aria-label={t("theme.label")}
          className="button-default cursor-pointer flex items-center gap-1.5 px-2 py-1.5 text-[#8a8a8a] hover:text-[#cecece] transition-colors rounded"
        >
          <Palette size={16} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent sideOffset={6} align="end" className="rounded-[8px]">
        <span className="px-2 py-1 text-[10px] uppercase tracking-[0.1em] text-[#555]">
          {t("theme.label")}
        </span>
        {THEME_ORDER.map((id) => {
          const theme = THEMES[id];
          return (
            <DropdownMenuItem
              key={id}
              className="flex items-center justify-between gap-4"
              onSelect={() => setTheme(id)}
            >
              <span className="flex items-center gap-2">
                <span
                  className="umbra-swatch"
                  style={{ backgroundColor: theme.accent }}
                />
                {locale === "zh" ? theme.label.zh : theme.label.en}
              </span>
              {id === themeId && <Check size={13} className="umbra-accent-text" />}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
