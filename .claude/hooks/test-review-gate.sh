#!/usr/bin/env bash
# Proves the PreToolUse review gate judges the repo the command will actually run in.
#
# The gate exists to stop a Swift PR being opened before the quality skills have seen
# it. It reads the diff itself, so it is only as good as the directory it reads from —
# and the repo's own flow (`cd <worktree> && gh pr create`) runs the hook in the main
# checkout, whose tree is clean. That shape is the first case below.
#
# Throwaway git sandboxes: nothing here touches a real repo or calls gh.
set -uo pipefail
GATE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/require-skill-reviews.sh
SANDBOX=$(mktemp -d -t reviewgate)
trap 'rm -rf "$SANDBOX"' EXIT

failures=0
check() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s (expected exit %s, got %s)\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

# A repo with a main branch and an origin/main to diff against, so the gate's base
# resolution behaves as it does against a real remote.
mk_repo() {
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init --quiet --initial-branch=main
  git -C "$dir" config user.email gate@test
  git -C "$dir" config user.name gate
  printf 'seed\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit --quiet -m seed
  git -C "$dir" update-ref refs/remotes/origin/main HEAD
}

commit_file() {
  local dir=$1 name=$2
  printf 'let value = 1\n' > "$dir/$name"
  git -C "$dir" add "$name"
  git -C "$dir" commit --quiet -m "add $name"
}

# Runs the gate the way Claude Code does: the command on stdin as JSON, the hook's
# process sitting in $cwd.
run_gate() {
  local cwd=$1 command=$2
  ( cd "$cwd" && printf '%s' "$command" \
      | jq -Rs '{tool_input: {command: .}}' \
      | "$GATE" >/dev/null 2>&1 )
  printf '%s' $?
}

MAIN=$SANDBOX/app
WORKTREE=$SANDBOX/app--feature
mk_repo "$MAIN"
git -C "$MAIN" worktree add --quiet -b feature/swift "$WORKTREE"
commit_file "$WORKTREE" Thing.swift

# The regression: a Swift branch opened from its worktree, with the hook sitting in the
# clean main checkout. Before the fix this read main's empty diff and exited 0.
check "swift worktree PR from the main checkout is gated" \
  2 "$(run_gate "$MAIN" "cd $WORKTREE && gh pr create --fill")"

check "the same PR passes once the reviews are attested" \
  0 "$(run_gate "$MAIN" "cd $WORKTREE && REVIEWS_DONE=1 gh pr create --fill")"

check "swift PR opened from inside the worktree is gated" \
  2 "$(run_gate "$WORKTREE" "gh pr create --fill")"

# A quoted path with a space, and a `~` the hook has to expand itself: both are
# directories the gate must still resolve rather than fall back to its own cwd.
QUOTED="$SANDBOX/has space"
mk_repo "$QUOTED"
commit_file "$QUOTED" Quoted.swift
check "a quoted cd path with a space is followed" \
  2 "$(run_gate "$MAIN" "cd \"$QUOTED\" && gh pr create --fill")"

HOME_REPO=$SANDBOX/home-repo
mk_repo "$HOME_REPO"
commit_file "$HOME_REPO" Tilde.swift
check "a tilde in the cd path is expanded" \
  2 "$(HOME=$SANDBOX run_gate "$MAIN" "cd ~/home-repo && gh pr create --fill")"

# A docs-only PR is the case the gate deliberately waves through, and the reason it
# reads a diff at all — including one opened from a sibling repo in this session.
DOCS=$SANDBOX/backend--docs
mk_repo "$DOCS"
printf 'notes\n' > "$DOCS/NOTES.md"
git -C "$DOCS" add NOTES.md
git -C "$DOCS" commit --quiet -m docs
check "a markdown-only PR from a sibling repo passes" \
  0 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill")"

# Uncommitted work counts: a PR opened right after an edit carries it.
printf 'let pending = 1\n' > "$DOCS/Pending.swift"
git -C "$DOCS" add Pending.swift
check "a staged swift file in that sibling repo is gated" \
  2 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill")"
git -C "$DOCS" reset --quiet HEAD Pending.swift
rm -f "$DOCS/Pending.swift"

# Fail closed on a directory the hook cannot resolve, rather than judging its own cwd.
check "a cd into a missing directory is gated" \
  2 "$(run_gate "$MAIN" "cd $SANDBOX/not-here && gh pr create --fill")"

check "a cd needing shell expansion is gated" \
  2 "$(run_gate "$MAIN" "cd \$WORKTREE_VAR && gh pr create --fill")"

NOT_A_REPO=$SANDBOX/plain-dir
mkdir -p "$NOT_A_REPO"
check "a cd outside any git repo is gated" \
  2 "$(run_gate "$MAIN" "cd $NOT_A_REPO && gh pr create --fill")"

# Only `gh pr create` is gated; every other command passes untouched.
check "an unrelated command passes" \
  0 "$(run_gate "$MAIN" "cd $WORKTREE && git status")"

# A `cd` after the PR command belongs to a later step and must not be followed.
check "a cd after gh pr create is ignored" \
  2 "$(run_gate "$WORKTREE" "gh pr create --fill && cd $DOCS")"

if [ "$failures" -ne 0 ]; then
  printf '\n%s check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall review-gate checks passed\n'
