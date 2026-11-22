#!/usr/bin/env bash
# Proves the PreToolUse review gate judges the repo the command will actually run in.
#
# The gate exists to stop a Swift PR being opened before the quality skills have seen
# it. It reads the diff itself, so it is only as good as the directory it reads from —
# and the repo's own flow (`cd <worktree> && gh pr create`) runs the hook in the main
# checkout, whose tree is clean. That shape is the first case below. A PR from a sibling
# repo is judged on that repo's own diff.
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
# process sitting in $cwd, and the sandbox app as the session's project. GATE_PATH
# stands in for the hook's PATH when a case needs a tool to be missing.
run_gate() {
  local cwd=$1 command=$2
  ( cd "$cwd" && printf '%s' "$command" \
      | jq -Rs '{tool_input: {command: .}}' \
      | PATH=${GATE_PATH:-$PATH} CLAUDE_PROJECT_DIR=$MAIN "$GATE" >/dev/null 2>&1 )
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
git -C "$MAIN" worktree add --quiet -b feature/quoted "$QUOTED"
check "a quoted cd path with a space is followed" \
  0 "$(run_gate "$MAIN" "cd \"$QUOTED\" && gh pr create --fill")"
commit_file "$QUOTED" Quoted.swift
check "a swift change behind a quoted cd path is gated" \
  2 "$(run_gate "$MAIN" "cd \"$QUOTED\" && gh pr create --fill")"

HOME_TREE=$SANDBOX/home-tree
git -C "$MAIN" worktree add --quiet -b feature/tilde "$HOME_TREE"
check "a tilde in the cd path is expanded" \
  0 "$(HOME=$SANDBOX run_gate "$MAIN" "cd ~/home-tree && gh pr create --fill")"
commit_file "$HOME_TREE" Tilde.swift
check "a swift change behind a tilde cd path is gated" \
  2 "$(HOME=$SANDBOX run_gate "$MAIN" "cd ~/home-tree && gh pr create --fill")"

# A docs-only PR is the case the gate deliberately waves through, and the reason it
# reads a diff at all.
DOCS=$SANDBOX/app--docs
git -C "$MAIN" worktree add --quiet -b feature/docs "$DOCS"
printf 'notes\n' > "$DOCS/NOTES.md"
git -C "$DOCS" add NOTES.md
git -C "$DOCS" commit --quiet -m docs
check "a markdown-only PR from a worktree passes" \
  0 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill")"
check "a markdown-only PR from a subdirectory of a worktree passes" \
  0 "$(mkdir -p "$DOCS/sub" && run_gate "$MAIN" "cd $DOCS/sub && gh pr create --fill")"

# Uncommitted work counts: a PR opened right after an edit carries it.
printf 'let pending = 1\n' > "$DOCS/Pending.swift"
git -C "$DOCS" add Pending.swift
check "a staged swift file in that worktree is gated" \
  2 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill")"
git -C "$DOCS" reset --quiet HEAD Pending.swift
rm -f "$DOCS/Pending.swift"

# A repo's own config can name a program for git to run, and the hook runs before the
# command is approved. Each of these plants one that leaves a marker if it ever runs.
plant_fsmonitor() {
  local dir=$1 marker=$2
  printf '#!/bin/sh\ntouch "%s"\n' "$marker" > "$SANDBOX/fsmonitor-$(basename "$marker")"
  chmod +x "$SANDBOX/fsmonitor-$(basename "$marker")"
  git -C "$dir" config core.fsmonitor "$SANDBOX/fsmonitor-$(basename "$marker")"
}

HOSTILE=$SANDBOX/hostile
mk_repo "$HOSTILE"
plant_fsmonitor "$HOSTILE" "$SANDBOX/ran-hostile"
printf '* filter=planted\n' > "$HOSTILE/.git/info/attributes"
git -C "$HOSTILE" -c core.fsmonitor=false config filter.planted.clean "touch '$SANDBOX/ran-hostile'; cat"
printf 'SEED\n' > "$HOSTILE/README.md"
check "a sibling repo with no swift passes" \
  0 "$(run_gate "$MAIN" "cd $HOSTILE && gh pr create --fill")"
