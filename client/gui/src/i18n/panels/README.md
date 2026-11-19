# Panel i18n pattern (UMBRA)

UMBRA ships a bilingual EN / 中文 UI. The top bar, about panel, and
empty-workspace menu are translated, as are the main panels.
This doc defines the pattern for translating a panel.

## The pattern

1. **Dictionary file** `src/i18n/panels/<name>.ts` exports BOTH `en` and `zh`
   objects, keyed by panel-prefixed strings. Example:

   ```ts
   export const en = {
     "listeners.add": "Add",
     "listeners.empty": "No listeners configured",
   } as const;

   export const zh: Record<string, string> = {
     "listeners.add": "添加",
     "listeners.empty": "尚未配置监听器",
   } as const;

   export default { en, zh };
   ```

   - `en` must be `as const` (it is the source of truth).
   - `zh` is typed `Record<string, string>` and must have the SAME keys.
   - Keys are prefixed with the panel name (e.g. `listeners.`) to avoid clashes.
   - Register the module in `src/i18n/panels/registry.ts`.

2. **Translation hook** — import `usePanelT` and call it at the top of each
   component that renders user-visible text:

   ```tsx
   import { usePanelT } from "@/i18n/panels/hook";
   // ...
   export function MyComponent() {
     const t = usePanelT("listeners");   // panel name matches the dict file
     return <span>{t("listeners.add")}</span>;
   }
   ```

   - `t(key)` returns the translated string.
   - `t(key, "English fallback")` returns the fallback if the key is missing.
   - For non-hook code (plain functions/builders), import `getPanelT` from
     `@/i18n/panels/registry` and call `const t = getPanelT("listeners");`
     then `t("listeners.add")`.

3. **What to translate** — only user-visible strings: button labels, headings,
   table column headers, placeholders, empty-state text, dialog titles/messages,
   tooltips, tab labels, status text. Do NOT translate:
   - code identifiers, variable names, IPC channel names, protocol values
     (`"http"`, `"https"`), file extensions (`.key`), IP/port placeholders.
   - CSS class names, TypeScript types, non-UI constants.

4. **Keys** — use camelCase segment after the prefix, matching the English
   meaning (e.g. `listeners.httpTitle`, `listeners.removeConfirm`). Reuse keys
   across components in the same panel.

5. After editing, run:
   ```
   node_modules\.bin\tsc --noEmit -p tsconfig.app.json
   ```
   and confirm NO new errors appear in your files. The baseline already has
   ~26 pre-existing errors in unrelated files — do not try to fix those.
