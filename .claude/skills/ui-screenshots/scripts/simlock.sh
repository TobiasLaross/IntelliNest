# shellcheck shell=bash
# simlock.sh — the cross-agent mutex over the POOL of physical screenshot simulators.
#
# Sourced by lilium's and gto-poker-ios's .claude/skills/ui-screenshots/scripts/shots.sh.
# Each repo keeps its own copy so both stay self-contained, but the two copies
# MUST remain BYTE-IDENTICAL: they are two halves of one protocol over one queue,
# and the reason this file exists at all is that they had silently drifted.
# gto fixed the runaway-keep-alive bug (its comments cite lilium#1016) and
# lilium never got the fix — which is how an agent doing code-only work sat on
# the simulator for two hours, defending it with a hand-rolled heartbeat loop,
# while several named lilium and gto sessions queued behind it. A lock protocol
# spread across two 700-line tool scripts is a lock protocol nobody can diff.
#
# THERE ARE N SIMULATORS AND ONE QUEUE. Each sim is a SLOT with its own lock dir;
# waiters stand in a single line and the one at the head takes whichever slot
# frees up first. A pool of one behaves exactly like the old single lock, so the
# protocol did not fork — it generalized.
#
# The sourcing script sets these BEFORE the `.` line:
#   SIMLOCK_TOOL          short repo name, e.g. "lilium" / "gto-poker-ios"
#   SIMLOCK_STATE_DIR     per-repo state dir
#   SIMLOCK_SESSION_FILE  per-WORKTREE ownership token (see own_session)
#   SIMLOCK_SCRIPT_PATH   absolute path to that shots.sh (the keep-alive re-invokes it)
#   SIMLOCK_RESOURCE      human phrase for messages ("screenshot stack" / "screenshot sim")
#   SIMLOCK_DIE_PREFIX    prefix for fatal errors ("shots: " / "error: ")
#
# and may define these hooks, which the shared code calls when they exist:
#   simlock_on_acquired <label> <slot>   after a fresh acquire (per-tool housekeeping)
#   simlock_teardown <slot>              before that slot's lock dir is removed, on
#                                        EVERY path that gives it up: release,
#                                        force-release, the keep-alive's idle
#                                        auto-release, and a steal. The slot is an
#                                        argument because a THIEF tears down its
#                                        VICTIM's slot, which is not its own.
#
# What the sourcing script reads back:
#   simlock_current_slot    the slot number we hold (empty + non-zero if none)
#   simlock_current_sim     the simulator name that slot is bound to
#   simlock_status_lines    the pool + queue, for the tool's own `status`

# Bumped whenever the on-disk protocol changes shape in a way the other copy has
# to understand — the meta.json keys, the waiters directory, the activity file.
# A lock carrying a different (or absent) version is still waitable and still
# stealable; we only say so loudly. See warn_protocol_drift.
#
# v2 added the slot pool. It is deliberately backward-compatible on the wire:
# slot 1 keeps the v1 lock dir path and the v1 queue path, so a checkout still
# running v1 keeps excluding v2 agents on slot 1 and stands in the same line.
# A v1 agent simply never learns slot 2 exists, which costs it parallelism and
# nothing else.
#
# v3 added the keepalive_pid key. Purely additive: every v2 field still means
# what it meant, so a v2 holder queues, steals and self-releases identically —
# the only thing lost is that `status` cannot prove its process is alive. See the
# v2 case in warn_protocol_drift, which says exactly that instead of crying wolf.
SIMLOCK_PROTOCOL_VERSION=3

# The ordered pool. Slot 1 is the first name, slot 2 the second, and so on.
# Waiters try slots in this order, so a one-agent machine always lands on slot 1
# and slot 2's caches stay cold until there is real contention.
SIMLOCK_DEFAULT_POOL="screenshots-1 screenshots-2"
read -r -a SIMLOCK_POOL <<< "${SHARED_SCREENSHOT_SIM_POOL:-$SIMLOCK_DEFAULT_POOL}"
[ "${#SIMLOCK_POOL[@]}" -gt 0 ] || { printf 'simlock: SHARED_SCREENSHOT_SIM_POOL is empty\n' >&2; exit 1; }

slot_count() { printf '%s' "${#SIMLOCK_POOL[@]}"; }
slot_sim() { printf '%s' "${SIMLOCK_POOL[$(( $1 - 1 ))]}"; }
slot_numbers() { local index=1; while [ "$index" -le "$(slot_count)" ]; do printf '%s\n' "$index"; index=$((index + 1)); done; }

# Atomic `mkdir` of a slot's dir is the mutex across both tools, so two agents
# never drive one sim at once. Slot 1's path is the v1 path, unchanged and
# byte-identical in both copies — changing it in one un-shares the two tools AND
# breaks exclusion against any checkout still on v1.
SIMLOCK_DEFAULT_LOCK_DIR="$HOME/.agentic-qa/lilium/feature-screenshot.lock.d"
LOCK_ROOT="${SHARED_SCREENSHOT_LOCK_DIR:-$SIMLOCK_DEFAULT_LOCK_DIR}"
slot_lock_dir() {
  if [ "$1" = 1 ]; then printf '%s' "$LOCK_ROOT"; else printf '%s.slot%s' "${LOCK_ROOT%/}" "$1"; fi
}
slot_meta() { printf '%s/meta.json' "$(slot_lock_dir "$1")"; }
# Published inside the slot so WAITERS can read the holder's true idle time. The
# private ACTIVITY_FILE below lives at a path only its own worktree can derive.
slot_activity() { printf '%s/activity' "$(slot_lock_dir "$1")"; }

STATE_DIR="$SIMLOCK_STATE_DIR"
# Tombstones sit beside the pool, not in the per-repo state dir, for the same
# reason the waiters queue does: a steal crosses repos. Written into the THIEF's
# state dir, a tombstone was looked for in the VICTIM's and never found, so a gto
# steal was invisible to the lilium agent it stole from — the exact silence the
# tombstone exists to break. A sibling of the lock dirs, so `rm -rf` on a release
# does not take the notice with it.
TOMBSTONE_DIR="${LOCK_ROOT%/}.tombstones"
SESSION_FILE="$SIMLOCK_SESSION_FILE"

