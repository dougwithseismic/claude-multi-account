#!/bin/zsh
# Sets up several Claude desktop accounts side by side (see the README):
#
#   ./install.sh               A, B and C, or every copy profiles.json already lists
#   ./install.sh 4             A to D: adds D to an existing setup
#   ./install.sh --uninstall   takes it out again, keeping each copy's data folder
#
# It never asks for input, so an AI agent can run it, and it's safe to run again: it
# rebuilds the launchers and Claude Notch and keeps profiles.json, settings and logins.
# What macOS keeps for a person (the Keychain prompt, signing in) is listed at the end.
set -euo pipefail
cd "${0:A:h}"

CLAUDE=/Applications/Claude.app
SUPPORT="$HOME/Library/Application Support"
CONFIG="$HOME/.config/claude-multi-account/profiles.json"

step() { print "\n\e[1m==> $*\e[0m" }
fail() { print -u2 "\e[31minstall.sh: $*\e[0m"; exit 1 }
list() { (( $# > 1 )) && print "${(j:, :)@[1,-2]} and ${@[-1]}" || print "$*" }

uninstall() {
  step "Removing Claude Notch"
  apps/notch/scripts/build-app.sh --uninstall

  step "Removing the launchers and profiles.json"
  for app in "$HOME/Applications"/Claude\ ?.app(N); do
    if [[ -f "$app/Contents/Resources/claude-profile.sh" ]]; then rm -rf "$app"; print "  removed ${app:t}"; fi
  done
  rm -rf "${CONFIG:h}"

  local kept=("$SUPPORT"/Claude-[B-Z](N/))
  print "\nUninstalled."
  if (( $#kept )); then
    print "Each extra copy's data folder is still there, so it stays signed in if you reinstall."
    print "To delete them too, which signs those copies out and deletes their settings:\n"
    print "  rm -rf ${(@qqq)kept}"
  fi
}

[[ ${1:-} == --uninstall ]] && { uninstall; exit }
[[ $# -eq 0 || $1 == <2-26> ]] || fail "usage: ./install.sh [number of copies, 2 to 26] | --uninstall"

step "Checking what's needed"
[[ $(uname) == Darwin ]] || fail "this is for macOS"
macos=$(sw_vers -productVersion)
(( ${macos%%.*} >= 26 )) || fail "Claude Notch needs macOS 26 or later"
[[ -d $CLAUDE ]] || fail "install the Claude desktop app in /Applications first: https://claude.ai/download"
xcrun --find swift >/dev/null 2>&1 || fail "install Apple's Command Line Tools first: xcode-select --install"
print "  macOS $macos, Claude.app and Swift found"

step "Profiles: ${CONFIG/#$HOME/~}"
# Starts from files/profiles.json if there's no file, adds any letter the count asks for,
# and prints "letter hotkey" for every copy. An existing file is only ever added to.
mkdir -p "${CONFIG:h}"
profiles=("${(@f)$(osascript -l JavaScript - "$CONFIG" files/profiles.json "${1:-0}" <<'JS'
ObjC.import('Foundation')
ObjC.import('stdlib')
function run([path, template, countArg]) {
  const palette = { D: '#B04FD6', E: '#E5487F', F: '#1FB5C1', G: '#E3B52B', H: '#E5484D' }
  const exists = $.NSFileManager.defaultManager.fileExistsAtPath(path)
  const source = exists ? path : template
  const count = Number(countArg) || (exists ? 0 : 3)
  let profiles = null
  try { profiles = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(source, $.NSUTF8StringEncoding, null))) } catch (e) {}
  if (!Array.isArray(profiles)) {
    console.log(`install.sh: ${source} isn't a JSON list of profiles; fix it or move it aside`) // to stderr
    $.exit(1)
  }
  if (!exists) profiles = profiles.filter(p => p.letter < String.fromCharCode(65 + count))
  const before = profiles.length
  const letters = new Set(profiles.map(p => p.letter))
  const hotkeys = new Set(profiles.map(p => p.hotkey))
  for (let i = 0; i < count; i++) {
    const letter = String.fromCharCode(65 + i)
    if (letters.has(letter)) continue
    const profile = { letter, label: `Claude ${letter}`, color: palette[letter] || '#B3B3B3' }
    if (i < 9 && !hotkeys.has(String(i + 1))) profile.hotkey = String(i + 1)
    profiles.push(profile)
  }
  if (!exists || profiles.length > before) {
    // One profile to a line, like files/profiles.json.
    const line = p => `  { ${Object.entries(p).map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ')} }`
    const text = `[\n${profiles.map(line).join(',\n')}\n]\n`
    $(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)
  }
  return profiles.filter(p => /^[A-Z]$/.test(p.letter)).map(p => `${p.letter} ${p.hotkey || ''}`).join('\n')
}
JS
)}")
typeset -A hotkey
for line in $profiles; do hotkey[${line%% *}]=${line#* }; done
letters=(${(ko)hotkey})
(( $#letters )) || fail "no profiles in $CONFIG"
print "  copies: $(list $letters)"

step "Data folders"
for X in $letters; do
  [[ $X == A ]] && continue
  dir="$SUPPORT/Claude-$X"
  if [[ -d $dir ]]; then print "  ${dir/#$HOME/~} (already there)"; continue; fi
  mkdir -p -m 700 "$dir"
  # A new copy starts with A's app preferences, never A's login (that's config.json).
  for file in claude_desktop_config.json developer_settings.json; do
    if [[ -f "$SUPPORT/Claude/$file" ]]; then cp -p "$SUPPORT/Claude/$file" "$dir/"; fi
  done
  print "  ${dir/#$HOME/~} (new)"
done

step "Launchers in ~/Applications"
# Small apps that bring a copy to the front, or start it, so Spotlight, Raycast, the Dock
# and Claude Notch never start a second copy on the same folder. LSUIElement keeps them
# out of the Dock; editing Info.plist breaks osacompile's signature, hence the re-sign.
icon=$(/usr/libexec/PlistBuddy -c "Print CFBundleIconFile" "$CLAUDE/Contents/Info.plist")
icon="$CLAUDE/Contents/Resources/${icon%.icns}.icns"
mkdir -p "$HOME/Applications"
for X in $letters; do
  app="$HOME/Applications/Claude $X.app"
  rm -rf "$app"
  osacompile -o "$app" -e "do shell script quoted form of (POSIX path of (path to me)) & \"Contents/Resources/claude-profile.sh $X\"" 2>/dev/null \
    || fail "couldn't build $app"
  install -m 755 files/claude-profile.sh "$app/Contents/Resources/claude-profile.sh"
  cp "$icon" "$app/Contents/Resources/applet.icns"
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$app/Contents/Info.plist"
  codesign --force --deep -s - "$app" 2>/dev/null || fail "couldn't sign $app"
  print "  Claude $X.app"
done

step "Building and installing Claude Notch (the first build takes a minute or two)"
apps/notch/scripts/build-app.sh --install

if [[ -d "$HOME/Applications/Claude Link Router.app" ]]; then
  print "\nAn older Claude Link Router is installed. See \"Moving from Hammerspoon\" in the README."
fi

# Copies with no login yet, from their config.json (no Keychain, no network).
signedin=(${=$(apps/notch/build/claude-usage --signed-in)})
signin=(${letters:|signedin})
key() { [[ -n ${hotkey[$1]} ]] && print "press ⌥⌘${hotkey[$1]}" || print "open ~/Applications/Claude $1.app" }

print "\n\e[1mInstalled.\e[0m Claude Notch is beside the notch: rest the pointer on it to see every account."
print "\nWhat's left needs you at the keyboard; macOS won't let a script do it:\n"
print "  - If macOS asks to let Claude Notch use \"Claude Safe Storage\" in your Keychain, enter"
print "    your login password and click Always Allow. It reads each copy's login to check usage."
if (( $#signin )); then
  (( $#signin > 1 )) && print "  - Sign in to Claude $(list $signin), one at a time:" || print "  - Sign in to Claude $signin:"
  print "      $(key $signin[1]) (Claude $signin[1]), click sign in and finish in the browser, and allow it"
  print "      to open Claude. The login goes to the Claude you used last, so don't click into another"
  print "      Claude until it's done. The first time, macOS asks whether \"Claude Notch\" may control"
  print "      \"Claude\": click Allow."
  for X in $signin[2,-1]; do print "      Then $(key $X) for Claude $X."; done
fi
shortcuts=()
for X in $letters; do
  if [[ -n ${hotkey[$X]} ]]; then shortcuts+="⌥⌘${hotkey[$X]}"; fi
done
print "\nFrom now on, open Claude with $(list $shortcuts) or the Claude $(list $letters) apps in ~/Applications,"
print "not Claude.app itself: that would start a second copy on Claude A's folder."
