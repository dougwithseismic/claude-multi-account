#!/bin/zsh
# Sets up several Claude desktop accounts side by side (see the README):
#
#   ./install.sh                A, B and C, or every copy profiles.json already lists
#   ./install.sh 4              A to D: adds D to an existing setup
#   ./install.sh --statusline   adds every copy's usage to Claude Code's status line
#   ./install.sh --claude-code  claude-a, claude-b, …: Claude Code in the terminal with each copy's own login
#   ./install.sh --chrome       Claude in Chrome for every copy's Code sessions, through claude-chrome-relay
#   ./install.sh --doctor       checks the setup and says how to fix what's wrong; changes nothing
#   ./install.sh --uninstall    takes it out again, keeping each copy's data folder
#
# It never asks for input, so an AI agent can run it, and it's safe to run again: it
# rebuilds the launchers and Claude Notch and keeps profiles.json, settings and logins.
# What macOS keeps for a person (the Keychain prompt, signing in) is listed at the end.
set -euo pipefail
cd "${0:A:h}"

CLAUDE=/Applications/Claude.app
SUPPORT="$HOME/Library/Application Support"
CONFIG="$HOME/.config/claude-multi-account/profiles.json"
# The claude-usage command, linked into ~/.local/bin when that folder exists.
CLI="$PWD/apps/notch/build/claude-usage"
LINK="$HOME/.local/bin/claude-usage"
# Claude Code's own settings, where its status line is set.
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
# Claude Code's usual folder, A's. claude-b runs Claude Code on ~/.claude-B, which links to
# these from here so every login has the same setup; its login and history are its own.
CODE="$HOME/.claude"
SHARED=(settings.json CLAUDE.md skills agents commands plugins)
# In every claude-a, claude-b… we write, so we only ever change or remove our own.
MARK="made by claude-multi-account's install.sh --claude-code"
# The MCP server that gives every copy the Claude in Chrome tools, and its name in Claude Code.
RELAY="$PWD/apps/notch/build/claude-chrome-relay"
SERVER=chrome-relay

step() { print "\n\e[1m==> $*\e[0m" }
fail() { print -u2 "\e[31minstall.sh: $*\e[0m"; exit 1 }
list() { (( $# > 1 )) && print "${(j:, :)@[1,-2]} and ${@[-1]}" || print "$*" }
indent() { local nl=$'\n'; print -r -- "  ${1//$nl/$nl  }" }
linked() { [[ -L $LINK && $(readlink "$LINK") == $CLI ]] }

link_cli() {
  if [[ ! -d ${LINK:h} ]]; then
    print "  ${CLI/#$HOME/\~} (there's no ~/.local/bin to link it into)"
  elif [[ -e $LINK || -L $LINK ]] && ! linked; then
    print "  ${LINK/#$HOME/\~} is something else already, so it's left alone: ${CLI/#$HOME/\~}"
  else
    ln -sfn "$CLI" "$LINK"
    print "  ${LINK/#$HOME/\~} -> ${CLI/#$HOME/\~}"
    (( ${path[(Ie)${LINK:h}]} )) || print "  ~/.local/bin isn't on your PATH, so run it as ~/.local/bin/claude-usage"
  fi
}

# Adds `claude-usage --statusline` to Claude Code's settings.json when it has no status
# line yet; one that's there already is never replaced (claude-usage says what to change).
statusline() {
  # A build from before 0.5 has no status line.
  if [[ ! -x $CLI || $("$CLI" --help 2>/dev/null) != *--statusline* ]]; then
    step "Building claude-usage"
    apps/notch/scripts/build-app.sh
  fi
  step "claude-usage"
  link_cli
  step "Claude Code's status line: ${SETTINGS/#$HOME/\~}"
  local cmd=$CLI result code=0
  if linked; then cmd=$LINK; fi
  result=$("$CLI" --add-statusline "$SETTINGS" "${(q-)cmd} --statusline" 2>&1) || code=$?
  indent "$result"
  case $code in
    0) print "\nClaude Code shows it under the prompt in each session, from the session's next answer: every"
       print "copy's letter, its 5-hour · weekly percentages, red from 90%, ✕ when used up, ▸ for the one in front." ;;
    3) ;; # Another status line is set; claude-usage said what's there and what to set.
    *) fail "couldn't add the status line" ;;
  esac
  # The numbers come from what Claude Notch 0.5 or later shares after each read.
  local version
  version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$HOME/Applications/Claude Notch.app/Contents/Info.plist" 2>/dev/null) || version=
  autoload -Uz is-at-least
  if [[ -z $version ]]; then
    print "\nClaude Notch reads the numbers it shows, and it isn't installed: run ./install.sh too."
  elif ! is-at-least 0.5 $version; then
    print "\nClaude Notch $version doesn't share its numbers yet: run ./install.sh to update it."
  fi
}