# A held session refreshes its heartbeat on every command AND from the keep-alive
# below. If nobody touches a slot for TTL seconds we assume the holder died and
# steal it. The right unit here is KEEPALIVE_INTERVALs, not minutes: the TTL has
# to outlast a few slipped beats on a loaded machine, and nothing more, so it is
# deliberately a multiple of that interval rather than a wall-clock guess. 180s
# at a 20s beat is 9 missed beats. The old 1200s was 20 beats — sized before the
# keep-alive existed, when a cold install or `before` build genuinely went silent
# for minutes — and it is the ONLY way a hard-killed holder's slot ever comes
# back (a dead pid does not free a slot; the steal below is purely age > TTL), so
# every second of it was 20 minutes another agent waited on a crash. MAXWAIT caps
# how long a waiter blocks before giving up with a clear message.
TTL="${SHOTS_LOCK_TTL:-180}"
# How long WE are willing to wait. It is deliberately not how long we let anyone
# ELSE wait: see ticket_maxwait.
SIMLOCK_DEFAULT_MAXWAIT=3600
MAXWAIT="${SHOTS_LOCK_MAXWAIT:-$SIMLOCK_DEFAULT_MAXWAIT}"
# The TTL assumed every holder calls a wrapped command often enough to look
# alive, but an agent driving raw idb between shots (or sitting in a long
# xcodebuild) calls none of them — it read as dead for minutes while working,
# was stolen from mid-run, and its recovery ladder then killed the thief's test
# runs (three in one incident). So acquire leaves a detached keep-alive
# refreshing the heartbeat until ownership is lost or the cap passes; the TTL
# stays as the backstop for a keep-alive that died with its agent. The interval
# is what buys the TTL its margin, so it is short: a beat is one `touch`, and
# paying it three times a minute is what lets the TTL come down to 180s without
# risking a steal out from under a live agent mid-build.
KEEPALIVE_INTERVAL="${SHOTS_KEEPALIVE_INTERVAL:-20}"
KEEPALIVE_CAP="${SHOTS_KEEPALIVE_CAP:-5400}"
KEEPALIVE_PID_FILE="${SESSION_FILE%.session}.keepalive.pid"
# The keep-alive used to refresh unconditionally for its whole cap, which made
# the TTL unreachable: a lock nobody had touched in an hour still read as live,
# and every other agent queued behind it for the full 90 minutes (lilium#1016).
# Only real commands stamp ACTIVITY_FILE — the keep-alive never does — so it can
# tell a long xcodebuild from an agent that walked away, and hands an idle slot
# back itself. A heartbeat proves the PROCESS is alive; this proves the WORK is.
ACTIVITY_FILE="${SESSION_FILE%.session}.activity"
IDLE_GRACE="${SHOTS_IDLE_GRACE:-600}"
# `force-release` refuses to take a slot whose holder ran something this recently
# without an explicit --yes; a live holder between two commands must not be cut off.
FORCE_MIN_IDLE="${SHOTS_FORCE_MIN_IDLE:-120}"
# How often a waiter re-checks the queue, and how often it repeats its position
# line when nothing has changed. One line per poll is noise nobody reads.
POLL="${SHOTS_LOCK_POLL:-5}"
WAIT_NOTE_INTERVAL="${SHOTS_LOCK_NOTE_INTERVAL:-60}"
# One append-only line per lock lifecycle event (acquire, wait-start, steal,
# release, keep-alive start/stop, auto-release, idle-warning, recover), so an
# interference incident can be reconstructed from a log instead of argued from
# memory. Shared by both tools. Head-chopped past 1MB.
AUDIT_LOG="${SHOTS_AUDIT_LOG:-$HOME/.agentic-qa/sim-lock-audit.log}"

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_rst=$'\033[0m'
say() { printf '%s\n' "$*" >&2; }
die() { printf '%s%s%s%s\n' "$c_red" "${SIMLOCK_DIE_PREFIX:-shots: }" "$*" "$c_rst" >&2; exit 1; }

now() { date +%s; }

meta_field() { # meta_field <slot> <key>
  local meta; meta="$(slot_meta "$1")"
  [ -f "$meta" ] || return 0
  python3 - "$meta" "$2" <<'PY' 2>/dev/null || true
import json, sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2], "") or "")
except Exception:
    pass
PY
}

meta_mtime() { stat -f %m "$(slot_meta "$1")" 2>/dev/null || echo 0; }

# The holder's display name. lilium keys it "feature" and gto keys it "label";
# both scripts write BOTH, so either tool names the other's holder correctly.
holder_label() { # holder_label <slot>
  local name; name="$(meta_field "$1" feature)"
  [ -n "$name" ] || name="$(meta_field "$1" label)"
  printf '%s' "$name"
}

holder_tool() { # holder_tool <slot>
  local tool; tool="$(meta_field "$1" tool)"
  [ -n "$tool" ] || tool="an unidentified tool"
  printf '%s' "$tool"
}

# Absent means a pre-handshake script wrote this lock, which is version 0 — not
# an error, and not something to choke on.
lock_protocol_version() { # lock_protocol_version <slot>
  local raw; raw="$(meta_field "$1" protocol_version)"
  case "$raw" in
    ''|*[!0-9]*) printf '0' ;;
    *) printf '%s' "$raw" ;;
  esac
}

# Fires at the moment of contention, in the transcript of the agent about to
# cause harm — the one place a drift warning cannot be forgotten the way a docs
# note or a commit hook can. Warn and continue: refusing outright would let one
# old checkout wedge the simulators for everybody.
#
# A v1 holder on slot 1 is the EXPECTED state during the pool rollout, not drift:
# v1 and v2 still exclude each other there, which is the whole point of keeping
# slot 1's path. Only a version we do not recognize at all is worth shouting about.
warn_protocol_drift() {
  [ "${simlock_drift_warned:-0}" = 1 ] && return 0
  local slot theirs
  for slot in $(slot_numbers); do
    [ -d "$(slot_lock_dir "$slot")" ] || continue
    # `mkdir` and the meta write are not one step. A lock caught inside that
    # window has no meta.json to read a version out of, and reporting that as
    # "v0" would cry drift at a healthy same-version holder every time we polled
    # at the wrong millisecond.
    [ -f "$(slot_meta "$slot")" ] || continue
    theirs="$(lock_protocol_version "$slot")"
    [ "$theirs" = "$SIMLOCK_PROTOCOL_VERSION" ] && continue
    # v3 differs from v2 by one added key. Exclusion, queue order, the steal
    # timer and idle self-release are unchanged, so a v2 holder is not the
    # dangerous kind of drift — it just publishes no keep-alive pid for us to
    # check. Shouting red here would train everyone to ignore the red.
    if [ "$theirs" = 2 ]; then
      simlock_drift_warned=1
      say "${c_ylw}note: slot ${slot} is held by a v2 checkout ('$(holder_label "$slot")', $(holder_tool "$slot")).${c_rst}"
      say "${c_ylw}      Queueing, stealing and idle release are unchanged; it publishes no${c_rst}"
      say "${c_ylw}      keep-alive pid, so judge it by beat and idle age alone.${c_rst}"
      audit protocol-v2-holder "slot=$slot holder='$(holder_label "$slot")'"
      return 0
    fi
    if [ "$theirs" = 1 ] && [ "$slot" = 1 ]; then
      simlock_drift_warned=1
      say "${c_ylw}note: slot 1 is held by a v1 checkout ('$(holder_label "$slot")', $(holder_tool "$slot")).${c_rst}"
      say "${c_ylw}      It cannot see the rest of the pool, so it will never take another slot.${c_rst}"
      say "${c_ylw}      Exclusion on slot 1 still holds. Pull that repo to give it the whole pool.${c_rst}"
      audit protocol-v1-holder "slot=$slot holder='$(holder_label "$slot")'"
      return 0
    fi
    simlock_drift_warned=1
    say "${c_red}!! SIM LOCK PROTOCOL DRIFT: this checkout ($SIMLOCK_TOOL) speaks v${SIMLOCK_PROTOCOL_VERSION};${c_rst}"
    say "${c_red}!! slot ${slot}, held by '$(holder_label "$slot")' ($(holder_tool "$slot")), was written by v${theirs}.${c_rst}"
    say "${c_red}!! The two checkouts of simlock.sh have drifted, so the pool's guarantees —${c_rst}"
    say "${c_red}!! queue order, idle self-release, the steal timer — may not hold on both sides.${c_rst}"
    say "${c_red}!! Waiting and stealing still work. Pull both repos before trusting the queue.${c_rst}"
    audit protocol-drift "ours=v${SIMLOCK_PROTOCOL_VERSION} theirs=v${theirs} slot=$slot holder='$(holder_label "$slot")'"
    return 0
  done
  return 0
}

