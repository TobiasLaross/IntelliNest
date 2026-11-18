#!/usr/bin/env bash
# shots.sh: drive a screenshot simulator to verify an IntelliNest UI change on a live simulator.
#
# Ported from terra-ios (Wisemap). The simulators (`screenshots-1`, `screenshots-2`) are a pool shared
# with lilium, gto-poker-ios, terra-ios and sinopia-ios, guarded by one cross-agent lock (simlock.sh,
# byte-identical in every repo). Acquire before touching a sim; the lock picks the slot, and every
# command below resolves the sim from it. A lock nobody drives hands itself back after
# SHOTS_IDLE_GRACE seconds.
#
# Never create or boot any other simulator for IntelliNest. If a pool sim is missing, stop and ask.
#
# Commands:
#   shots.sh status                       # lock holders, the queue, and our sim
#   shots.sh holds                        # exit 0 iff we hold a slot (no output)
#   shots.sh acquire "<label>"            # block until we own a sim
#   shots.sh release                      # drop the lock (non-zero if it could not)
#   shots.sh force-release "<holder>"     # recover a hold whose session token no longer matches
#   shots.sh run "<label>" -- <cmd>       # acquire + run + release from a trap
#   shots.sh recover                      # dead-idb reset, scoped to our sim
#   shots.sh boot                         # boot the sim this session was assigned
#   shots.sh sim | udid                   # print that sim's name or udid
#   shots.sh build                        # compile this worktree (no sim, no lock)
#   shots.sh install                      # build, then install on the sim
#   shots.sh launch [-- <launch-args>]    # (re)launch the app
#   shots.sh shot <name>                  # screenshot to ./shots/<name>.png
#   shots.sh describe                     # every labelled element with its centre point
#   shots.sh tap <x> <y>                  # tap a point
#   shots.sh tap-label <label>            # tap the first element whose accessibility label matches
#   shots.sh text "<text>"                # type into the focused field
set -euo pipefail

BUNDLE_ID="se.laross.IntelliNest"
SCHEME="IntelliNest"
PROJECT="IntelliNest.xcodeproj"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOTS_DIR="${REPO_ROOT}/shots"

# --- the cross-agent lock: configure simlock.sh here, never re-implement it below ---
SIMLOCK_TOOL="intellinest"
STATE_DIR="${INTELLINEST_SHOTS_STATE_DIR:-$HOME/.agentic-qa/intellinest}"
SIMLOCK_STATE_DIR="$STATE_DIR"
# Keyed by worktree, one agent per worktree (see own_session in simlock.sh).
WORKTREE_KEY="$(printf '%s' "$REPO_ROOT" | md5 -q)"
SIMLOCK_SESSION_FILE="/tmp/intellinest-shots.${WORKTREE_KEY}.session"
SIMLOCK_SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
SIMLOCK_RESOURCE="screenshot sim"
SIMLOCK_DIE_PREFIX="error: "
# shellcheck source-path=SCRIPTDIR
# shellcheck source=simlock.sh
. "$SCRIPT_DIR/simlock.sh"

# Outside the repo: a -derivedDataPath inside it makes the SwiftLint build phase lint the SwiftPM checkouts.
DERIVED="${STATE_DIR}/DerivedData/${WORKTREE_KEY}"
BUILD_LOG="${STATE_DIR}/build-${WORKTREE_KEY}.log"

simlock_teardown() { return 0; }

simlock_on_acquired() {
  # Prunes idb registrations whose companion died, so the run doesn't inherit the last crash.
  command -v idb >/dev/null 2>&1 && idb list-targets >/dev/null 2>&1 || true
  return 0
}

