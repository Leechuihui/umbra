"""Add an empty-state hint to the listener server dropdown.

The dropdown is fed by config.json's servers array, which only gets an entry
after a successful authentication. When it is empty the Select shows nothing,
which looks broken. This patch adds a disabled placeholder item and a clearer
placeholder text in all four places that render the server select.
"""

from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
COMP = BASE / "src" / "components" / "canva" / "topbar" / "listeners" / "components"

# Files that render a server <Select> for listeners.
TARGETS = [
    COMP / "form.tsx",
    COMP / "add-http.tsx",
    COMP / "add-https.tsx",
    COMP / "add-file-server.tsx",
]

OLD_PLACEHOLDER = 'placeholder={t("listeners.serverPlaceholder")}'
NEW_PLACEHOLDER = (
    'placeholder={\n              servers.length === 0\n'
    '                ? t("listeners.noServers")\n'
    '                : t("listeners.serverPlaceholder")\n'
    '            }'
)

EMPTY_ITEM = (
    '            {servers.length === 0 && (\n'
    '              <SelectItem value="__no_servers" disabled className="text-[13.5px]">\n'
    '                {t("listeners.noServers")}\n'
    '              </SelectItem>\n'
    '            )}\n'
)


def patch(path: Path) -> None:
    if not path.exists():
        print(f"skip (missing): {path.name}")
        return

    src = path.read_text(encoding="utf-8")
    original = src

    # 1. clearer placeholder when there are no servers
    if OLD_PLACEHOLDER in src:
        src = src.replace(OLD_PLACEHOLDER, NEW_PLACEHOLDER, 1)

    # 2. disabled hint item inside the server SelectContent
    #    Anchor on the first SelectContent that follows the server placeholder.
    anchor = '<SelectContent className="text-[13.5px]">'
    idx = src.find(anchor)
    if idx != -1 and "__no_servers" not in src:
        insert_at = idx + len(anchor)
        src = src[:insert_at] + "\n" + EMPTY_ITEM + src[insert_at:]

    if src != original:
        path.write_text(src, encoding="utf-8")
        print(f"patched: {path.name}")
    else:
        print(f"no change: {path.name}")


for target in TARGETS:
    patch(target)
