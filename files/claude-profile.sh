#!/bin/zsh
# Focus the Claude instance for profile A (default data dir) or B (Claude-B), starting it if it isn't running.
BIN=/Applications/Claude.app/Contents/MacOS/Claude
case "$1" in
  A) pid=$(pgrep -fx "$BIN" | head -1); args=() ;;
  B) dir="$HOME/Library/Application Support/Claude-B"
     pid=$(pgrep -fx "$BIN --user-data-dir=$dir" | head -1); args=(--args "--user-data-dir=$dir") ;;
  *) echo "usage: $0 A|B" >&2; exit 2 ;;
esac
if [[ -n $pid ]]; then
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($pid).activateWithOptions(3)" >/dev/null
else
  open -n -a /Applications/Claude.app $args
fi