audit() {
  local event="$1" label="${2:-}"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  if [ "$(stat -f %z "$AUDIT_LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    tail -c 524288 "$AUDIT_LOG" > "$AUDIT_LOG.tmp" && mv "$AUDIT_LOG.tmp" "$AUDIT_LOG"
  fi
  printf '%s repo=%s event=%s label=%s session=%s pid=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SIMLOCK_TOOL" "$event" "$label" \
    "$(cat "$SESSION_FILE" 2>/dev/null || echo -)" "$$" >> "$AUDIT_LOG"
}

tombstone_file() { printf '%s/tombstone.%s.json' "$TOMBSTONE_DIR" "$1"; }

write_tombstone() { # write_tombstone <victim_session> <victim_label> <thief_label> <slot>
  mkdir -p "$TOMBSTONE_DIR"
  # A victim that never came back leaves its notice forever; a day is long past
  # the point where anyone is still going to read one.
  find "$TOMBSTONE_DIR" -type f -mtime +1 -delete 2>/dev/null || true
  python3 -c '
import json, sys, datetime
json.dump({
    "victim_session": sys.argv[2], "victim_label": sys.argv[3], "thief_label": sys.argv[4],
    "slot": int(sys.argv[5]),
    "stolen_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}, open(sys.argv[1], "w"))
' "$(tombstone_file "$1")" "$1" "$2" "$3" "$4"
}

# A steal is otherwise silent for its victim: the victim's next command says
# "another agent holds", which is indistinguishable from never having acquired,
# and an agent that believes it still holds a sim keeps driving it underneath the
# thief. The thief leaves a tombstone keyed by the victim's session id so the
# victim is told what happened, and by whom, and stops.
stolen_report() {
  local mine tomb thief when slot
  mine="$(cat "$SESSION_FILE" 2>/dev/null || true)"
  [ -n "$mine" ] || return 1
  tomb="$(tombstone_file "$mine")"
  [ -f "$tomb" ] || return 1
  thief="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("thief_label",""))' "$tomb" 2>/dev/null || true)"
  when="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("stolen_at",""))' "$tomb" 2>/dev/null || true)"
  slot="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("slot",""))' "$tomb" 2>/dev/null || true)"
  say "${c_red}Slot ${slot:-?} of the $SIMLOCK_RESOURCE pool was stolen by '${thief}' at ${when}: our heartbeat went stale (> ${TTL}s without activity).${c_rst}"
  say "Do not touch the simulator — another agent may be driving it. Re-run acquire to queue."
  [ "${1:-}" = "consume" ] && rm -f "$tomb"
  return 0
}

# We hold a slot iff OUR worktree's session id matches that slot's session id.
# The session file is how a single agent proves ownership across its many
# separate bash calls (there is no long-lived process to check a pid against),
# and it must never be shared between agents: a machine-global path made every
# agent read every other agent's session id, so ownership answered "yes" to
# whoever asked — `status` reported "held by us" to sessions that held nothing,
# `release` tore down a stranger's stack, and a waiter could believe it owned a
# lock it was still queued for. gto-poker-ios hit and fixed the identical bug (#285).
#
# Which slot we hold is DERIVED from that same token rather than recorded in a
# second file. A second file is a second thing to get out of sync, and the state
# it would drift into — "we think we hold slot 2, the pool says slot 2 is
# somebody else's" — is precisely the bug the session token exists to prevent.
held_slot() {
  local mine slot
  mine="$(cat "$SESSION_FILE" 2>/dev/null || true)"
  [ -n "$mine" ] || return 1
  for slot in $(slot_numbers); do
    [ -d "$(slot_lock_dir "$slot")" ] || continue
    if [ "$mine" = "$(meta_field "$slot" session)" ]; then printf '%s' "$slot"; return 0; fi
  done
  return 1
}

# The two questions the sourcing tool asks: which slot, and therefore which sim.
simlock_current_slot() { held_slot; }
simlock_current_sim() { local slot; slot="$(held_slot)" || return 1; slot_sim "$slot"; }

# Refresh the heartbeat without touching the simulator, for a caller that holds a
# slot across work this script never sees (minutes inside `xcodebuild` call none
# of the wrapped commands, so the lock aged past the TTL and a waiter stole it
# out from under a live run). Non-zero once we no longer hold anything, so a
# keep-alive loop ends rather than refreshing a slot that now belongs to someone
# else. Deliberately NOT a public verb: the only thing an agent could do with one
# is defend a slot it is not using, which is the incident this file is named for.
heartbeat_if_owner() {
  local slot; slot="$(held_slot)" || return 1
  touch "$(slot_lock_dir "$slot")" "$(slot_meta "$slot")"
  return 0
}

# The keep-alive publishes ITS OWN pid into the slot, because meta.json is the
# only place another session can read it — KEEPALIVE_PID_FILE lives at a path
# only the holder's own worktree can derive. Rewritten in place rather than
# merged into the acquire write: the keep-alive is a different process, started
# after the meta exists.
#
# Atomic, and only ever onto a meta that is already there. A half-written
# meta.json is worse than a missing key: meta_field swallows the parse error and
# returns empty, so a reader catching the truncation would see no session (we
# stop holding our own slot), no holder name, and protocol_version 0 — a drift
# banner against a healthy same-version agent.
publish_keepalive_pid() { # publish_keepalive_pid <slot> <pid>
  local meta; meta="$(slot_meta "$1")"
  [ -f "$meta" ] || return 0
  python3 - "$meta" "$2" <<'PY' 2>/dev/null || true
import json, os, sys, tempfile
meta, pid = sys.argv[1], int(sys.argv[2])
try:
    with open(meta) as handle:
        data = json.load(handle)
except Exception:
    sys.exit(0)
if data.get("keepalive_pid") == pid:
    sys.exit(0)
data["keepalive_pid"] = pid
directory = os.path.dirname(meta)
fd, tmp = tempfile.mkstemp(dir=directory)
try:
    with os.fdopen(fd, "w") as handle:
        json.dump(data, handle)
    os.replace(tmp, meta)
except Exception:
    os.unlink(tmp)
PY
}

# Whether a process that is genuinely supposed to outlive the hold is still
# there. The ACQUIRING shell's pid answers nothing: an agent works across many
# short-lived bash calls, so it exits the moment `acquire` returns and every
# healthy hold then printed "pid NNNN dead" beside a 0-second heartbeat
# (lilium#1054). Two sessions in one hour read that as a crashed holder, and the
# only thing standing between that reading and a force-release on a live run is
# FORCE_MIN_IDLE. The keep-alive is the process that IS alive for the whole hold,
# so it is the one to name. Same pid-reuse guard as stop_keepalive: a recycled
# pid must not read as alive.
holder_liveness() { # holder_liveness <slot>
  local pid; pid="$(meta_field "$1" keepalive_pid)"
  if [ -z "$pid" ]; then
    printf 'no keep-alive pid'
    return 0
  fi
  case "$(ps -o command= -p "$pid" 2>/dev/null || true)" in
    *keepalive-loop*) printf 'keep-alive %s alive' "$pid" ;;
    *) printf 'keep-alive %s dead' "$pid" ;;
  esac
}

# Only a command the agent actually ran stamps this. The keep-alive reads it and
# never writes it, which is the whole point.
stamp_activity() { # stamp_activity <slot>
  : > "$ACTIVITY_FILE"
  [ -n "${1:-}" ] && [ -d "$(slot_lock_dir "$1")" ] && : > "$(slot_activity "$1")"
  return 0
}

activity_age() {
  local mt; mt="$(stat -f %m "$ACTIVITY_FILE" 2>/dev/null || echo 0)"
  [ "$mt" -eq 0 ] && { echo 0; return; }
  echo $(( $(now) - mt ))
}

# Seconds since a slot's CURRENT HOLDER last ran a real command — readable by
# anyone, unlike activity_age. Falls back to the meta mtime for a holder running
# a pre-handshake copy, which only ever over-states liveness (the keep-alive
# beats that file), never under-states it.
holder_idle() { # holder_idle <slot>
  local mt; mt="$(stat -f %m "$(slot_activity "$1")" 2>/dev/null || echo 0)"
  if [ "$mt" -eq 0 ]; then mt="$(meta_mtime "$1")"; fi
  if [ "$mt" -eq 0 ]; then echo 0; return; fi
  echo $(( $(now) - mt ))
}

free_slots() {
  local slot count=0
  for slot in $(slot_numbers); do [ -d "$(slot_lock_dir "$slot")" ] || count=$((count + 1)); done
  printf '%s' "$count"
}

# --- the FIFO queue -----------------------------------------------------------
# A bare `mkdir` race let whoever happened to poll at the right moment barge in
# front of an agent that had been waiting twenty minutes, and gave a waiter no
# way to answer "how long, and behind whom?". Each waiter now drops a ticket here
# and may only claim a slot while its position is within the number of FREE ones.
#
# The directory is a SIBLING of the lock dirs, never a child: a lock dir is
# `rm -rf`'d on every release and every steal, which would take the queue with
# it. Both tools derive it from the same LOCK_ROOT — and it is the v1 path
# unchanged, so a v1 waiter and a v2 waiter stand in one line.
WAITERS_DIR="${LOCK_ROOT%/}.waiters"
TICKET_FILE=""

# Tickets sort by filename, which starts with a 10-digit epoch — lexical order is
# arrival order for the next two centuries. A same-second tie breaks on pid:
# arbitrary, but every waiter reads the same order, which is the property that
# actually matters.
# shellcheck disable=SC2012  # we generate every name here: <epoch>.<pid>.<rand>,
# digits and dots only. `ls` also skips dotfiles, which is what keeps a ticket
# still being written (see take_ticket) out of the queue.
ticket_ids() { ls "$WAITERS_DIR" 2>/dev/null | sort; }
ticket_born() { printf '%s' "${1%%.*}"; }
ticket_pid() { printf '%s' "${1#*.}" | cut -d. -f1; }
ticket_label() { sed -n 1p "$WAITERS_DIR/$1" 2>/dev/null; }

# A waiter's patience belongs to that waiter, so it is written INTO its ticket
# and read back per-ticket here. Pruning on the pruner's own MAXWAIT instead
# meant any agent with a short one deleted everybody else's place in line: a
# scheduled sweep polls with SHOTS_LOCK_MAXWAIT=0 precisely so it never queues,
# and that value emptied the entire queue every time it ran. Observed live —
# one impatient acquire dropped two agents who had been waiting 19 minutes and
# 2 minutes. (They re-take a ticket on their next poll, so it reads as an
# unfair queue rather than a hang, which is why it went unnoticed.)
#
# A ticket with no recorded patience was written by a pre-pool script; fall back
# to the DEFAULT rather than to ours, which is the same thing every version
# would have used.
ticket_maxwait() {
  local raw; raw="$(sed -n 2p "$WAITERS_DIR/$1" 2>/dev/null)"
  case "$raw" in
    ''|*[!0-9]*) printf '%s' "$SIMLOCK_DEFAULT_MAXWAIT" ;;
    *) printf '%s' "$raw" ;;
  esac
}