check "the gate runs nothing a sibling repo's config names" \
  absent "$([ -e "$SANDBOX/ran-hostile" ] && echo present || echo absent)"

NESTED=$DOCS/vendor/hostile
mk_repo "$NESTED"
plant_fsmonitor "$NESTED" "$SANDBOX/ran-nested"
check "a repo nested in a worktree with no swift passes" \
  0 "$(run_gate "$MAIN" "cd $NESTED && gh pr create --fill")"
check "the gate runs nothing a nested repo's config names" \
  absent "$([ -e "$SANDBOX/ran-nested" ] && echo present || echo absent)"

plant_fsmonitor "$MAIN" "$SANDBOX/ran-project"
check "a swift worktree PR is still gated with an fsmonitor configured" \
  2 "$(run_gate "$MAIN" "cd $WORKTREE && gh pr create --fill")"
check "the gate's own git runs with fsmonitor off" \
  absent "$([ -e "$SANDBOX/ran-project" ] && echo present || echo absent)"
git -C "$MAIN" config --unset core.fsmonitor

SIBLING=$SANDBOX/backend
mk_repo "$SIBLING"
mkdir "$SIBLING/docs"
commit_file "$SIBLING" docs/notes.md
check "a markdown-only PR from a sibling repo passes" \
  0 "$(run_gate "$MAIN" "cd $SIBLING && gh pr create --fill")"
commit_file "$SIBLING" Api.swift
check "a swift PR from a sibling repo is gated" \
  2 "$(run_gate "$MAIN" "cd $SIBLING && gh pr create --fill")"
check "a swift PR from a sibling repo's subdirectory is gated" \
  2 "$(run_gate "$MAIN" "cd $SIBLING/docs && gh pr create --fill")"

# Fail closed on a directory the hook cannot resolve, rather than judging its own cwd.
check "a cd into a missing directory is gated" \
  2 "$(run_gate "$MAIN" "cd $SANDBOX/not-here && gh pr create --fill")"

check "a cd needing shell expansion is gated" \
  2 "$(run_gate "$MAIN" "cd \$WORKTREE_VAR && gh pr create --fill")"

NOT_A_REPO=$SANDBOX/plain-dir
mkdir -p "$NOT_A_REPO"
check "a cd outside any git repo is gated" \
  2 "$(run_gate "$MAIN" "cd $NOT_A_REPO && gh pr create --fill")"

# Only `gh pr create` run as a command is gated; every other command passes untouched,
# including one whose quoted argument mentions it.
check "an unrelated command passes" \
  0 "$(run_gate "$MAIN" "cd $WORKTREE && git status")"
check "an issue body that mentions the phrase passes" \
  0 "$(run_gate "$WORKTREE" "gh issue create --title x --body 'it blocks gh pr create'")"
check "an issue body with the phrase after a separator passes" \
  0 "$(run_gate "$WORKTREE" "gh issue create --body \"first; gh pr create --fill\"")"
check "a PR command behind an env assignment is gated" \
  2 "$(run_gate "$WORKTREE" "GH_PAGER= gh pr create --fill")"
check "a PR command on a later line is gated" \
  2 "$(run_gate "$WORKTREE" "git push
gh pr create --fill")"

# A `cd` after the PR command belongs to a later step and must not be followed.
check "a cd after gh pr create is ignored" \
  2 "$(run_gate "$WORKTREE" "gh pr create --fill && cd $DOCS")"

# The `cd` can sit behind a subshell paren, on its own line, or be a `pushd`: each is the
# same worktree PR as the first case, and reading main's clean diff instead waved it through.
check "a cd inside a subshell is followed" \
  2 "$(run_gate "$MAIN" "(cd $WORKTREE && gh pr create --fill)")"
check "a cd inside a subshell passes once attested" \
  0 "$(run_gate "$MAIN" "(cd $WORKTREE && REVIEWS_DONE=1 gh pr create --fill)")"
check "a cd on its own line is followed" \
  2 "$(run_gate "$MAIN" "git push
cd $WORKTREE
gh pr create --fill")"
check "a cd on its own line passes once attested" \
  0 "$(run_gate "$MAIN" "git push
