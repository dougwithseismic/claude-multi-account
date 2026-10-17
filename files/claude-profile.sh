#!/bin/zsh
# Focus the Claude instance for a profile letter, starting it if it isn't running.
# A uses Claude's normal data folder; any other letter X uses "Claude-X".
BIN=/Applications/Claude.app/Contents/MacOS/Claude
case "$1" in
  A) pid=$(pgrep -fx "$BIN" | head -1); args=() ;;
  [B-Z]) dir="$HOME/Library/Application Support/Claude-$1"
     mkdir -p "$dir" && chmod 700 "$dir"
     pid=$(pgrep -fx "$BIN --user-data-dir=$dir" | head -1); args=(--args "--user-data-dir=$dir") ;;
  *) echo "usage: $0 A|B|C|…" >&2; exit 2 ;;
esac
if [[ -n $pid ]]; then
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($pid).activateWithOptions(3)" >/dev/null
else
  open -n -a /Applications/Claude.app $args
fi