# A crashed waiter must not stall the line: liveness beats strict fairness. Drop
# tickets whose process is gone, and any that outlived MAXWAIT — its owner has
# given up by then whatever its pid is doing now.
prune_tickets() {
  local id pid age
  for id in $(ticket_ids); do
    pid="$(ticket_pid "$id")"
    age=$(( $(now) - $(ticket_born "$id") ))
    if [ -n "$pid" ] && [ "$age" -lt "$(ticket_maxwait "$id")" ] && ps -p "$pid" >/dev/null 2>&1; then continue; fi
    rm -f "$WAITERS_DIR/$id"
  done
  return 0
}

# Written under a DOTTED temp name and renamed into place, so a reader polling
# mid-write neither sees a half-written label nor counts the temp file as a
# second ticket — ticket_ids lists no dotfiles, and rename is atomic.
take_ticket() {
  local label="$1" partial
  mkdir -p "$WAITERS_DIR"
  partial="$WAITERS_DIR/.partial.$$"
  TICKET_FILE="$WAITERS_DIR/$(now).$$.${RANDOM}"
  # Line 1 the label, line 2 how long WE will wait — so no other agent's
  # impatience can time our ticket out. See ticket_maxwait.
  printf '%s\n%s\n' "$label" "$MAXWAIT" > "$partial"
  mv -f "$partial" "$TICKET_FILE"
}

drop_ticket() {
  [ -n "$TICKET_FILE" ] && rm -f "$TICKET_FILE"
  rm -f "$WAITERS_DIR/.partial.$$"
  TICKET_FILE=""
  return 0
}

queue_depth() { ticket_ids | grep -c . || true; }

queue_position() { # 1-based place of OUR ticket, 0 if we hold none
  local id index=0
  for id in $(ticket_ids); do
    index=$((index + 1))
    if [ "$WAITERS_DIR/$id" = "$TICKET_FILE" ]; then echo "$index"; return 0; fi
  done
  echo 0
}

ordinal() {
  local n="$1"
  case "$(( n % 100 ))" in 11|12|13) printf '%dth' "$n"; return 0 ;; esac
  case "$(( n % 10 ))" in
    1) printf '%dst' "$n" ;;
    2) printf '%dnd' "$n" ;;
    3) printf '%drd' "$n" ;;
    *) printf '%dth' "$n" ;;
  esac
}