cd $WORKTREE
REVIEWS_DONE=1 gh pr create --fill")"
check "a pushd is followed" \
  2 "$(run_gate "$MAIN" "pushd $WORKTREE && gh pr create --fill")"
check "a pushd passes once attested" \
  0 "$(run_gate "$MAIN" "pushd $WORKTREE && REVIEWS_DONE=1 gh pr create --fill")"

# When the command changes branch first, or names the branch with --head, the diff of the
# checked-out branch is not the PR's. The gate cannot read the right one, so it fails closed
# whatever that diff holds: these run against the clean main checkout and the docs worktree.
for shape in \
  "gh pr create --fill --head feature/swift" \
  "gh pr create --fill --head=feature/swift" \
  "gh pr create --fill -H feature/swift" \
  "gh pr create --title t \\
  --head feature/swift" \
  "git switch feature/swift && gh pr create --fill" \
  "git checkout -b feature/new && gh pr create --fill" \
  "git -C $MAIN checkout feature/swift && gh pr create --fill"; do
  name=${shape//$MAIN/MAIN}
  check "a PR for a branch the hook cannot see is gated: ${name//$'\n'/ }" \
    2 "$(run_gate "$MAIN" "$shape")"
done
check "a --head PR from a markdown-only worktree is still gated" \
  2 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill --head feature/swift")"
check "a --head PR passes once attested" \
  0 "$(run_gate "$MAIN" "REVIEWS_DONE=1 gh pr create --fill --head feature/swift")"
check "a branch switch passes once attested" \
  0 "$(run_gate "$MAIN" "git switch feature/swift && REVIEWS_DONE=1 gh pr create --fill")"
check "a quoted commit message naming switch is not a branch change" \
  0 "$(run_gate "$MAIN" "cd $DOCS && git commit -qam 'switch the copy' && gh pr create --fill")"
check "a -H after the PR command belongs to a later step" \
  0 "$(run_gate "$MAIN" "cd $DOCS && gh pr create --fill && curl -H 'x: y' localhost")"

# gh reached by path or through a shell wrapper is the same PR as a bare gh: judged on its
# diff, not waved through and not blocked outright.
for shape in \
  "/opt/homebrew/bin/gh pr create --fill" \
  "command gh pr create --fill" \
  "env gh pr create --fill" \
  "exec gh pr create --fill"; do
  check "a swift PR is gated through: $shape" \
    2 "$(run_gate "$WORKTREE" "$shape")"
  check "a markdown-only PR passes through: $shape" \
    0 "$(run_gate "$DOCS" "$shape")"
done
check "a gh path passes once attested" \
  0 "$(run_gate "$WORKTREE" "REVIEWS_DONE=1 /opt/homebrew/bin/gh pr create --fill")"
check "an env wrapper passes once attested" \
  0 "$(run_gate "$WORKTREE" "env REVIEWS_DONE=1 gh pr create --fill")"

# The token only counts as an assignment on the gh command itself.
for shape in \
  "echo REVIEWS_DONE=1; gh pr create --fill" \
  "REVIEWS_DONE=1 git push && gh pr create --fill" \
  "gh pr create --fill REVIEWS_DONE=1" \
  "gh pr create --title t --body 'run REVIEWS_DONE=1 gh pr create next'" \
  "gh pr create --title t --body \"REVIEWS_DONE=1 is the token\""; do
  check "the token elsewhere in the command does not attest: $shape" \
    2 "$(run_gate "$WORKTREE" "$shape")"
done

# File names git quotes, and a list longer than a pipe buffer: both once read as "no Swift".
for name in "Översikt.swift" 'Say "hi".swift' $'Tab\tName.swift' "Deep/Er/Nested.swift"; do
  ODD=$(mktemp -d "$SANDBOX/odd.XXXXXX")/tree
  git -C "$MAIN" worktree add --quiet --detach "$ODD" main
  mkdir -p "$(dirname "$ODD/$name")"
  commit_file "$ODD" "$name"
  check "a swift file is gated whatever its name: $name" \
    2 "$(run_gate "$MAIN" "cd $ODD && gh pr create --fill")"
done

LONG=$SANDBOX/app--long
git -C "$MAIN" worktree add --quiet --detach "$LONG" main
printf 'let value = 1\n' > "$LONG/A.swift"
mkdir "$LONG/assets"
padding=$(printf '%0120d' 0)
for ((number = 0; number < 1500; number++)); do : > "$LONG/assets/$padding$number.txt"; done
git -C "$LONG" add -A
git -C "$LONG" commit --quiet -m long
check "a swift file in a very long file list is gated" \
  2 "$(run_gate "$MAIN" "cd $LONG && gh pr create --fill")"

RENAMED=$SANDBOX/app--renamed
git -C "$MAIN" worktree add --quiet --detach "$RENAMED" feature/swift
git -C "$RENAMED" mv Thing.swift Thing.txt
check "a swift file renamed in the working tree is gated" \
  2 "$(run_gate "$MAIN" "cd $RENAMED && gh pr create --fill")"

# A project of its own, with the Swift file already on main, so only the working tree can gate it.
EDITED=$SANDBOX/edited
mk_repo "$EDITED"
commit_file "$EDITED" Existing.swift
git -C "$EDITED" update-ref refs/remotes/origin/main HEAD
edited_gate() { MAIN=$EDITED run_gate "$EDITED" "gh pr create --fill"; }
check "a swift file already on main passes" 0 "$(edited_gate)"
touch -t 203001010000 "$EDITED/Existing.swift"
check "a touched but unchanged swift file passes" 0 "$(edited_gate)"
printf 'let edited = 2\n' >> "$EDITED/Existing.swift"
check "an unstaged swift edit is gated" 2 "$(edited_gate)"
git -C "$EDITED" add Existing.swift
printf 'let value = 1\n' > "$EDITED/Existing.swift"
check "a staged swift edit undone in the working tree is still gated" 2 "$(edited_gate)"
git -C "$EDITED" reset --quiet --hard

# Comparing the working tree makes git run whatever filter driver the repo's config names.
printf '* filter=planted\n' > "$EDITED/.git/info/attributes"
for kind in clean process; do
  printf 'let edited = "%s"\n' "$kind" > "$EDITED/Existing.swift"
  git -C "$EDITED" config "filter.planted.$kind" "touch '$SANDBOX/ran-$kind'; cat"
  check "a swift edit under a $kind filter is gated" 2 "$(edited_gate)"
  check "the gate never runs a $kind filter" \
    absent "$([ -e "$SANDBOX/ran-$kind" ] && echo present || echo absent)"
  git -C "$EDITED" config --unset "filter.planted.$kind"
done

SUPER=$SANDBOX/super
mk_repo "$SUPER"
mk_repo "$SUPER/Dep"
git -C "$SUPER" -c advice.addEmbeddedRepo=false add Dep
git -C "$SUPER" commit --quiet -m dependency
git -C "$SUPER" update-ref refs/remotes/origin/main HEAD
printf '* filter=planted\n' > "$SUPER/Dep/.git/info/attributes"
printf 'SEED\n' > "$SUPER/Dep/README.md"
git -C "$SUPER/Dep" config filter.planted.clean "touch '$SANDBOX/ran-submodule'; cat"
check "a dirty submodule alone passes" \
  0 "$(MAIN=$SUPER run_gate "$SUPER" "gh pr create --fill")"
check "the gate never runs a submodule's filter" \
  absent "$([ -e "$SANDBOX/ran-submodule" ] && echo present || echo absent)"

BROKEN=$SANDBOX/broken
mk_repo "$BROKEN"
printf 'not an index, and far too short to be one' > "$BROKEN/.git/index"
check "a diff git cannot read is gated" \
  2 "$(MAIN=$BROKEN run_gate "$BROKEN" "gh pr create --fill")"

# Without jq the hook would die with 127, which Claude Code treats as a non-blocking error.
NO_JQ_BIN=$SANDBOX/no-jq-bin
mkdir -p "$NO_JQ_BIN"
ln -s "$(command -v bash)" "$NO_JQ_BIN/bash"
check "a missing jq blocks instead of switching the gate off" \
  2 "$(GATE_PATH=$NO_JQ_BIN run_gate "$WORKTREE" "gh pr create --fill")"

if [ "$failures" -ne 0 ]; then
  printf '\n%s check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall review-gate checks passed\n'
