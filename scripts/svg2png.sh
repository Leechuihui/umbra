#!/usr/bin/env bash
# Convert the docs diagrams from SVG to PNG for video editing.
# Tries rsvg-convert, then inkscape, then ImageMagick.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/docs/diagrams"
OUT="$ROOT/docs/diagrams/png"

mkdir -p "$OUT"

CONVERTER=""
if command -v rsvg-convert >/dev/null 2>&1; then
  CONVERTER="rsvg"
elif command -v inkscape >/dev/null 2>&1; then
  CONVERTER="inkscape"
elif command -v magick >/dev/null 2>&1; then
  CONVERTER="magick"
elif command -v convert >/dev/null 2>&1; then
  CONVERTER="convert"
fi

if [[ -z "$CONVERTER" ]]; then
  echo "no SVG converter found (need rsvg-convert, inkscape or imagemagick)"
  exit 1
fi

echo "converter: $CONVERTER"
echo

ok=0
fail=0

for svg in "$SRC"/*.svg; do
  [[ -f "$svg" ]] || continue
  name="$(basename "$svg" .svg)"
  png="$OUT/$name.png"

  case "$CONVERTER" in
    rsvg)
      rsvg-convert -w 2400 -b '#0a0a0a' -o "$png" "$svg" 2>/dev/null
      ;;
    inkscape)
      inkscape "$svg" --export-type=png --export-filename="$png" \
        --export-width=2400 --export-background='#0a0a0a' >/dev/null 2>&1
      ;;
    magick)
      magick -background '#0a0a0a' -density 192 "$svg" -resize 2400x "$png" 2>/dev/null
      ;;
    convert)
      convert -background '#0a0a0a' -density 192 "$svg" -resize 2400x "$png" 2>/dev/null
      ;;
  esac

  if [[ -s "$png" ]]; then
    size="$(du -h "$png" | cut -f1)"
    echo "  [OK]   $name.png  ($size)"
    ok=$((ok+1))
  else
    echo "  [FAIL] $name"
    fail=$((fail+1))
  fi
done

echo
echo "converted: $ok   failed: $fail"
[[ "$fail" -eq 0 ]] && exit 0 || exit 1
