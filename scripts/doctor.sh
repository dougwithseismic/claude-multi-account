#!/bin/zsh
# ./install.sh --doctor: checks the setup and changes nothing. Each line is a tick, a
# cross with how to fix it, or a dash for something that's up to you. Exits 0 when there's
# no cross, 1 otherwise. Never touches the Keychain's secrets or the network.
set -uo pipefail
cd "${0:A:h}/.."
autoload -Uz is-at-least
zmodload -F zsh/stat b:zstat
zmodload zsh/datetime

CLAUDE=/Applications/Claude.app
BIN=$CLAUDE/Contents/MacOS/Claude
SUPPORT="$HOME/Library/Application Support"
CONFIG="$HOME/.config/claude-multi-account/profiles.json"
NOTCH="$HOME/Applications/Claude Notch.app"
SNAPSHOT="$HOME/Library/Caches/claude-multi-account/usage.json"
# The one this checkout built, else one on the PATH.
CLI=apps/notch/build/claude-usage
[[ -x $CLI ]] || CLI=${commands[claude-usage]:-$CLI}
here=${PWD/#$HOME/~}

problems=0
section() { print "\n\e[1m==> $*\e[0m" }
ok() { print "  \e[32m✓\e[0m $1" }
bad() { print "  \e[31m✗\e[0m $1"; [[ -n ${2:-} ]] && print "      $2"; (( problems += 1 )) }
note() { print "  \e[2m–\e[0m $1"; [[ -n ${2:-} ]] && print "      \e[2m$2\e[0m"; return 0 }
list() { (( $# > 1 )) && print "${(j:, :)@[1,-2]} and ${@[-1]}" || print "$*" }
version() { defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null }
ago() { (( $1 < 60 )) && print "${1}s" || { (( $1 < 3600 )) && print "$(( $1 / 60 ))m" || print "$(( $1 / 3600 ))h $(( $1 % 3600 / 60 ))m" } }

section "This Mac"
macos=$(sw_vers -productVersion)
if (( ${macos%%.*} >= 26 )); then ok "macOS $macos"; else bad "macOS $macos" "Claude Notch needs macOS 26 or later."; fi
if [[ -d $CLAUDE ]]; then ok "Claude.app $(version $CLAUDE)"
else bad "Claude.app isn't in /Applications" "Install it from https://claude.ai/download"; fi
if xcode-select -p >/dev/null 2>&1 && xcrun --find swift >/dev/null 2>&1; then
  ok "Swift, from Apple's Command Line Tools"
else
  bad "No Swift, so Claude Notch can't be built" "Install Apple's Command Line Tools: xcode-select --install"
fi

# profiles.json, read the way the app reads it: an entry without a single capital letter
# is skipped, and a colour that isn't #RRGGBB is drawn grey. Prints "! problem" lines,
# then "letter hotkey" for each profile.
typeset -A hotkey
letters=()
if [[ ! -f $CONFIG ]]; then
  bad "No profiles.json" "Run ./install.sh to make one."
else
  out=("${(@f)$(osascript -l JavaScript - "$CONFIG" <<'JS'
ObjC.import('Foundation')
function run([path]) {
  let profiles
  try { profiles = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null))) } catch (e) {}
  if (!Array.isArray(profiles)) return "! isn't a JSON list of profiles, so the app uses A, B and C instead"
  const problems = [], lines = [], letters = new Set(), keys = new Map()
  profiles.forEach((p, i) => {
    const letter = p && p.letter
    if (typeof letter !== 'string' || !/^[A-Z]$/.test(letter)) return problems.push(`! entry ${i + 1} has no single capital "letter", so it's skipped`)
    if (letters.has(letter)) return problems.push(`! ${letter} is listed twice`)
    letters.add(letter)
    if (p.color != null && !/^#?[0-9a-fA-F]{6}$/.test(p.color)) problems.push(`! ${letter}'s colour "${p.color}" isn't like #2F7BF5, so it's drawn grey`)
    let key = ''
    if (p.hotkey != null) {
      if (typeof p.hotkey !== 'string' || p.hotkey.length !== 1) problems.push(`! ${letter}'s hotkey "${p.hotkey}" isn't one key, so it has none`)
      else {
        key = p.hotkey.toUpperCase()
        if (keys.has(key)) problems.push(`! ${keys.get(key)} and ${letter} both have ⌥⌘${key}`)
        keys.set(key, letter)
      }
    }
    lines.push(`${letter} ${key}`)
  })
  return [...problems, ...lines].join('\n')
}
JS
)}")
  before=$problems
  for line in $out; do
    if [[ $line == '! '* ]]; then bad "profiles.json: ${line#! }"
    else hotkey[${line%% *}]=${line#* }; letters+=${line%% *}; fi
  done
  (( problems > before )) && print "      Fix it in ${CONFIG/#$HOME/~}, or move it aside and run ./install.sh for a fresh one."
  (( $#letters )) && ok "profiles.json: $(list $letters)"
fi

section "Copies"
signedin=()
if [[ -x $CLI ]]; then signedin=(${=$($CLI --signed-in 2>/dev/null)})
else note "Can't tell which copies are signed in until Claude Notch is built" "Run ./install.sh."; fi
key() { [[ -n ${hotkey[$1]:-} ]] && print "press ⌥⌘${hotkey[$1]}" || print "open ~/Applications/Claude $1.app" }

for X in $letters; do
  [[ $X == A ]] && dir="$SUPPORT/Claude" || dir="$SUPPORT/Claude-$X"
  launcher="$HOME/Applications/Claude $X.app/Contents/Resources/claude-profile.sh"
  fine=1
  if [[ ! -d $dir ]]; then
    fine=0
    [[ $X == A ]] && bad "Claude A has no data folder yet" "Open Claude.app once." \
      || bad "Claude $X has no data folder" "Run ./install.sh to make it."
  fi
  if [[ ! -f $launcher ]]; then fine=0; bad "Claude $X has no launcher in ~/Applications" "Run ./install.sh to build it."
  elif ! cmp -s "$launcher" files/claude-profile.sh; then fine=0; bad "Claude $X's launcher is out of date" "Run ./install.sh to rebuild it."; fi
  login=
  if [[ -x $CLI && -d $dir ]]; then
    if (( ${signedin[(Ie)$X]} )); then login=", signed in"
    else fine=0; k=$(key $X); bad "Claude $X isn't signed in" "${(U)k[1]}${k[2,-1]}, click sign in and finish in the browser."; fi
  fi
  (( fine )) && ok "Claude $X: data folder, launcher$login"
done

# Each running copy, by the data folder it was started on. Two on one folder fight over it.
typeset -A open
for args in ${(f)"$(ps -axwwo args=)"}; do
  [[ $args == "$BIN" || $args == "$BIN "* ]] || continue
  folder=Claude
  [[ $args == *--user-data-dir=* ]] && folder=${${${args#*--user-data-dir=}%% --*}:t}
  [[ $folder == Claude ]] && X=A || X=${folder#Claude-}
  open[$X]=$(( ${open[$X]:-0} + 1 ))
done
twice=(${(k)open[(R)<2->]})
running=(${(ko)open})
if (( $#twice )); then
  for X in ${(o)twice}; do bad "Claude $X is open twice on the same folder" "Quit both (⌘Q), then $(key $X)."; done
elif (( $#running )); then ok "Open: Claude $(list $running), once each"
else note "No copy of Claude is open"; fi

section "Claude Notch"
want=$(sed -n 's/.*CFBundleShortVersionString<\/key><string>\([^<]*\)<.*/\1/p' apps/notch/scripts/build-app.sh)
have=$(version $NOTCH)
if [[ -z $have ]]; then
  bad "Not installed in ~/Applications" "Run ./install.sh."
else
  if [[ $have == $want ]]; then ok "$have, in ~/Applications"
  else bad "$have is installed; this copy of the code ($here) is $want" "Run ./install.sh to update it."; fi
  if pgrep -qx ClaudeNotch; then ok "Running"
  else bad "Not running" "Open it: open ~/Applications/Claude\\ Notch.app"; fi

  # Older builds don't know --login-item and would start instead of answering.
  if is-at-least 0.5 $have; then
    case $("$NOTCH/Contents/MacOS/ClaudeNotch" --login-item 2>/dev/null) in
      enabled) ok "Opens at login" ;;
      requiresApproval) bad "Opening at login is waiting for your OK" "System Settings → General → Login Items: turn on Claude Notch." ;;
      *) note "Doesn't open at login" "Turn it on in Claude Notch's settings (the gear) if you want it to." ;;
    esac
  fi

  handler=$(osascript -l JavaScript - 2>/dev/null <<'JS'
ObjC.import('AppKit')
const app = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString('claude://'))
app.isNil() ? '' : app.path.js
JS
)
  if [[ ${handler:A} == ${NOTCH:A} ]]; then ok "claude:// links (sign-in) go to Claude Notch, which passes them on"
  else bad "claude:// links go to ${${handler:t}:-nothing}, so sign-in can reach the wrong copy" "Open Claude Notch; it takes them back when it starts."; fi

  if is-at-least 0.5 $have; then
    if [[ -f $SNAPSHOT ]]; then
      age=$(( EPOCHSECONDS - $(zstat +mtime $SNAPSHOT) ))
      if (( age <= 15 * 60 )); then ok "Usage last read $(ago $age) ago"
      else bad "Usage last read $(ago $age) ago" "Claude Notch reads it every 5 minutes while it's open and online."; fi
    else
      bad "No usage read yet" "Claude Notch writes ${SNAPSHOT/#$HOME/~} after its first read; check it's open."
    fi
  fi
fi

# Only whether the item is there: without -g or -w, security doesn't read the secret.
if security find-generic-password -s "Claude Safe Storage" >/dev/null 2>&1; then
  ok "\"Claude Safe Storage\" is in the Keychain"
else
  bad "No \"Claude Safe Storage\" in the Keychain" "Open Claude A and sign in; Claude makes it."
fi

if command -v claude-usage >/dev/null; then ok "claude-usage is on your PATH"
else note "claude-usage isn't on your PATH" "It's in $here/apps/notch/build. To type just claude-usage, make ~/.local/bin, put it on your PATH, and run ./install.sh again."; fi

if (( problems )); then
  print "\n\e[1m$problems to fix.\e[0m Each ✗ says how."
  exit 1
fi
print "\n\e[1mEverything looks right.\e[0m"