queue_lines() { # queue_lines [indent]
  local indent="${1:-}" id index=0
  for id in $(ticket_ids); do
    index=$((index + 1))
    say "${indent}$(ordinal "$index"): '$(ticket_label "$id")' (waiting $(( $(now) - $(ticket_born "$id") ))s)"
  done
  return 0
}

# --- the idle-hold warning ----------------------------------------------------
# An idle holder is invisible to itself. The incident behind this file had an
# agent sit on the lock for two hours doing code-only work while several named
# sessions queued — nothing ever told it so. Say it in the holder's own
# transcript, by name, well before the keep-alive's IDLE_GRACE takes it back.
# A queued agent means every slot is taken, so an idle holder is still the thing
# standing in its way even when it is only one of several.
warn_idle_with_waiters() { # warn_idle_with_waiters <idle-seconds> <slot>
  local idle="$1" slot="$2" depth
  [ "$idle" -ge $(( IDLE_GRACE / 2 )) ] || return 0
  prune_tickets
  depth="$(queue_depth)"
  [ "$depth" -gt 0 ] || return 0
  say ""
  say "${c_red}!! You have held slot ${slot} ($(slot_sim "$slot")) for ${idle}s WITHOUT driving it, and ${depth} agent(s) are queued:${c_rst}"
  queue_lines "${c_red}!!     "
  say "${c_red}!! Run 'shots.sh release' now unless your very next command needs the simulator."
  say "!! The keep-alive hands an idle slot back on its own, but that is $(( IDLE_GRACE - idle ))s away.${c_rst}"
  say ""
  audit idle-warning "$(holder_label "$slot") (slot $slot, idle ${idle}s, ${depth} waiting)"
  return 0
}

assert_held() {
  local slot
  if slot="$(held_slot)"; then
    local idle; idle="$(activity_age)"   # read BEFORE stamping, or it is always 0
    touch "$(slot_lock_dir "$slot")" "$(slot_meta "$slot")"   # heartbeat
    stamp_activity "$slot"
    warn_idle_with_waiters "$idle" "$slot"
    return 0
  fi
  if stolen_report consume; then
    die "our slot in the $SIMLOCK_RESOURCE pool is no longer ours."
  fi
  [ "$(free_slots)" -lt "$(slot_count)" ] \
    || die "no screenshot slot held — run: shots.sh acquire \"<label>\" first."
  warn_protocol_drift
  die "we hold no slot; every $SIMLOCK_RESOURCE is taken by another agent — re-run acquire to queue."
}

