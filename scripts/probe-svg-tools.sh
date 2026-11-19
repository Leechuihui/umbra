#!/usr/bin/env bash
# Probe for an SVG-to-PNG converter on this host.

for t in rsvg-convert inkscape magick convert chromium google-chrome; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t -> $(command -v "$t")"
  else
    echo "[--] $t"
  fi
done

echo "--- python modules ---"
for m in cairosvg svglib PIL; do
  if python3 -c "import $m" 2>/dev/null; then
    echo "[OK] $m"
  else
    echo "[--] $m"
  fi
done
