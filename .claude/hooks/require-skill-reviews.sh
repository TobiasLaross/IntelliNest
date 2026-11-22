#!/usr/bin/env bash
# Claude Code PreToolUse gate.
#
# Blocks `gh pr create` until the Swift review skills have been run on the branch
# diff and their findings addressed:
#   /swiftui-pro  /swift-concurrency-pro  /swift-safety  /swift-accessibility-skill
#
# Only for a diff that carries Swift, see `changed_swift` below.
#
# The hook can't run a Claude skill itself (skills need the model), so it gates
# the PR-open step and hands control back to the agent with instructions. Once
# the reviews are done, re-run the command prefixed with REVIEWS_DONE=1 to pass.
#
# Wired up in .claude/settings.json as a PreToolUse hook on the Bash tool.
# Ported from gto-poker-ios's Scripts/require-skill-reviews.sh; keep the two in step.
set -euo pipefail

# Claude Code treats a hook that dies with 127 as a non-blocking error, so a missing tool
# would switch the gate off silently. Block instead.
for tool in jq perl; do
  command -v "$tool" >/dev/null 2>&1 && continue
  printf 'Blocked: %s is missing, install it with brew install %s\n' "$tool" "$tool" >&2
  exit 2
done

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Only gate PR creation; every other Bash call passes straight through. Match the phrase as a
# command of its own, not inside a quoted argument (an issue body that mentions it), whether
# gh is a bare word, a path, or reached through command, env or exec. Prints a verdict and
# everything before the command, which is where the command's own `cd` lives:
#   attested        REVIEWS_DONE=1 is an assignment on the gh command itself, not text elsewhere
#   unknown-branch  the command switches branches first, or gh gets --head, so the branch
#                   checked out where the command runs is not the one the PR opens
#   gated           judge the diff of the directory the command runs in
parse_pr_command() {
  printf '%s' "$command" | perl -0777 -ne '
    (my $masked = $_) =~ s/(["\x27])(.*?)\1/$1 . ("_" x length($2)) . $1/gse;
    exit 1 unless $masked =~ m{
      (?:\A|[;&|(\n])[ \t]*
      ((?:[A-Za-z_][A-Za-z0-9_]*=\S*[ \t]+|(?:command|env|exec)[ \t]+(?:-\S+[ \t]+)*)*)
      (?:\S*/)?gh[ \t]+pr[ \t]+create(?=\s|\z)
    }x;
    my ($start, $words, $args) = ($-[1], $1, substr($masked, $+[0]));
    $args =~ s/\\\n/ /g;
    $args =~ s/[;&|)\n].*//s;
    my $before = substr($masked, 0, $start);
    my $verdict = "gated";
    if ($words =~ /(?:\A|\s)REVIEWS_DONE=1\s/) {
      $verdict = "attested";
    } elsif ($before =~ /(?:\A|[;&|(\n])[ \t]*git[ \t]+(?:[^;&|(\n]*[ \t])?(?:switch|checkout)(?:\s|\z)/
             || $args =~ /(?:\A|\s)(?:--head(?=[=\s]|\z)|-H)/) {
      $verdict = "unknown-branch";
    }
    print $verdict, "\0", substr($_, 0, $start), "\0";
  '
}
{ IFS= read -r -d '' verdict && IFS= read -r -d '' prefix; } < <(parse_pr_command) || exit 0

# Explicit acknowledgement that the reviews ran and findings were addressed.
if [ "$verdict" = attested ]; then
  exit 0
fi

# Where the command will actually run its git. A hook runs in the session's working
# directory, but this repo opens every PR from a sibling worktree reached by a `cd` on
# the same command line, so the session's directory is the main checkout with a clean
# tree, which carries no Swift and waved every worktree PR straight through. Follow
# the command's own `cd` instead, and refuse to guess when it needs a shell to resolve.
command_dir() {
  local rest=$prefix
  local dir=$PWD path
  local newline=$'\n'
  local cd_re="(^|&&|\|\||;|\(|$newline)[[:space:]]*(cd|pushd)[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]&|;)]+)"
  while [[ $rest =~ $cd_re ]]; do
    path=${BASH_REMATCH[3]}
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
  printf '%s' "$dir"
}

# Git with the config that can start a program switched off. The directory can be any repo,
# and a hook runs before the command is approved, so it should never launch anything itself.
safe_git() {
  GIT_CONFIG_NOSYSTEM=1 GIT_NO_LAZY_FETCH=1 git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}

# A PR from a sibling repo is judged on its own diff, so a docs-only one there still passes.
repo_root() {
  safe_git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

# The default branch this PR would target, so the diff below is the PR's own.
default_branch() {
  local candidate
  candidate=$(safe_git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || candidate=""
  if [ -n "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  for candidate in origin/main origin/master; do
    if safe_git -C "$repo" rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"; return 0
    fi
  done
  return 1
}

# Comparing the working tree runs any filter driver the config names, and no -c can switch off
# a driver by an unknown name. So compare inside an empty git dir, which has no config at all,
# on a copy of the index. cp -p, because git trusts an entry by the index's own mtime.
uncommitted_swift() {
  local tree objects index scratch status=0
  tree=$(safe_git -C "$repo" rev-parse --verify --quiet 'HEAD^{tree}') || return 1
  objects=$(safe_git -C "$repo" rev-parse --path-format=absolute --git-path objects) || return 1
  index=$(safe_git -C "$repo" rev-parse --path-format=absolute --git-path index) || return 1
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/reviewgate.XXXXXX") || return 1
  {
    mkdir "$scratch/refs" &&
      printf 'ref: refs/heads/none\n' > "$scratch/HEAD" &&
      cp -p "$index" "$scratch/index" &&
      inert_git diff-index --cached --name-only --ignore-submodules=all "$tree" -- '*.swift' &&
      inert_git diff --name-only --no-renames --ignore-submodules=all "$tree" -- '*.swift'
  } 2>/dev/null || status=1
  rm -rf "$scratch"
  return "$status"
}

inert_git() {
  GIT_DIR=$scratch GIT_WORK_TREE=$repo GIT_INDEX_FILE=$scratch/index GIT_OBJECT_DIRECTORY=$objects \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" "$@"
}

# The Swift this PR changes: commits since the base, plus anything still uncommitted, so a PR
# opened right after an edit is judged on the files it carries. Git does the matching, because
# it quotes unusual names in its output, and a grep -q on a long list fails under pipefail.
changed_swift() {
  local base merge_base
  base=$(default_branch) || return 1
  merge_base=$(safe_git -C "$repo" merge-base HEAD "$base" 2>/dev/null) || return 1
  safe_git -C "$repo" diff-tree -r --name-only --no-renames --ignore-submodules=all \
    "$merge_base" HEAD -- '*.swift' 2>/dev/null || return 1
  uncommitted_swift || return 1
}

# The skills read Swift, so only a diff carrying Swift is worth gating, in this repo or a sibling
# one. Fails closed: an unresolvable directory, base or diff gates rather than waving a change through.
if [ "$verdict" = unknown-branch ]; then
  cat >&2 <<'MSG'
Blocked: the gate can't tell which branch this PR opens. The command switches branches before
gh pr create, or passes --head, so the branch checked out where it runs is not the PR's.

If the PR's diff carries Swift, run the review skills listed below on it first. Either way,
re-run the same command prefixed with REVIEWS_DONE=1 once nothing is left to review.
MSG
elif dir=$(command_dir) && repo=$(repo_root "$dir") && swift=$(changed_swift); then
  if [ -z "$swift" ]; then
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