cmd_acquire() {
  local label="${1:?usage: acquire \"<label>\"}"
  mkdir -p "$STATE_DIR" "$(dirname "$LOCK_ROOT")"
  local mine; mine="$(cat "$SESSION_FILE" 2>/dev/null || true)"
  if [ -n "$mine" ] && [ -f "$(tombstone_file "$mine")" ]; then
    say "${c_ylw}Note: our previous hold was stolen after its heartbeat went stale — queueing fresh.${c_rst}"
    rm -f "$(tombstone_file "$mine")"
  fi
  # Re-entrant: a session that already holds a slot (a screenshot run that then
  # invokes the test script) would otherwise queue behind itself until its own
  # heartbeat went stale — a TTL-long wait for a sim it already owns.
  local slot
  if slot="$(held_slot)"; then
    local idle; idle="$(activity_age)"
    touch "$(slot_lock_dir "$slot")" "$(slot_meta "$slot")"
    stamp_activity "$slot"
    start_keepalive "$label"
    say "${c_grn}Already holding slot ${slot} ($(slot_sim "$slot")) for '$(holder_label "$slot")' — reusing.${c_rst}"
    warn_idle_with_waiters "$idle" "$slot"
    return 0
  fi

  local start waiting_logged=false last_note=-1 last_pos=-1
  start="$(now)"
  take_ticket "$label"
  # The ticket must not outlive this shell: a waiter killed at the keyboard would
  # otherwise sit at the head of the queue forever, and every real waiter behind
  # it would wait out MAXWAIT before the pruner timed it out.
  trap 'drop_ticket' EXIT INT TERM
  while true; do
    prune_tickets
    local pos; pos="$(queue_position)"
    # Our own ticket can be pruned out from under us once it passes MAXWAIT.
    # Retake it rather than silently leaving the line.
    if [ "$pos" -eq 0 ]; then take_ticket "$label"; pos="$(queue_position)"; fi

    # Anyone within the number of free slots may claim one, so two free slots
    # serve the front two waiters in the same poll rather than one per POLL.
    # `mkdir` settles who lands where; a loser just re-polls. Nobody deeper in
    # the line can barge, which is the fairness property that actually matters.
    if [ "$pos" -le "$(free_slots)" ]; then
      for slot in $(slot_numbers); do
        local dir; dir="$(slot_lock_dir "$slot")"
        if mkdir "$dir" 2>/dev/null; then
          local sid; sid="$(now)-$$-${RANDOM}${RANDOM}"
          python3 - "$(slot_meta "$slot")" "$label" "$sid" "$$" "$SIMLOCK_TOOL" \
                    "$SIMLOCK_PROTOCOL_VERSION" "$slot" "$(slot_sim "$slot")" <<'PY'
import json, sys, datetime
json.dump({
    # "feature" and "label" are the same string under two keys: lilium keys the
    # holder name "feature" and gto keys it "label", and each writes both so the
    # other names the holder correctly when it finds this slot taken.
    "feature": sys.argv[2], "label": sys.argv[2], "session": sys.argv[3], "pid": int(sys.argv[4]),
    "tool": sys.argv[5], "protocol_version": int(sys.argv[6]),
    "slot": int(sys.argv[7]), "sim": sys.argv[8],
    "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}, open(sys.argv[1], "w"))
PY
          printf '%s' "$sid" > "$SESSION_FILE"
          stamp_activity "$slot"
          # Disarm any pending idle shutdown of this sim — see cmd_idle_shutdown.
          rm -f "$(idle_token_file "$slot")"
          audit acquire "$label (slot $slot, $(slot_sim "$slot"))"
          start_keepalive "$label"
          drop_ticket
          trap - EXIT INT TERM
          say "${c_grn}Acquired slot ${slot} of the $SIMLOCK_RESOURCE pool — sim '$(slot_sim "$slot")' — for '$label'.${c_rst}"
          say "Release it the moment your last simulator command is done — other agents"
          say "queue for a free slot. Idle ${IDLE_GRACE}s and it releases itself."
          if declare -F simlock_on_acquired >/dev/null 2>&1; then simlock_on_acquired "$label" "$slot"; fi
          return 0
        fi
        # Something that is not a lock dir is squatting on the path — a stray
        # file from a botched `touch`, an interrupted copy. `mkdir` can never
        # succeed against it and no heartbeat will ever age it out, so every
        # waiter would sit there until MAXWAIT against nothing. Clear it.
        if [ ! -d "$dir" ]; then
          say "${c_ylw}Clearing a non-directory at $dir — nothing can hold a slot there.${c_rst}"
          audit clear-garbage "$label (slot $slot)"
          rm -rf "$dir"
        fi
      done
    fi

    # Head of the line and every slot is taken: only the head ever steals, so a
    # steal can never jump the queue. Ownership is proven by the heartbeat (the
    # meta mtime), NOT by a pid: an agent works across many separate bash calls
    # with no long-lived process, so a pid check would read "dead" the instant
    # acquire returned and defeat the lock entirely. Slots are tried in order and
    # the first stale one is taken — one steal per pass, never a sweep.
    if [ "$pos" -eq 1 ]; then
      # Only re-enter the loop immediately when a steal actually freed something.
      # An unconditional `continue` here skipped the MAXWAIT check and the sleep
      # below, so the head of the queue spun at full tilt against a pool of live
      # holders and never timed out — a wait that could not end.
      local stole=false
      for slot in $(slot_numbers); do
        [ -d "$(slot_lock_dir "$slot")" ] || continue
        local mt age holder; mt="$(meta_mtime "$slot")"; holder="$(holder_label "$slot")"
        # `mkdir` and the meta write are not one atomic step. A slot caught
        # inside that window has no meta.json yet; fall back to the lock dir's
        # own mtime rather than reading epoch-0 as "infinitely stale" and
        # stealing a slot somebody acquired 40ms ago.
        if [ "$mt" -eq 0 ]; then mt="$(stat -f %m "$(slot_lock_dir "$slot")" 2>/dev/null || echo 0)"; fi
        age=$(( $(now) - mt ))
        [ "$mt" -eq 0 ] || [ "$age" -gt "$TTL" ] || continue
        say "${c_ylw}Slot ${slot} is stale (${age}s since activity > ${TTL}s) — stealing from '$holder'.${c_rst}"
        local victim; victim="$(meta_field "$slot" session)"
        if [ -n "$victim" ]; then write_tombstone "$victim" "$holder" "$label" "$slot"; fi
        audit steal "$label (slot $slot, victim: '$holder')"
        if declare -F simlock_teardown >/dev/null 2>&1; then simlock_teardown "$slot"; fi
        rm -rf "$(slot_lock_dir "$slot")"
        stole=true
        break
      done
      [ "$stole" = true ] && continue
    fi

    warn_protocol_drift
    local waited; waited=$(( $(now) - start ))
    if [ "$waited" -ge "$MAXWAIT" ]; then
      die "waited ${waited}s for a free slot; giving up. Re-run acquire, or clear $LOCK_ROOT* if it is truly abandoned."
    fi
    if [ "$waiting_logged" = false ]; then audit wait-start "$label"; waiting_logged=true; fi
    # Repeat the position line only when something changed, or once a minute —
    # one line per poll is noise, and noise is what nobody reads.
    if [ "$pos" != "$last_pos" ] || [ "$waited" -ge $(( last_note + WAIT_NOTE_INTERVAL )) ]; then
      last_pos="$pos"; last_note="$waited"
      say "waiting: $(ordinal "$pos") of $(queue_depth) for one of $(slot_count) slots (${waited}s elapsed)"
      local held; for held in $(slot_numbers); do
        [ -d "$(slot_lock_dir "$held")" ] || continue
        say "  slot $held ($(slot_sim "$held")): '$(holder_label "$held")', idle $(holder_idle "$held")s"
      done
    fi
    sleep "$POLL"
  done
}

# --- reclaiming a slot's simulator on the way out -----------------------------
# A simulator nobody is waiting for is pure cost: each one carries gigabytes of
# exhaust that nothing ever GCs — os_log diagnostics under var/db/diagnostics,
# system caches, and the install containers CoreSimulator orphans into
# `Caches/com.apple.containermanagerd/Dead/` on every reinstall and then never
# deletes. A two-sim pool doubles that bill, and slot 2 in particular sits cold
# between the rare moments there are two agents, so it is the last thing that
# should be holding disk.
#
# So a release with an EMPTY QUEUE hands the disk back. A release with someone
# waiting does not touch a thing: the next holder wants this sim warm, and an
# erase would charge them a ~2 GB MobileAsset re-download on the next boot for a
# device that is about to be reinstalled onto anyway.
#
# But "nobody is waiting" is usually only true for a minute. Agents release and
# re-acquire between steps, and shutting down on every quiet release cold-booted
# screenshots-1 26 times in one afternoon, some of them seconds apart — each a
# full iOS boot (SpringBoard, the wallpaper renderer, every daemon) at 100%+ CPU
# that the next run then waited on. So the shutdown is DEFERRED:
#   * At release — reap the Dead containers. Pure reclaim: `Dead/` only ever
#     holds containers CoreSimulator has already orphaned, so the live app never
#     reads from it, and it does not need the device down.
#   * SIM_IDLE_SHUTDOWN seconds later, if nobody has taken the slot since — shut
#     the device down, and over RECLAIM_MIN_MB also `simctl erase` it. The erase
#     is what actually clears the diagnostics and what costs the re-download, so
#     it stays gated on the device being genuinely fat. The test is `>=`, so
#     SHOTS_RECLAIM_MIN_MB=0 erases on every quiet shutdown (`du -sm` floors a
#     nearly-empty device to 0). SHOTS_RECLAIM=0 turns the whole thing off.
#
# The deferred half runs detached (an agent's bash call does not live 15
# minutes) and proves the slot stayed idle with a per-slot token: each quiet
# release writes a fresh one and every acquire deletes it, so a sleeper whose
# token is gone or replaced knows the slot was used since and stands down.
RECLAIM="${SHOTS_RECLAIM:-1}"
RECLAIM_MIN_MB="${SHOTS_RECLAIM_MIN_MB:-4000}"
SIM_IDLE_SHUTDOWN="${SHOTS_SIM_IDLE_SHUTDOWN:-900}"
SIM_DEVICES_DIR="${SHOTS_SIM_DEVICES_DIR:-$HOME/Library/Developer/CoreSimulator/Devices}"
# Path segment every reap target must contain — a guard so a malformed device
# dir can never widen the `rm -rf` beyond a containermanagerd Dead orphan.
RECLAIM_GUARD="Caches/com.apple.containermanagerd/Dead"
# A sibling of the lock dirs, like the waiters queue: the token must outlive the
# `rm -rf` of the slot's lock dir on release, and both tools must find it.
IDLE_TOKEN_DIR="${LOCK_ROOT%/}.idle-shutdown"
idle_token_file() { printf '%s/slot%s' "$IDLE_TOKEN_DIR" "$1"; }

sim_udid_named() { # sim_udid_named <name> -> udid of the available device with that exact name
  xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
data = json.load(sys.stdin).get("devices", {})
for devices in data.values():
    for device in devices:
        if device.get("name") == want:
            print(device.get("udid", "")); raise SystemExit
' "$1" 2>/dev/null || true
}

device_mb() { # device_mb <udid>
  local dir="$SIM_DEVICES_DIR/$1"
  [ -d "$dir" ] || { echo 0; return; }
  du -sm "$dir" 2>/dev/null | cut -f1 || echo 0
}

reap_dead_containers() { # reap_dead_containers <udid> -> MB reclaimed
  local dead="$SIM_DEVICES_DIR/$1/data/Library/$RECLAIM_GUARD" before
  [ -d "$dead" ] || { echo 0; return; }
  # Defence in depth: never act on a path that lost the expected guard segment.
  case "$dead" in
    *"/$RECLAIM_GUARD") : ;;
    *) echo 0; return ;;
  esac
  before="$(du -sm "$dead" 2>/dev/null | cut -f1)"; before="${before:-0}"
  rm -rf "${dead:?}/"* 2>/dev/null || true
  echo "$before"
}

