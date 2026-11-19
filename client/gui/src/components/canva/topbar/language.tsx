import { Languages } from "lucide-react";
import { useI18n, type Locale } from "@/i18n/context";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

const LOCALES: { id: Locale; label: string }[] = [
  { id: "en", label: "English" },
  { id: "zh", label: "中文" },
];

export default function LanguageToggle() {
  const { locale, setLocale, t } = useI18n();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          title={t("lang.label")}
          aria-label={t("lang.label")}
          className="button-default cursor-pointer flex items-center gap-1.5 px-2 py-1.5 text-[#8a8a8a] hover:text-[#cecece] transition-colors rounded"
        >
          <Languages size={16} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        sideOffset={6}
        align="end"
        className="rounded-[8px]"
      >
        <span className="px-2 py-1 text-[10px] uppercase tracking-[0.1em] text-[#555]">
          {t("lang.label")}
        </span>
        {LOCALES.map((item) => (
          <DropdownMenuItem
            key={item.id}
            className="flex items-center justify-between gap-4"
            onSelect={() => setLocale(item.id)}
          >
            <span>{item.label}</span>
            {item.id === locale && <span className="text-[#41be5c]">✓</span>}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
