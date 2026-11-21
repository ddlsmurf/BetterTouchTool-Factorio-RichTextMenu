#!/bin/bash
# Exports Factorio's prototype names and icons for the "Factorio Rich Text" BetterTouchTool picker.
# Uses the game's own dump flags (--dump-prototype-locale, --dump-icon-sprites), so mods are included.
# Output: ~/Library/Application Support/factorio/script-output/<type>/<name>.png and <type>-locale.json
#
# Usage:  bash factorio-richtext-setup.sh [path/to/factorio.app/Contents/MacOS/factorio]
# Quit Factorio first. Re-run after adding/removing mods or changing the game language.

set -u

DATA="$HOME/Library/Application Support/factorio"
OUT="$DATA/script-output"
STEAM_GAME="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
STEAM_CLIENT="/Applications/Steam.app/Contents/MacOS/steam_osx"
STEAM_APPID=427520

BIN="${1:-}"
if [ -z "$BIN" ]; then
  for c in "$STEAM_GAME" \
           "/Applications/factorio.app/Contents/MacOS/factorio" \
           "/Applications/Factorio.app/Contents/MacOS/factorio" \
           "$HOME/Applications/factorio.app/Contents/MacOS/factorio"; do
    if [ -x "$c" ]; then BIN="$c"; break; fi
  done
fi
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "Could not find the Factorio executable."
  echo "Pass it explicitly, e.g.: bash $0 /Applications/factorio.app/Contents/MacOS/factorio"
  exit 1
fi
echo "Factorio: $BIN"

if pgrep -x factorio >/dev/null 2>&1; then
  echo "Factorio is running. Quit it and run this script again."
  exit 1
fi

mkdir -p "$OUT"   # --dump-* silently writes nothing if script-output is missing

wait_for_factorio_exit() {
  # wait up to 5 min for the game to start, then until it exits
  local i=0
  while ! pgrep -x factorio >/dev/null 2>&1; do
    i=$((i + 1)); [ "$i" -gt 300 ] && { echo "  Factorio never started."; return 1; }
    sleep 1
  done
  while pgrep -x factorio >/dev/null 2>&1; do sleep 2; done
}

echo "1/2  Names (--dump-prototype-locale)..."
"$BIN" --dump-prototype-locale >/dev/null 2>&1
if ls "$OUT"/*-locale.json >/dev/null 2>&1; then
  echo "     ok: $(find "$OUT" -maxdepth 1 -name '*-locale.json' | wc -l | tr -d ' ') locale files"
else
  echo "     no *-locale.json written. The picker will still work, but show internal names only."
  echo "     Details: $DATA/factorio-current.log"
fi

echo "2/2  Icons (--dump-icon-sprites). Factorio opens a window and closes itself when done..."
if [ "$BIN" = "$STEAM_GAME" ] && [ -x "$STEAM_CLIENT" ]; then
  # Steam build: launch through Steam so the argument survives (same approach as FactorioLab).
  # If Steam asks whether to allow launch arguments, allow it.
  "$STEAM_CLIENT" -applaunch "$STEAM_APPID" --dump-icon-sprites >/dev/null 2>&1 &
  wait_for_factorio_exit
else
  "$BIN" --dump-icon-sprites >/dev/null 2>&1
fi

total=$(find "$OUT" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
if [ "$total" -eq 0 ]; then
  echo "No icons were written. Check $DATA/factorio-current.log"
  echo "Steam users: you can also set the game's Launch Options to --dump-icon-sprites, start it once, then clear them."
  exit 1
fi
echo "Done: $total icons in $OUT"
for d in item entity recipe technology fluid tile virtual-signal item-group achievement shortcut space-location quality; do
  if [ -d "$OUT/$d" ]; then
    printf '  %-15s %s\n' "$d" "$(find "$OUT/$d" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
  fi
done