# Called from every path that gives a slot up voluntarily — release and the
# keep-alive's idle auto-release. NOT from a steal: a thief wants the sim.
reclaim_slot_sim() { # reclaim_slot_sim <slot>
  [ "$RECLAIM" = "1" ] || return 0
  local slot="$1" sim udid reaped token
  prune_tickets
  if [ "$(queue_depth)" -gt 0 ]; then
    say "Leaving $(slot_sim "$slot") warm — $(queue_depth) agent(s) queued for it."
    return 0
  fi
  sim="$(slot_sim "$slot")"
  udid="$(sim_udid_named "$sim")"
  [ -n "$udid" ] || return 0
  reaped="$(reap_dead_containers "$udid")"
  token="$(now)-$$-${RANDOM}${RANDOM}"
  mkdir -p "$IDLE_TOKEN_DIR"
  printf '%s' "$token" > "$(idle_token_file "$slot")"
  nohup "$SIMLOCK_SCRIPT_PATH" idle-shutdown "$slot" "$token" </dev/null >/dev/null 2>&1 &
  disown $! 2>/dev/null || true
  audit reclaim-reap "$sim (slot $slot, reaped ${reaped}MB, shutdown in ${SIM_IDLE_SHUTDOWN}s if unused)"
  say "${c_grn}Reclaimed $sim: ${reaped}MB of dead containers reaped; left booted, shuts down after ${SIM_IDLE_SHUTDOWN}s unused.${c_rst}"
  return 0
}

# The deferred half of reclaim_slot_sim, run detached. It takes the slot's lock
# itself for the shutdown, so an agent arriving mid-shutdown queues for a few
# seconds instead of booting a device that is going down under it.
cmd_idle_shutdown() { # cmd_idle_shutdown <slot> <token>
  local slot="${1:?}" token="${2:?}" tokfile sim udid mb dir
  sleep "$SIM_IDLE_SHUTDOWN"
  tokfile="$(idle_token_file "$slot")"
  [ "$(cat "$tokfile" 2>/dev/null || true)" = "$token" ] || return 0
  prune_tickets
  [ "$(queue_depth)" -eq 0 ] || return 0
  dir="$(slot_lock_dir "$slot")"
  mkdir "$dir" 2>/dev/null || return 0
  printf '{"feature":"idle-shutdown","label":"idle-shutdown","tool":"%s","protocol_version":%s,"slot":%s}' \
    "$SIMLOCK_TOOL" "$SIMLOCK_PROTOCOL_VERSION" "$slot" > "$(slot_meta "$slot")"
  # Re-check under the lock: an acquire that landed between the token read and
  # the mkdir deleted the token and has since released, or it would still hold.
  if [ "$(cat "$tokfile" 2>/dev/null || true)" = "$token" ]; then
    rm -f "$tokfile"
    sim="$(slot_sim "$slot")"
    udid="$(sim_udid_named "$sim")"
    if [ -n "$udid" ]; then
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      mb="$(device_mb "$udid")"
      if [ "$mb" -ge "$RECLAIM_MIN_MB" ]; then
        # logd refuses `log erase` on a booted device, which is why the shutdown
        # above is not optional.
        xcrun simctl erase "$udid" >/dev/null 2>&1 || true
        audit reclaim-erase "$sim (slot $slot, was ${mb}MB)"
      else
        audit idle-shutdown "$sim (slot $slot, ${mb}MB)"
      fi
    fi
  fi
  rm -rf "$dir"
  return 0
}

# Exits non-zero when it did NOT release. It used to return 0 with a yellow note
# that reads like success, and to drop SESSION_FILE on every branch — so a
# release that could not prove ownership left the lock held AND destroyed the
# only token that could ever release it, and it sat until its TTL while everyone
# else queued (lilium#1016). The token now survives a failed release, and
# `force-release` is the supported way out.
cmd_release() {
  stop_keepalive
  local slot
  if slot="$(held_slot)"; then
    local label; label="$(holder_label "$slot")"
    if declare -F simlock_teardown >/dev/null 2>&1; then simlock_teardown "$slot"; fi
    audit release "$label (slot $slot)"
    reclaim_slot_sim "$slot"
    rm -rf "$(slot_lock_dir "$slot")"
    rm -f "$SESSION_FILE" "$ACTIVITY_FILE"
    say "${c_grn}Released slot ${slot} ($(slot_sim "$slot")).${c_rst}"
    return 0
  fi
  if stolen_report consume; then
    rm -f "$SESSION_FILE" "$ACTIVITY_FILE"
    return 0
  fi
  if [ "$(free_slots)" -lt "$(slot_count)" ]; then
    say "${c_red}NOT released: we cannot prove any held slot is ours.${c_rst}"
    for slot in $(slot_numbers); do
      [ -d "$(slot_lock_dir "$slot")" ] || continue
      say "    slot $slot ($(slot_sim "$slot")) is held by '$(holder_label "$slot")' ($(holder_tool "$slot"))"
    done
    say "If one of those holds is yours, take it back with:"
    say "    shots.sh force-release \"<holder label>\""
    return 1
  fi
  say "No slot held; nothing to release."
  rm -f "$SESSION_FILE" "$ACTIVITY_FILE"
  return 0
}

# The recovery path for a hold whose session token no longer matches — the state
# that previously left `rm -rf` on the lock dir as the only way out. Refuses
# unless the caller names the current holder exactly, and unless that holder has
# actually gone quiet, so it cannot be used to barge in on a live agent. The
# quiet test reads the holder's ACTIVITY stamp, not its heartbeat: the keep-alive
# beats the heartbeat every minute, so an idle-time test against that would
# refuse forever.
cmd_force_release() {
  local want="${1:-}" confirm="${2:-}"
  [ -n "$want" ] || die "usage: force-release \"<holder label>\" [--yes]  (see: shots.sh status)"
  local slot match="" matches=0
  for slot in $(slot_numbers); do
    [ -d "$(slot_lock_dir "$slot")" ] || continue
    [ "$(holder_label "$slot")" = "$want" ] || continue
    match="$slot"; matches=$((matches + 1))
  done
  if [ "$matches" -eq 0 ]; then
    if [ "$(free_slots)" -eq "$(slot_count)" ]; then
      say "No slot held; nothing to release."; rm -f "$SESSION_FILE" "$ACTIVITY_FILE"; return 0
    fi
    die "no slot is held by '$want' — run 'shots.sh status' and pass the exact label."
  fi
  # Two agents can pick the same label, and guessing which one to cut off is the
  # kind of coin-flip this whole file exists to avoid.
  [ "$matches" -eq 1 ] \
    || die "'$want' holds $matches slots — release them one at a time from the agent that owns each."
  slot="$match"
  local holder idle; holder="$(holder_label "$slot")"; idle="$(holder_idle "$slot")"
  if [ "$idle" -lt "$FORCE_MIN_IDLE" ] && [ "$confirm" != "--yes" ]; then
    die "'$holder' ran something ${idle}s ago (< ${FORCE_MIN_IDLE}s) and may be live. Re-run with --yes if you are certain."
  fi
  # Only stop OUR keep-alive, and only when the slot we are cutting is one we
  # think we hold. Force-releasing somebody else's slot must not kill the loop
  # defending our own.
  local ours; if ours="$(held_slot)" && [ "$ours" = "$slot" ]; then stop_keepalive; fi
  if declare -F simlock_teardown >/dev/null 2>&1; then simlock_teardown "$slot"; fi
  rm -rf "$(slot_lock_dir "$slot")"
  if [ -n "${ours:-}" ] && [ "${ours:-}" = "$slot" ]; then rm -f "$SESSION_FILE" "$ACTIVITY_FILE"; fi
  audit force-release "$holder (slot $slot, idle ${idle}s)"
  say "${c_grn}Force-released '$holder' from slot ${slot} ($(slot_sim "$slot")).${c_rst}"
}

