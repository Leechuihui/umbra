"""Verify every relative markdown link in docs/ and the root READMEs resolves.

Catches broken image paths and dead cross-references before they ship.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Markdown inline links and images: [label](target) / ![alt](target)
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")

TARGETS = [
    ROOT / "README.md",
    ROOT / "README.zh-CN.md",
    ROOT / "docs" / "README.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "USAGE.md",
    ROOT / "docs" / "VIDEO-SCRIPT.md",
]

ok = 0
broken = 0

for doc in TARGETS:
    if not doc.exists():
        print(f"[MISSING DOC] {doc.relative_to(ROOT)}")
        broken += 1
        continue

    text = doc.read_text(encoding="utf-8")
    for match in LINK_RE.finditer(text):
        target = match.group(1).strip()

        # Skip external links, anchors, and mailto
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue

        # Strip any anchor suffix
        path_part = target.split("#", 1)[0]
        if not path_part:
            continue

        resolved = (doc.parent / path_part).resolve()
        if resolved.exists():
            ok += 1
        else:
            print(f"[BROKEN] {doc.relative_to(ROOT)} -> {target}")
            broken += 1

print()
print(f"resolved: {ok}")
print(f"broken:   {broken}")
raise SystemExit(0 if broken == 0 else 1)
