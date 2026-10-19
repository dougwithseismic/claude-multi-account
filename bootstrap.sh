#!/bin/zsh
# Installs Claude Notch from nothing, in one pasted line:
#
#   curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh
#   curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh -s -- 4
#
# The site serves this file as install.sh. It checks the Mac, gets the code into
# ~/claude-multi-account (or updates it, if it's there and unchanged), and runs the real
# install.sh with any arguments it was given. Like install.sh, it never asks for input.
#
# Everything is inside main, run on the last line, so a download cut short runs nothing.

main() {
  set -euo pipefail
  local repo=https://github.com/dougwithseismic/claude-multi-account.git
  local dir=$HOME/claude-multi-account
  local line='curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh'

  step() { print "\n\e[1m==> $*\e[0m" }
  fail() { print -u2 "\e[31m$*\e[0m"; exit 1 }

  step "Checking what's needed"
  [[ $(uname) == Darwin ]] || fail "Claude Notch is for macOS."
  local macos=$(sw_vers -productVersion)
  (( ${macos%%.*} >= 26 )) || fail "Claude Notch needs macOS 26 or later; this Mac has $macos."
  [[ -d /Applications/Claude.app ]] \
    || fail "Install the Claude desktop app in /Applications first: https://claude.ai/download"
  # git and Swift both come with Apple's Command Line Tools. Without them /usr/bin/git
  # only offers to install them, so check before using it.
  if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swift >/dev/null 2>&1; then
    xcode-select --install 2>/dev/null || true
    print "\nClaude Notch is built on this Mac, which needs Apple's Command Line Tools."
    print "Their installer should be open now. When it's done, run this line again:\n"
    print "  $line"
    exit 1
  fi
  print "  macOS $macos, Claude.app and the Command Line Tools found"

  if [[ ! -e $dir ]]; then
    step "Getting the code into ~/claude-multi-account"
    git clone --quiet "$repo" "$dir"
  elif [[ ! -x $dir/install.sh ]] || ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    fail "~/claude-multi-account is there but isn't a copy of Claude Notch. Move it aside and run this again."
  elif [[ -n $(git -C "$dir" status --porcelain) ]]; then
    step "Using ~/claude-multi-account as it is"
    print "  It has changes of its own, so it wasn't updated. To update it, commit or undo"
    print "  them, then run this again."
  else
    step "Updating ~/claude-multi-account"
    git -C "$dir" pull --quiet --ff-only \
      || fail "Couldn't update ~/claude-multi-account; run git pull in it to see why."
    print "  $(git -C "$dir" log -1 --format='%h %s')"
  fi

  exec "$dir/install.sh" "$@"
}

main "$@"