# A hold that cannot leak: acquire, run, release from a trap, whatever happens to
# the command in between — including the SIGTERM a killed background job gets.
cmd_run() {
  local label="${1:-}"; shift || true
  [ -n "$label" ] || die "usage: run \"<label>\" -- <command> [args…]"
  [ "${1:-}" = "--" ] && shift
  [ "$#" -gt 0 ] || die "usage: run \"<label>\" -- <command> [args…]"
  cmd_acquire "$label"
  trap 'cmd_release >/dev/null 2>&1 || true' EXIT INT TERM
  local rc=0
  "$@" || rc=$?
  return "$rc"
}

# Ownership as an exit code, for scripts that must not touch a slot the calling
# agent already holds. Says nothing — grepping `status`'s human text for this is
# a trap: `grep -q` closes the pipe at its first match, so `status` dies of
# SIGPIPE on its next line and the pipeline reports 141 under `pipefail`, which
# reads exactly like "not held" and costs the caller its slot.
cmd_holds() { held_slot >/dev/null; }

keepalive_running() {
  local pid; pid="$(cat "$KEEPALIVE_PID_FILE" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  case "$(ps -o command= -p "$pid" 2>/dev/null || true)" in
    *keepalive-loop*) return 0 ;;
    *) return 1 ;;
  esac
}

# Detached on purpose: an agent works across many separate bash calls, so an
# in-process loop dies with each call and the raw idb work between wrapped
# commands refreshes nothing. nohup + disown + closed stdio lets the loop outlive
# the acquiring shell; the pid file lets release kill it promptly instead of
# waiting a period for it to notice on its own.
start_keepalive() {
  local label="$1"
  keepalive_running && return 0
  rm -f "$KEEPALIVE_PID_FILE"
  nohup "$SIMLOCK_SCRIPT_PATH" keepalive-loop "$label" </dev/null >/dev/null 2>&1 &
  local pid=$!
  printf '%s' "$pid" > "$KEEPALIVE_PID_FILE"
  disown "$pid" 2>/dev/null || true
  # Publish here rather than waiting for the loop's first beat, or `status` reads
  # "no keep-alive pid" for the first KEEPALIVE_INTERVAL of every hold.
  local slot; slot="$(held_slot || true)"
  [ -n "$slot" ] && publish_keepalive_pid "$slot" "$pid"
  audit keep-alive-start "$label"
}

stop_keepalive() {
  local pid; pid="$(cat "$KEEPALIVE_PID_FILE" 2>/dev/null || true)"
  rm -f "$KEEPALIVE_PID_FILE"
  [ -n "$pid" ] || return 0
  # Guard against pid reuse: only kill a process that is actually our loop.
  case "$(ps -o command= -p "$pid" 2>/dev/null || true)" in
    *keepalive-loop*)
      kill "$pid" 2>/dev/null || true
      local slot; slot="$(held_slot || true)"
      audit keep-alive-stop "${slot:+$(holder_label "$slot")}"
      ;;
  esac
  return 0
}

cmd_keepalive_loop() {
  local label="${1:-}" waited=0 idle slot
  while [ "$waited" -lt "$KEEPALIVE_CAP" ]; do
    sleep "$KEEPALIVE_INTERVAL"
    waited=$((waited + KEEPALIVE_INTERVAL))
    heartbeat_if_owner || exit 0
    slot="$(held_slot)" || exit 0
    # A no-op write once the pid is already ours; it matters after a re-acquire
    # that reused this loop, and it is what makes the beat and the liveness
    # signal come from the same process.
    publish_keepalive_pid "$slot" "$$"
    idle="$(activity_age)"
    if [ "$idle" -ge "$IDLE_GRACE" ]; then
      audit auto-release "$label (slot $slot, idle ${idle}s)"
      if declare -F simlock_teardown >/dev/null 2>&1; then simlock_teardown "$slot"; fi
      reclaim_slot_sim "$slot"
      rm -rf "$(slot_lock_dir "$slot")"
      rm -f "$SESSION_FILE" "$ACTIVITY_FILE" "$KEEPALIVE_PID_FILE"
      exit 0
    fi
  done
  audit keep-alive-expired "$label"
}

# The pool half of `status`, for the tool's own cmd_status to print alongside its
# stack/sim state. Two ages per held slot, because they answer different
# questions: the beat says whether the holder's PROCESS is alive, idle says
# whether its WORK is.
simlock_status_lines() {
  local slot ours; ours="$(held_slot || true)"
  for slot in $(slot_numbers); do
    local tag; tag="$(printf 'slot %s (%s):' "$slot" "$(slot_sim "$slot")")"
    if [ -d "$(slot_lock_dir "$slot")" ]; then
      local beat idle live
      beat=$(( $(now) - $(meta_mtime "$slot") )); idle="$(holder_idle "$slot")"
      # Always print whether a process is still behind this hold. "held by us"
      # alone sent two agents onto one simulator once already, and `ps` is the
      # one check that settles it — so state it here rather than making every
      # reader run it. It names the KEEP-ALIVE, not the acquiring shell: see
      # holder_liveness.
      live="$(holder_liveness "$slot")"
      if [ "$ours" = "$slot" ]; then
        say "  $tag ${c_grn}held by us${c_rst} ('$(holder_label "$slot")', $live, beat ${beat}s ago, idle ${idle}s)"
      else
        say "  $tag ${c_ylw}held by '$(holder_label "$slot")'${c_rst} ($(holder_tool "$slot"), $live, beat ${beat}s ago, idle ${idle}s)"
      fi
    else
      say "  $tag ${c_grn}free${c_rst}"
    fi
  done
  [ -n "$ours" ] && warn_idle_with_waiters "$(activity_age)" "$ours"
  warn_protocol_drift
  prune_tickets
  local depth; depth="$(queue_depth)"
  if [ "$depth" -gt 0 ]; then
    say "  queue:      ${c_ylw}${depth} waiting${c_rst}"
    queue_lines "                "
  else
    say "  queue:      ${c_grn}empty${c_rst}"
  fi
  return 0
}
