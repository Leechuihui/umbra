#!/usr/bin/env bash
# Convert UMBRA diagrams from SVG to PNG using ImageMagick on Kali.
# Output goes to /tmp/umbra-png/ so it can be copied back to the host.

set -uo pipefail

SRC=/tmp/umbra-svg
OUT=/tmp/umbra-png

mkdir -p "$OUT"
rm -f "$OUT"/*.png

if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  echo "no imagemagick"
  exit 1
fi

CONV="$(command -v magick || command -v convert)"
echo "converter: $CONV"
echo

ok=0
fail=0

for svg in "$SRC"/*.svg; do
  [[ -f "$svg" ]] || continue
  name="$(basename "$svg" .svg)"
  png="$OUT/$name.png"

  # High density for crisp text, dark background to match the theme.
  "$CONV" -background '#0a0a0a' -density 200 "$svg" \
    -resize 2400x -flatten "$png" 2>/tmp/magick-err.log

  if [[ -s "$png" ]]; then
    echo "  [OK]   $name.png  ($(du -h "$png" | cut -f1))"
    ok=$((ok+1))
  else
    echo "  [FAIL] $name"
    head -3 /tmp/magick-err.log | sed 's/^/         /'
    fail=$((fail+1))
  fi
done

echo
echo "converted: $ok   failed: $fail"
ls -lh "$OUT" 2>/dev/null | tail -n +2