# The machine-wide `pkill -f idb_companion` kills other agents' work; this only touches our sim's companions.
cmd_recover() {
  assert_held
  require_idb
  local slot; slot="$(simlock_current_slot)"
  local udid; udid="$(sim_udid || true)"; [ -n "$udid" ] || die "no sim named '$(sim_name)', nothing to recover."
  audit recover "$(holder_label "$slot")"
  idb list-targets >/dev/null 2>&1 || true
  local killed=0 pid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    case "$(ps -o command= -p "$pid" 2>/dev/null || true)" in
      *"$udid"*) kill "$pid" 2>/dev/null || true; killed=$((killed + 1)) ;;
    esac
  done < <(pgrep -f idb_companion 2>/dev/null || true)
  rm -f /tmp/idb/*"$udid"* 2>/dev/null || true
  touch "$(slot_lock_dir "$slot")" "$(slot_meta "$slot")"
  say "${c_grn}recover: killed ${killed} companion(s) bound to $(sim_name); cleared its sockets.${c_rst}"
  say "Re-run the failed command; the next idb call respawns a clean companion."
}

cmd_status() {
  say "screenshot sim pool:"
  simlock_status_lines
  local slot; slot="$(simlock_current_slot || true)"
  [ -n "$slot" ] || { say "  ours:       ${c_ylw}no slot held${c_rst} (run: shots.sh acquire \"<label>\")"; return 0; }
  local udid; udid="$(sim_udid || true)"
  if [ -n "$udid" ]; then
    say "  ours:       slot $slot: $(sim_name) ($udid)"
  else
    say "  ours:       slot $slot: $(sim_name) ${c_red}missing${c_rst} (ask the user; never create one)"
  fi
}

# Read from the lock, not a variable, so a second bash call can't drift onto a sim we don't hold.
sim_name() {
  simlock_current_sim || die "no screenshot slot held. Run: shots.sh acquire \"<label>\" first."
}

sim_udid() { sim_udid_named "$(sim_name)"; }

# The pool sims are shared and pre-made. Creating one here is what leaves stray multi-GB devices behind.
require_sim() {
  local udid; udid="$(sim_udid || true)"
  [ -n "$udid" ] || die "pool sim '$(sim_name)' does not exist. Ask the user; never create a simulator."
  printf '%s\n' "$udid"
}

cmd_boot() {
  assert_held
  local udid; udid="$(require_sim)"
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b
  echo "$udid booted"
}

# Needs no slot: a cold build inside the hold outlasts SHOTS_IDLE_GRACE and the lock hands itself back.
build_app() {
  [ -f "$REPO_ROOT/IntelliNest-Info.xcconfig" ] \
    || die "IntelliNest-Info.xcconfig is missing. See 'Secrets file' in CLAUDE.md."
  mkdir -p "$(dirname "$BUILD_LOG")"
  xcodebuild build \
    -project "$REPO_ROOT/$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO >"$BUILD_LOG" 2>&1 \
    || { tail -30 "$BUILD_LOG" >&2; die "build failed (full log: $BUILD_LOG)"; }
  local app; app="$(find "$DERIVED/Build/Products" -maxdepth 2 -name "$SCHEME.app" -type d | head -1)"
  [ -n "$app" ] || die "built .app not found"
  printf '%s\n' "$app"
}

cmd_build() { build_app; }

cmd_install() {
  assert_held
  local udid; udid="$(require_sim)"
  local app; app="$(build_app)"
  xcrun simctl install "$udid" "$app"
  # Skips the location prompt; notifications and "Välj användare" still need a tap.
  xcrun simctl privacy "$udid" grant location-always "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "installed $BUNDLE_ID"
}

cmd_launch() {
  assert_held
  local udid; udid="$(require_sim)"
  shift || true; [ "${1:-}" = "--" ] && shift || true
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" "$@"
}

cmd_shot() {
  assert_held
  local name="${1:?usage: shot <name>}" udid; udid="$(require_sim)"
  mkdir -p "$SHOTS_DIR"
  xcrun simctl io "$udid" screenshot "$SHOTS_DIR/$name.png" >/dev/null
  echo "$SHOTS_DIR/$name.png"
}

require_idb() { command -v idb >/dev/null 2>&1 || die "idb not found. Install fb-idb to drive the sim."; }

# Prints "<label>\t<x>\t<y>" per labelled element, x/y being its centre in points.
describe_lines() { # describe_lines <udid>
  idb ui describe-all --udid "$1" 2>/dev/null | python3 -c '
import json, sys
try:
    elements = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
for element in elements:
    label = element.get("AXLabel")
    frame = element.get("frame") or {}
    if label:
        x = frame.get("x", 0) + frame.get("width", 0) / 2
        y = frame.get("y", 0) + frame.get("height", 0) / 2
        print(f"{label}\t{int(x)}\t{int(y)}")
'
}

cmd_describe() {
  assert_held; require_idb
  local udid; udid="$(require_sim)"
  describe_lines "$udid" || die "idb could not read $(sim_name). Try: shots.sh recover"
}

# A zero-length tap is ignored by a SwiftUI Toggle; this stays well under the long-press threshold.
TAP_DURATION=0.12

cmd_tap() {
  assert_held; require_idb
  local x="${1:?usage: tap <x> <y>}" y="${2:?usage: tap <x> <y>}" udid; udid="$(require_sim)"
  idb ui tap --udid "$udid" "$x" "$y" --duration "$TAP_DURATION" >/dev/null
  say "tapped $x,$y"
}

cmd_tap_label() {
  assert_held; require_idb
  local want="${1:?usage: tap-label <label>}" udid line; udid="$(require_sim)"
  line="$(describe_lines "$udid" | awk -F'\t' -v want="$want" '$1 == want { print; exit }')"
  [ -n "$line" ] || die "no element labelled '$want' on screen."
  local x y; x="$(printf '%s' "$line" | cut -f2)"; y="$(printf '%s' "$line" | cut -f3)"
  idb ui tap --udid "$udid" "$x" "$y" --duration "$TAP_DURATION" >/dev/null
  say "tapped $want"
}

cmd_text() {
  assert_held; require_idb
  local udid; udid="$(require_sim)"
  idb ui text --udid "$udid" "${1:?usage: text <text>}"
}

cmd_sim()  { assert_held; printf '%s\n' "$(sim_name)"; }
cmd_udid() { assert_held; require_sim; }

COMMANDS="status|holds|acquire|release|force-release|run|recover|boot|sim|udid|build|install|launch|shot|describe|tap|tap-label|text"
case "${1:-status}" in
  status)   cmd_status ;;
  holds)    cmd_holds ;;
  keepalive-loop) shift; cmd_keepalive_loop "$@" ;;
  idle-shutdown) shift; cmd_idle_shutdown "$@" ;;
  acquire)  shift; cmd_acquire "$@" ;;
  release)  cmd_release ;;
  force-release) shift; cmd_force_release "$@" ;;
  run)      shift; cmd_run "$@" ;;
  recover)  cmd_recover ;;
  boot)     cmd_boot ;;
  sim)      cmd_sim ;;
  udid)     cmd_udid ;;
  build)    cmd_build ;;
  install)  cmd_install ;;
  launch)   cmd_launch "$@" ;;
  shot)     shift; cmd_shot "$@" ;;
  describe) cmd_describe ;;
  tap)      shift; cmd_tap "$@" ;;
  tap-label) shift; cmd_tap_label "$@" ;;
  text)     shift; cmd_text "$@" ;;
  *) die "usage: shots.sh {${COMMANDS}}" ;;
esac
