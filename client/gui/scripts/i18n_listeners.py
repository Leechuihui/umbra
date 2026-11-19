"""Bulk-translate the remaining listener sub-forms (UMBRA i18n).

Adds the usePanelT hook and swaps hardcoded English labels for
dictionary keys in add-https.tsx / add-file-server.tsx / add-http.tsx.
"""
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
DIR = BASE / "src" / "components" / "canva" / "topbar" / "listeners" / "components"

IMPORT_LINE = 'import { usePanelT } from "@/i18n/panels/hook";'

# (old literal, i18n expression)
SUBS = [
    ('<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">Server</label>',
     '<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">{t("listeners.fieldServer")}</label>'),
    ('<SelectValue placeholder="Select a server..." />',
     '<SelectValue placeholder={t("listeners.serverPlaceholder")} />'),
    ('<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">Port to Open</label>',
     '<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">{t("listeners.portToOpen")}</label>'),
    ('aria-label="Port to open"', 'aria-label={t("listeners.portToOpenAria")}'),
    ('<span className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">Advanced</span>',
     '<span className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">{t("listeners.advanced")}</span>'),
    ('<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">Endpoint Path</label>',
     '<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">{t("listeners.endpointPath")}</label>'),
    ('<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">Response Headers</label>',
     '<label className="block text-[12px] text-[#6e6e6e] uppercase tracking-widest">{t("listeners.responseHeaders")}</label>'),
    ('<label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">Custom body</label>',
     '<label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">{t("listeners.customBody")}</label>'),
    ('<SelectItem value="off" className="text-[13.5px]">off</SelectItem>',
     '<SelectItem value="off" className="text-[13.5px]">{t("listeners.bodyOff")}</SelectItem>'),
    ('<SelectItem value="custom" className="text-[13.5px]">custom</SelectItem>',
     '<SelectItem value="custom" className="text-[13.5px]">{t("listeners.bodyCustom")}</SelectItem>'),
    ('<SelectLabel className="text-[11px] text-[#6e6e6e] uppercase">Examples</SelectLabel>',
     '<SelectLabel className="text-[11px] text-[#6e6e6e] uppercase">{t("listeners.bodyExamples")}</SelectLabel>'),
    ('placeholder="Header-Name"', 'placeholder={t("listeners.headerKeyPlaceholder")}'),
    ('placeholder="value"', 'placeholder={t("listeners.headerValuePlaceholder")}'),
]

# multi-line label blocks
MULTI = [
    ("""                <label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">
                  Listener response
                </label>""",
     """                <label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">
                  {t("listeners.listenerResponse")}
                </label>"""),
    ("""                <label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">
                  Implant request
                </label>""",
     """                <label className="block text-[12px] text-[#6e6e6e] mb-1.5 uppercase tracking-widest">
                  {t("listeners.implantRequest")}
                </label>"""),
    ("                    Add §\n                  </button>",
     '                    {t("listeners.addMarker")}\n                  </button>'),
    ("                    Clear §\n                  </button>",
     '                    {t("listeners.clearMarker")}\n                  </button>'),
]


def patch(filename: str, hook_anchor: str) -> None:
    path = DIR / filename
    src = path.read_text(encoding="utf-8")
    original = src

    for old, new in SUBS + MULTI:
        if old in src:
            src = src.replace(old, new)

    if IMPORT_LINE not in src:
        # insert import after the last existing import block line
        lines = src.splitlines()
        last_import = max(
            i for i, ln in enumerate(lines)
            if ln.startswith("import ") or ln.startswith("} from ")
        )
        lines.insert(last_import + 1, IMPORT_LINE)
        src = "\n".join(lines) + "\n"

    if hook_anchor in src and 'usePanelT("listeners")' not in src:
        src = src.replace(
            hook_anchor,
            hook_anchor + '\n  const t = usePanelT("listeners");',
            1,
        )

    if src != original:
        path.write_text(src, encoding="utf-8")
        print("patched", filename)
    else:
        print("no change", filename)


patch("add-https.tsx", "  const adv = useAdvancedSection(formData, handleFormChange);")
patch(
    "add-file-server.tsx",
    "  } = useAdvancedSection(formData, handleFormChange);",
)
patch("add-http.tsx", "  } = useAdvancedSection(formData, handleFormChange);")