ours() { [[ -f $1 ]] && grep -qsF -- "$MARK" "$1" }

# claude-a, claude-b, … in ~/.local/bin, one per copy in profiles.json: Claude Code in the
# terminal with that copy's own login. claude-a is Claude Code as usual, on ~/.claude.
claude_code() {
  local bin=${LINK:h}
  [[ -f $CONFIG ]] || fail "there's no profiles.json yet, so run ./install.sh first"
  [[ -d $bin ]] || fail "the commands go in ~/.local/bin, which isn't there: mkdir -p ~/.local/bin, put it on your PATH, and run this again"
  local letters=(${(f)"$(osascript -l JavaScript - "$CONFIG" <<'JS'
ObjC.import('Foundation')
function run([path]) {
  let profiles = []
  try { profiles = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null))) } catch (e) {}
  return (Array.isArray(profiles) ? profiles : []).map(p => p && p.letter).filter(l => typeof l === 'string' && /^[A-Z]$/.test(l)).join('\n')
}
JS
)"})
  (( $#letters )) || fail "no profiles in $CONFIG"

  step "Claude Code in the terminal, one login per copy"
  local X x cmd dir item made=()
  local -a shared
  for X in $letters; do
    x=${(L)X}
    cmd="$bin/claude-$x"
    if [[ -e $cmd || -L $cmd ]] && ! ours "$cmd"; then
      print "  ${cmd/#$HOME/\~} is something else already, so it's left alone"
      continue
    fi
    if [[ $X == A ]]; then
      print -r -- "#!/bin/sh
# claude-a: Claude Code with Claude A's login, in ~/.claude as usual; $MARK.
unset CLAUDE_CONFIG_DIR
exec claude \"\$@\"" >| $cmd
      dir=$CODE
      shared=()
    else
      dir="$HOME/.claude-$X"
      [[ -d $dir ]] || mkdir -m 700 "$dir"
      shared=()
      for item in $SHARED; do
        # Never over anything already in the folder.
        if [[ -e $CODE/$item && ! -e $dir/$item && ! -L $dir/$item ]]; then ln -s "$CODE/$item" "$dir/$item"; fi
        if [[ -L $dir/$item && $(readlink "$dir/$item") == $CODE/$item ]]; then shared+=$item; fi
      done
      print -r -- "#!/bin/sh
# claude-$x: Claude Code with Claude $X's login, in ~/.claude-$X; $MARK.
export CLAUDE_CONFIG_DIR=\"\$HOME/.claude-$X\"
exec claude \"\$@\"" >| $cmd
    fi
    chmod 755 $cmd
    made+=claude-$x
    print "  claude-$x: ${dir/#$HOME/\~}${shared:+, with ~/.claude's ${(j:, :)shared}}"
  done
  (( $#made )) || return 0

  (( ${path[(Ie)$bin]} )) || print "\n~/.local/bin isn't on your PATH, so type ~/.local/bin/claude-b and so on, or add it."
  (( $+commands[claude] )) || print "\nClaude Code isn't on your PATH. Install it first: https://code.claude.com/docs/en/setup"
  local others=(${made:#claude-a})
  if (( $#others )); then
    print "\nRun $(list $others) once each and sign in with that copy's account; Claude Code asks the"
    print "first time. claude-a is the Claude Code you have now."
    print "What's listed after each folder links to ~/.claude's, so every login has the same setup;"
    print "each login and its history are its own."
    if grep -qs -- 'claude-usage.*--statusline' "$SETTINGS"; then
      print "In the status line, a ${others[1]} session's own limits read \"Code ${(U)others[1]#claude-}\"."
    fi
  fi
}

# The Claude Code folders the relay goes in: "" for ~/.claude (every desktop copy's Code
# tab and claude-a), then ~/.claude-B and so on for each claude-b… we made.
code_dirs() {
  print -r -- ""
  local cmd
  for cmd in ${LINK:h}/claude-[b-z](N); do
    if ours "$cmd" && [[ -d $HOME/.claude-${(U)${cmd:t}#claude-} ]]; then print -r -- "$HOME/.claude-${(U)${cmd:t}#claude-}"; fi
  done
}

# Claude Code on folder $1 ("" for ~/.claude), whatever this shell's CLAUDE_CONFIG_DIR is.
# Never reads this script's stdin, which is the script itself under curl | zsh.
code_in() {
  local dir=$1; shift
  if [[ -n $dir ]]; then CLAUDE_CONFIG_DIR=$dir claude "$@" </dev/null
  else env -u CLAUDE_CONFIG_DIR claude "$@" </dev/null; fi
}

# The command folder $1's "chrome-relay" MCP server runs, from its .claude.json; nothing
# when there's none. Read directly, as `claude mcp get` would start the server to check it.
relay_in() {
  local file=${1:-$HOME}/.claude.json
  [[ -f $file ]] || return 0
  osascript -l JavaScript - "$file" "$SERVER" <<'JS'
ObjC.import('Foundation')
function run([path, name]) {
  try {
    const config = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null)))
    const server = config && config.mcpServers && config.mcpServers[name]
    return server ? String(server.command || '?') : ''
  } catch (e) { return '' }
}
JS
}

# Whether ~/.claude has our relay, so a plain ./install.sh keeps it up to date.
relay_set_up() { [[ $(relay_in "") == */claude-chrome-relay ]] }

# Adds claude-chrome-relay to Claude Code as a user-wide MCP server, in ~/.claude and each
# claude-b…'s folder. One that runs another copy of the relay (an older checkout) is moved
# to this one; a different server that happens to be called chrome-relay is left alone.
chrome() {
  if [[ ! -x $RELAY || $("$RELAY" --version 2>/dev/null) != "claude-chrome-relay "* ]]; then
    step "Building claude-chrome-relay"
    apps/notch/scripts/build-app.sh
  fi
  step "Claude in Chrome for every copy: claude-chrome-relay"
  if (( ! $+commands[claude] )); then
    print "  Claude Code isn't on your PATH, so it can't be added for you. Install Claude Code"
    print "  (https://code.claude.com/docs/en/setup) and run this again, or add it by hand:\n"
    print "  claude mcp add --scope user $SERVER -- ${(q-)RELAY}"
    return 0
  fi
  local dir have name added=0
  for dir in "${(@f)$(code_dirs)}"; do
    name=${${dir:-~/.claude}/#$HOME/\~}
    have=$(relay_in "$dir")
    if [[ $have == $RELAY ]]; then print "  $name: already has it"; continue; fi
    if [[ -n $have && $have != */claude-chrome-relay ]]; then
      print "  $name: another MCP server is called $SERVER ($have), so it's left alone"
      continue
    fi
    [[ -z $have ]] || code_in "$dir" mcp remove --scope user $SERVER >/dev/null 2>&1 || true
    if code_in "$dir" mcp add --scope user $SERVER -- "$RELAY" >/dev/null 2>&1; then
      print "  $name: added${have:+ (it ran ${have/#$HOME/\~} before)}"
      added=1
    else
      print "  $name: couldn't add it; run this to see why: claude mcp add --scope user $SERVER -- ${(q-)RELAY}"
    fi
  done
  (( added )) || return 0
  local access=on
  [[ -e ${CONFIG:h}/chrome-off ]] && access=off
  print "\nNew Code sessions in every copy have the Chrome tools (sessions already open need restarting)."
  print "Each session works in its own tab group in Chrome, named after its copy. Chrome must be"
  print "open with the Claude extension installed. Any copy can now drive your Chrome profile,"
  print "signed-in sites included; Chrome access in Claude Notch's settings turns it off for"
  print "every copy at once (it's $access now)."
}

uninstall() {
  step "Removing Claude Notch"
  apps/notch/scripts/build-app.sh --uninstall

  step "Removing claude-usage's link, its status line, the usage snapshot, claude-chrome-relay and claude-a, claude-b…"
  if linked; then rm "$LINK"; print "  removed ${LINK/#$HOME/\~}"; fi
  # Only a status line that runs claude-usage; another one stays.
  if [[ -f $SETTINGS && -x $CLI ]]; then
    local result
    result=$("$CLI" --remove-statusline "$SETTINGS" 2>&1) || true
    if [[ -n $result ]]; then indent "$result"; fi
  elif grep -qs -- 'claude-usage.*--statusline' "$SETTINGS"; then
    print "  ${SETTINGS/#$HOME/\~} still runs claude-usage for its status line, and claude-usage isn't built"
    print "  here to take it out: remove the \"statusLine\" entry by hand."
  fi
  rm -rf "$HOME/Library/Caches/claude-multi-account"

  # Before the claude-b… commands go, as they say which folders are ours.
  local dir have
  for dir in "${(@f)$(code_dirs)}"; do
    have=$(relay_in "$dir")
    [[ $have == */claude-chrome-relay ]] || continue
    if (( $+commands[claude] )) && code_in "$dir" mcp remove --scope user $SERVER >/dev/null 2>&1; then
      print "  removed claude-chrome-relay from ${${dir:-~/.claude}/#$HOME/\~}"
    else
      print "  couldn't remove claude-chrome-relay from ${${dir:-~/.claude}/#$HOME/\~}: claude mcp remove --scope user $SERVER"
    fi
  done
  # Relays in sessions that are still open would keep working, and with profiles.json's
  # folder gone so is the switch that turns them off.
  if pkill -U $UID -x claude-chrome-relay 2>/dev/null; then print "  stopped claude-chrome-relay in the Code sessions still open"; fi

  local cmd
  for cmd in ${LINK:h}/claude-[a-z](N); do
    if ours "$cmd"; then rm "$cmd"; print "  removed ${cmd/#$HOME/\~}"; fi
  done
  local code=("$HOME"/.claude-[A-Z](N/))

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
  if (( $#code )); then
    print "\nClaude Code's folders for the extra copies are still there too, with their logins and history:\n"
    print "  rm -rf ${(@qqq)code}"
  fi
}

[[ ${1:-} == --doctor ]] && exec scripts/doctor.sh

# One run at a time: two would race over the launchers and the app they each replace.
zmodload zsh/system
LOCK="${TMPDIR:-/tmp}/claude-multi-account-install.lock"
: >> "$LOCK"
zsystem flock -t 0 "$LOCK" 2>/dev/null || fail "another ./install.sh is running; wait for it to finish"

[[ ${1:-} == --uninstall ]] && { uninstall; exit }
[[ ${1:-} == --statusline ]] && { statusline; exit }
[[ ${1:-} == --claude-code ]] && { claude_code; if relay_set_up; then chrome; fi; exit }
[[ ${1:-} == --chrome ]] && { chrome; exit }
[[ $# -eq 0 || $1 == <2-26> ]] || fail "usage: ./install.sh [number of copies, 2 to 26] | --statusline | --claude-code | --chrome | --doctor | --uninstall"

step "Checking what's needed"
[[ $(uname) == Darwin ]] || fail "this is for macOS"
macos=$(sw_vers -productVersion)
(( ${macos%%.*} >= 26 )) || fail "Claude Notch needs macOS 26 or later"
[[ -d $CLAUDE ]] || fail "install the Claude desktop app in /Applications first: https://claude.ai/download"
if ! xcode-select -p >/dev/null 2>&1; then fail "install Apple's Command Line Tools first: xcode-select --install"; fi
swift=$(xcrun swift -version 2>&1) || fail "the Command Line Tools are there but Swift won't run:
$swift
If it mentions a licence, run: sudo xcodebuild -license accept. Otherwise: sudo xcode-select --reset"
swift=${${swift#*Swift version }%% *}
autoload -Uz is-at-least
is-at-least 6.2 $swift || fail "Claude Notch needs Swift 6.2 or later, and this Mac has $swift. Update the Command Line Tools in System Settings → General → Software Update, or run: xcode-select --install"
print "  macOS $macos, Claude.app and Swift $swift found"

step "Profiles: ${CONFIG/#$HOME/\~}"
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
  if [[ -d $dir ]]; then print "  ${dir/#$HOME/\~} (already there)"; continue; fi
  mkdir -p -m 700 "$dir"
  # A new copy starts with A's app preferences, never A's login (that's config.json).
  for file in claude_desktop_config.json developer_settings.json; do
    if [[ -f "$SUPPORT/Claude/$file" ]]; then cp -p "$SUPPORT/Claude/$file" "$dir/"; fi
  done
  print "  ${dir/#$HOME/\~} (new)"
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
  if [[ -e $app && ! -f $app/Contents/Resources/claude-profile.sh ]]; then
    print "  Claude $X.app is an app of your own, so it's left alone; ⌥⌘ and Claude Notch still work"
    continue
  fi
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

step "claude-usage"
link_cli

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
# Unless a profile has ⌥⌘0 for itself.
if (( ! ${${(v)hotkey}[(Ie)0]} )); then print "⌥⌘0 switches to the copy with the most room."; fi
if ! grep -qs -- 'claude-usage.*--statusline' "$SETTINGS"; then
  print "\nTo see every copy's usage in Claude Code's status line too: ./install.sh --statusline"
fi
# Copies added since --claude-code ran get their command too.
if ours "${LINK:h}/claude-a"; then
  claude_code
elif [[ -d ${LINK:h} ]]; then
  print "For Claude Code in the terminal with each copy's own login (claude-a, claude-b, …): ./install.sh --claude-code"
fi
# And their folders get the relay, once it's set up.
if relay_set_up; then
  chrome
else
  print "For Claude in Chrome in every copy's Code sessions, through one Chrome profile: ./install.sh --chrome"
fi
