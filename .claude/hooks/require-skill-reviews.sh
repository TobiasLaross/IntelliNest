#!/usr/bin/env bash
# Claude Code PreToolUse gate.
#
# Blocks `gh pr create` until the Swift review skills have been run on the branch
# diff and their findings addressed:
#   /swiftui-pro  /swift-concurrency-pro  /swift-safety  /swift-accessibility-skill
#
# Only for a diff that carries Swift — see `changed_files` below.
#
# The hook can't run a Claude skill itself (skills need the model), so it gates
# the PR-open step and hands control back to the agent with instructions. Once
# the reviews are done, re-run the command prefixed with REVIEWS_DONE=1 to pass.
#
# Wired up in .claude/settings.json as a PreToolUse hook on the Bash tool.
# Ported from gto-poker-ios's Scripts/require-skill-reviews.sh; keep the two in step.
set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Only gate PR creation; every other Bash call passes straight through.
case "$command" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

# Explicit acknowledgement that the reviews ran and findings were addressed.
if printf '%s' "$command" | grep -q 'REVIEWS_DONE=1'; then
  exit 0
fi

# Where the command will actually run its git. A hook runs in the session's working
# directory, but this repo opens every PR from a sibling worktree reached by a `cd` on
# the same command line, so the session's directory is the main checkout with a clean
# tree — which carries no Swift and waved every worktree PR straight through. Follow
# the command's own `cd` instead, and refuse to guess when it needs a shell to resolve.
command_dir() {
  local rest=${command%%gh pr create*}
  local dir=$PWD path
  while [[ $rest =~ (^|\&\&|\|\||\;)[[:space:]]*cd[[:space:]]+(\"[^\"]*\"|\'[^\']*\'|[^[:space:]\&\|\;]+) ]]; do
    path=${BASH_REMATCH[2]}
    rest=${rest#*"${BASH_REMATCH[0]}"}
    case $path in
      \"*\" | \'*\') path=${path:1:${#path}-2} ;;
    esac
    path=${path/#\~/$HOME}
    path=${path//\$\{HOME\}/$HOME}
    path=${path//\$HOME/$HOME}
    case $path in *'$'*) return 1 ;; esac
    case $path in /*) dir=$path ;; *) dir=$dir/$path ;; esac
  done
  [ -d "$dir" ] || return 1
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  printf '%s' "$dir"
}

# The default branch this PR would target, so the diff below is the PR's own.
default_branch() {
  local candidate
  candidate=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || candidate=""
  if [ -n "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  for candidate in origin/main origin/master; do
    if git -C "$repo" rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"; return 0
    fi
  done
  return 1
}

# What this PR actually changes: commits since the base, plus anything still in the
# working tree, so a PR opened right after an edit is judged on the files it carries.
changed_files() {
  local base merge_base
  base=$(default_branch) || return 1
  merge_base=$(git -C "$repo" merge-base HEAD "$base" 2>/dev/null) || return 1
  {
    git -C "$repo" diff --name-only "$merge_base" HEAD 2>/dev/null || return 1
    git -C "$repo" diff --name-only HEAD 2>/dev/null || true
  } | sort -u
}

# The skills read Swift, so only a diff carrying Swift is worth gating. The hook fires
# for every `gh pr create` in a session rooted at this project — including one run from
# a sibling repo's worktree — so ask git what is changing rather than assuming it is
# this app: a Markdown-only PR against a backend was demanding a SwiftUI review of
# TypeScript. Fails closed — an unresolvable directory, base or diff gates as before
# rather than waving through a change nobody has looked at.
if repo=$(command_dir) && files=$(changed_files); then
  if ! printf '%s\n' "$files" | grep -q '\.swift$'; then
    exit 0
  fi
fi

cat >&2 <<'MSG'
Blocked: open a PR only after reviewing the diff with the Swift review skills.

Run these on the current branch diff and address their findings (scope each to
what changed: concurrency only if async code changed, accessibility only if a
view changed; /swift-safety on every diff):
  /swiftui-pro
  /swift-concurrency-pro
  /swift-safety
  /swift-accessibility-skill

Then re-run the same command prefixed with REVIEWS_DONE=1, e.g.:
  REVIEWS_DONE=1 gh pr create ...
MSG
exit 2
