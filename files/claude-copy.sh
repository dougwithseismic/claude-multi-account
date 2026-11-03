#!/bin/zsh
# Makes or removes one copy of Claude (see the README). install.sh runs it for every copy in
# profiles.json, and Claude Notch's Copies window for the one being added or removed:
#
#   claude-copy.sh make X           its data folder, and its launcher in ~/Applications
#   claude-copy.sh remove X         its launcher; the data folder stays, so it stays signed in
#   claude-copy.sh remove X --data  its data folder too, which signs it out and deletes its settings
#
# Prints a line for each thing it does, and why it failed on stderr. Safe to run again.
set -euo pipefail

CLAUDE=/Applications/Claude.app
SUPPORT="$HOME/Library/Application Support"
# The launcher's script, beside this one: in files/, or in Claude Notch's Resources.
PROFILE_SCRIPT="${0:A:h}/claude-profile.sh"

fail() { print -u2 "$*"; exit 1 }

[[ $# -ge 2 && $2 == [A-Z] && ( $1 == make || $1 == remove ) ]] || fail "usage: claude-copy.sh make|remove LETTER [--data]"
X=$2
app="$HOME/Applications/Claude $X.app"
dir="$SUPPORT/Claude-$X"

if [[ $1 == remove ]]; then
  [[ $X != A ]] || fail "Claude A is Claude itself, so it can't be removed"
  if [[ ${3:-} == --data ]] && pgrep -U $UID -fx "$CLAUDE/Contents/MacOS/Claude --user-data-dir=$dir" >/dev/null; then
    fail "Claude $X is open: quit it first, then delete its data"
  fi
  # Only a launcher we made; an app of your own by that name stays.
  if [[ -f $app/Contents/Resources/claude-profile.sh ]]; then rm -rf "$app"; print "  removed Claude $X.app"; fi
  if [[ ${3:-} == --data && -d $dir ]]; then rm -rf "$dir"; print "  deleted ${dir/#$HOME/~}"; fi
  exit
fi

[[ -d $CLAUDE ]] || fail "Install the Claude desktop app in /Applications first: https://claude.ai/download"
[[ -f $PROFILE_SCRIPT ]] || fail "claude-profile.sh isn't beside ${0:A}"

if [[ $X != A ]]; then
  if [[ -d $dir ]]; then
    print "  ${dir/#$HOME/~} (already there)"
  else
    mkdir -p -m 700 "$dir"
    # A new copy starts with A's app preferences, never A's login (that's config.json).
    for file in claude_desktop_config.json developer_settings.json; do
      if [[ -f "$SUPPORT/Claude/$file" ]]; then cp -p "$SUPPORT/Claude/$file" "$dir/"; fi
    done
    print "  ${dir/#$HOME/~} (new)"
  fi
fi

# A small app that brings the copy to the front, or starts it, so Spotlight, Raycast, the
# Dock and Claude Notch never start a second copy on the same folder. LSUIElement keeps it
# out of the Dock; editing Info.plist breaks osacompile's signature, hence the re-sign.
if [[ -e $app && ! -f $app/Contents/Resources/claude-profile.sh ]]; then
  print "  Claude $X.app is an app of your own, so it's left alone; ⌥⌘ and Claude Notch still work"
  exit
fi
icon=$(/usr/libexec/PlistBuddy -c "Print CFBundleIconFile" "$CLAUDE/Contents/Info.plist")
icon="$CLAUDE/Contents/Resources/${icon%.icns}.icns"
mkdir -p "$HOME/Applications"
rm -rf "$app"
osacompile -o "$app" -e "do shell script quoted form of (POSIX path of (path to me)) & \"Contents/Resources/claude-profile.sh $X\"" 2>/dev/null \
  || fail "Couldn't build $app"
install -m 755 "$PROFILE_SCRIPT" "$app/Contents/Resources/claude-profile.sh"
cp "$icon" "$app/Contents/Resources/applet.icns"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$app/Contents/Info.plist"
codesign --force --deep -s - "$app" 2>/dev/null || fail "Couldn't sign $app"
print "  Claude $X.app"
