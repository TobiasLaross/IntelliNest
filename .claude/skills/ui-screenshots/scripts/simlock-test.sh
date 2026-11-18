#!/usr/bin/env bash
# simlock-test.sh — the protocol tests for simlock.sh.
#
# There were none. simlock.sh is the one piece of code on this Mac that every
# agent in two repos runs, and a bug in it does not fail a build — it wedges
# every session at once, which is how the two-hour hold (lilium#1016) and the
# machine-global session file (#285) both survived as long as they did. Those
# were found by an incident, not by a test.
#
# It runs entirely against a temp lock root with a fake pool and stubbed
# `xcrun`, so it touches no real simulator and no real lock. Every agent is a
# separate PROCESS with its own session file, because that is the only shape in
# which the ownership and queue bugs are reachable at all.
#
# Like simlock.sh itself, this file must stay BYTE-IDENTICAL in lilium and
# gto-poker-ios.
#
#   ./simlock-test.sh          # run them
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d /tmp/simlock-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$*" >&2; fail=$((fail + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
# Slot dirs only. A bare `pool.lock.d*` glob also catches the .waiters and
# .tombstones siblings, which are not slots and never come down on a release.
held_slots() { ls -d "$TMP"/pool.lock.d "$TMP"/pool.lock.d.slot* 2>/dev/null | grep -c .; }

# A stub `xcrun` so reclaim_slot_sim can run without a simulator. It records its
# calls so the tests can assert on what reclaim did and did not do.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/xcrun" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${XCRUN_CALLS:?}"
case "$*" in
  *"list devices available -j"*) printf '{"devices":{"rt":[{"name":"pool-a","udid":"UDID-A"},{"name":"pool-b","udid":"UDID-B"}]}}' ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/xcrun"
export PATH="$TMP/bin:$PATH"
export XCRUN_CALLS="$TMP/xcrun-calls"
: > "$XCRUN_CALLS"

# A minimal stand-in for shots.sh: the smallest thing that can source the
# protocol and dispatch a verb, so each "agent" below is a real separate process.
cat > "$TMP/agent.sh" <<AGENT
#!/usr/bin/env bash
set -uo pipefail
SIMLOCK_TOOL="\${AGENT_TOOL:-test-tool}"
SIMLOCK_STATE_DIR="$TMP/state"
SIMLOCK_SESSION_FILE="$TMP/\${AGENT_ID:?}.session"
SIMLOCK_SCRIPT_PATH="$TMP/agent.sh"
SIMLOCK_RESOURCE="test sim"
SIMLOCK_DIE_PREFIX="test: "
mkdir -p "\$SIMLOCK_STATE_DIR"
simlock_teardown() { printf 'teardown slot=%s agent=%s\n' "\${1:-?}" "\${AGENT_ID}" >> "$TMP/teardowns"; return 0; }
. "$HERE/simlock.sh"
verb="\${1:-}"; shift || true
case "\$verb" in
  acquire)       cmd_acquire "\$@" ;;
  release)       cmd_release ;;
  force-release) cmd_force_release "\$@" ;;
  holds)         cmd_holds ;;
  status)        simlock_status_lines ;;
  slot)          simlock_current_slot ;;
  sim)           simlock_current_sim ;;
  keepalive-loop) cmd_keepalive_loop "\$@" ;;
  # Release spawns the deferred shutdown detached; here that is a no-op so no
  # stray sleeper outlives the run. The tests drive it via idle-shutdown-now.
  idle-shutdown) : ;;
  idle-shutdown-now) cmd_idle_shutdown "\$@" ;;
  *) echo "unknown verb '\$verb'" >&2; exit 64 ;;
esac
AGENT
chmod +x "$TMP/agent.sh"

export SHARED_SCREENSHOT_LOCK_DIR="$TMP/pool.lock.d"
export SHARED_SCREENSHOT_SIM_POOL="pool-a pool-b"
export SHOTS_LOCK_POLL=1
export SHOTS_AUDIT_LOG="$TMP/audit.log"
export SHOTS_SIM_DEVICES_DIR="$TMP/devices"
export SHOTS_RECLAIM=0          # off by default; the reclaim tests turn it on
export SHOTS_KEEPALIVE_INTERVAL=1

# Run a verb as a named agent. The keep-alive is disabled for most tests by
# pointing SIMLOCK_SCRIPT_PATH's loop at a cap of 0 — we drive the protocol
# directly rather than waiting on a background beat.
agent() { local id="$1"; shift; AGENT_ID="$id" SHOTS_KEEPALIVE_CAP=0 "$TMP/agent.sh" "$@"; }
agent_bg() { local id="$1"; shift; AGENT_ID="$id" SHOTS_KEEPALIVE_CAP=0 "$TMP/agent.sh" "$@" & }

reset_pool() {
  rm -rf "$TMP/pool.lock.d" "$TMP/pool.lock.d".* "$TMP"/*.session "$TMP"/*.activity \
         "$TMP"/*.keepalive.pid "$TMP/teardowns" "$TMP/devices"
  : > "$XCRUN_CALLS"
}

# --- slot allocation ----------------------------------------------------------
printf '\nslot allocation\n'
reset_pool
agent one acquire "first" >/dev/null 2>&1
check "first agent takes slot 1" "$(agent one slot)" "1"
check "slot 1 maps to the first sim in the pool" "$(agent one sim)" "pool-a"

agent two acquire "second" >/dev/null 2>&1
check "second agent is NOT blocked, takes slot 2" "$(agent two slot)" "2"
check "slot 2 maps to the second sim" "$(agent two sim)" "pool-b"

check "agent one still holds slot 1" "$(agent one slot)" "1"
agent one holds && ok "holds is true for a holder" || bad "holds is false for a holder"

# --- v1 wire compatibility ----------------------------------------------------
printf '\nv1 wire compatibility\n'
[ -d "$TMP/pool.lock.d" ] \
  && ok "slot 1 uses the unchanged v1 lock dir path" \
  || bad "slot 1 lock dir moved — a v1 checkout would stop excluding us there"
[ -d "$TMP/pool.lock.d.slot2" ] \
  && ok "slot 2 uses a path v1 never looks at" \
  || bad "slot 2 lock dir is not where it should be"

# --- ownership is per-agent, never machine-global -----------------------------
printf '\nownership\n'
agent three holds && bad "holds is true for an agent holding nothing" \
                  || ok "holds is false for a non-holder"
check "a non-holder resolves no slot" "$(agent three slot 2>/dev/null; echo "rc=$?")" "rc=1"
out="$(agent three release 2>&1)"; rc=$?
check "a non-holder cannot release someone else's slot" "$rc" "1"
check "…and both slots survive it" "$(held_slots)" "2"
[ -f "$TMP/one.session" ] && ok "a failed release leaves the real holder's token intact" \
                          || bad "a failed release destroyed another agent's session token"

# --- the queue ----------------------------------------------------------------
printf '\nqueue\n'
agent_bg three acquire "third" >"$TMP/three.out" 2>&1; three_pid=$!
agent_bg four  acquire "fourth" >"$TMP/four.out" 2>&1; four_pid=$!
# Both slots are taken, so both must be waiting rather than holding.
waited=0
while [ "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" -lt 2 ] && [ "$waited" -lt 50 ]; do
  sleep 0.2; waited=$((waited + 1))
done
check "both extra agents are queued, neither barged in" \
  "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" "2"
[ -d "$TMP/pool.lock.d.waiters" ] \
  && ok "the queue lives at the unchanged v1 path (one line across versions)" \
  || bad "the waiters dir moved — v1 and v2 agents would stand in different lines"

# Freeing one slot must serve exactly one waiter.
agent one release >/dev/null 2>&1
waited=0
while [ "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" -gt 1 ] && [ "$waited" -lt 100 ]; do
  sleep 0.2; waited=$((waited + 1))
done
check "releasing one slot serves exactly one waiter" \
  "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" "1"
check "the freed slot went to the agent that queued FIRST" "$(agent three slot)" "1"
grep -q "waiting:" "$TMP/four.out" && ok "the later waiter reported its queue position" \
                                   || bad "the later waiter printed no position line"

agent two release >/dev/null 2>&1
wait "$four_pid" 2>/dev/null
check "the last waiter is served once the other slot frees" "$(agent four slot)" "2"
wait "$three_pid" 2>/dev/null
agent three release >/dev/null 2>&1; agent four release >/dev/null 2>&1

# --- one agent's impatience must not evict another's ticket -------------------
# Found live: an acquire run with SHOTS_LOCK_MAXWAIT=30 pruned two agents who
# had been queued 19 minutes and 2 minutes, and took the free slot ahead of
# them. The scheduled sim sweep polls with SHOTS_LOCK_MAXWAIT=0 for exactly the
# reason that it must never queue, so it emptied the whole line every run.
#
# The queued waiter is synthesized rather than launched: a real background agent
# re-takes a ticket the moment its own goes missing, which is the self-healing
# that made this bug read as an unfair queue instead of a hang — and would mask
# it here. A ticket file with a live pid is the state under test.
printf '\nqueue fairness under differing patience\n'
reset_pool
agent one acquire "holder one" >/dev/null 2>&1
agent two acquire "holder two" >/dev/null 2>&1
sleep 120 & waiter_pid=$!          # a live pid for the ticket to belong to
mkdir -p "$TMP/pool.lock.d.waiters"
# Queued half an hour ago, patient for the default hour: no correct pruner drops it.
printf 'patient waiter\n3600\n' > "$TMP/pool.lock.d.waiters/$(( $(date +%s) - 1800 )).$waiter_pid.1"
SHOTS_LOCK_MAXWAIT=1 agent four acquire "impatient" >/dev/null 2>&1
check "an impatient agent leaves a longer-lived ticket in the queue" \
  "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" "1"
check "…and does not jump ahead of it onto a slot" \
  "$(agent four slot 2>/dev/null; echo "rc=$?")" "rc=1"
# A ticket whose own patience really has run out is still collected, or a
# crashed waiter would stall the line forever.
printf 'expired waiter\n60\n' > "$TMP/pool.lock.d.waiters/$(( $(date +%s) - 1800 )).$waiter_pid.2"
# `status` prunes synchronously, so no background acquire is needed — and a
# backgrounded waiter here would race the next test for a slot.
agent five status >/dev/null 2>&1
check "a ticket past ITS OWN patience is still pruned" \
  "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c '\.2$')" "0"
check "…while the patient one beside it survives" \
  "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c '\.1$')" "1"
{ kill "$waiter_pid"; wait "$waiter_pid"; } 2>/dev/null || true
rm -f "$TMP/pool.lock.d.waiters"/*
agent one release >/dev/null 2>&1; agent two release >/dev/null 2>&1

# --- re-entrancy --------------------------------------------------------------
printf '\nre-entrancy\n'
reset_pool
agent one acquire "reentrant" >/dev/null 2>&1
out="$(agent one acquire "reentrant" 2>&1)"
check "re-acquiring is instant, not a queue behind ourselves" \
  "$(printf '%s' "$out" | grep -c 'Already holding')" "1"
check "…and it stays on the same slot" "$(agent one slot)" "1"

# --- stealing -----------------------------------------------------------------
printf '\nstealing\n'
reset_pool
agent one acquire "stale one" >/dev/null 2>&1
agent two acquire "live two"  >/dev/null 2>&1
# Age slot 1 past the TTL, leave slot 2 fresh.
touch -t 200001010000 "$TMP/pool.lock.d/meta.json" "$TMP/pool.lock.d"
out="$(SHOTS_LOCK_TTL=60 agent three acquire "thief" 2>&1)"
check "the head of the queue takes the STALE slot" "$(SHOTS_LOCK_TTL=60 agent three slot)" "1"
check "…and leaves the live one alone" "$(agent two slot)" "2"
grep -q "teardown slot=1" "$TMP/teardowns" \
  && ok "the thief tore down its VICTIM's slot, not its own" \
  || bad "teardown did not run for the stolen slot"
out="$(agent one release 2>&1)"
printf '%s' "$out" | grep -q "was stolen by 'thief'" \
  && ok "the victim is told its slot was taken, by name" \
  || bad "the victim got no tombstone report (it would keep driving the sim)"

# --- force-release ------------------------------------------------------------
printf '\nforce-release\n'
reset_pool
agent one acquire "alpha" >/dev/null 2>&1
agent two acquire "beta"  >/dev/null 2>&1
out="$(SHOTS_FORCE_MIN_IDLE=0 agent three force-release "nobody" 2>&1)"; rc=$?
check "force-release refuses a label nobody holds" "$rc" "1"
out="$(agent three force-release "alpha" 2>&1)"; rc=$?
check "force-release refuses a holder that is still live" "$rc" "1"
out="$(SHOTS_FORCE_MIN_IDLE=0 agent three force-release "alpha" 2>&1)"
check "force-release cuts the named slot only" "$(held_slots)" "1"
check "…and the other holder is untouched" "$(agent two slot)" "2"
[ -f "$TMP/two.session" ] && ok "force-releasing a stranger keeps our own token" \
                          || bad "force-release destroyed the wrong session token"

# Same label on both slots is a coin-flip, so it must refuse rather than guess.
reset_pool
agent one acquire "same" >/dev/null 2>&1
agent two acquire "same" >/dev/null 2>&1
out="$(SHOTS_FORCE_MIN_IDLE=0 agent three force-release "same" 2>&1)"; rc=$?
check "force-release refuses an ambiguous label" "$rc" "1"
check "…and cuts neither slot" "$(held_slots)" "2"
agent one release >/dev/null 2>&1; agent two release >/dev/null 2>&1

# --- reclaim on release -------------------------------------------------------
printf '\nreclaim on release\n'
token_file() { printf '%s/pool.lock.d.idle-shutdown/slot%s' "$TMP" "$1"; }
idle_now() { local id="$1"; shift; SHOTS_RECLAIM=1 SHOTS_SIM_IDLE_SHUTDOWN=0 agent "$id" idle-shutdown-now "$@"; }

reset_pool
mkdir -p "$TMP/devices/UDID-A/data/Library/Caches/com.apple.containermanagerd/Dead/temp.1"
dd if=/dev/zero of="$TMP/devices/UDID-A/data/Library/Caches/com.apple.containermanagerd/Dead/temp.1/blob" \
   bs=1024 count=2048 >/dev/null 2>&1
agent one acquire "quiet" >/dev/null 2>&1
out="$(SHOTS_RECLAIM=1 agent one release 2>&1)"
grep -q "shutdown UDID-A" "$XCRUN_CALLS" \
  && bad "a quiet release shut the sim down at once (the next acquire pays a cold boot)" \
  || ok "a release with an empty queue leaves the sim booted"
[ -e "$TMP/devices/UDID-A/data/Library/Caches/com.apple.containermanagerd/Dead/temp.1" ] \
  && bad "the orphaned Dead container was not reaped" \
  || ok "the orphaned Dead container was reaped at release"
[ -s "$(token_file 1)" ] && ok "a quiet release arms the idle shutdown" || bad "no idle-shutdown token was written"

idle_now one 1 "$(cat "$(token_file 1)")" >/dev/null 2>&1
grep -q "shutdown UDID-A" "$XCRUN_CALLS" \
  && ok "an armed slot nobody took is shut down after the idle delay" \
  || bad "the idle shutdown did not shut the sim down"
grep -q "erase UDID-A" "$XCRUN_CALLS" \
  && bad "a small device was erased anyway (that costs a ~2GB re-download)" \
  || ok "a device under the threshold is shut down but not erased"
check "the idle shutdown hands the slot back" "$(held_slots)" "0"
[ -e "$(token_file 1)" ] && bad "the idle shutdown left its token behind" || ok "the idle shutdown consumes its token"

# Re-acquired in between: the sleeper's token is gone, so it must stand down.
reset_pool
agent one acquire "first" >/dev/null 2>&1
SHOTS_RECLAIM=1 agent one release >/dev/null 2>&1
stale="$(cat "$(token_file 1)")"
agent two acquire "back again" >/dev/null 2>&1
[ -e "$(token_file 1)" ] && bad "acquire did not disarm the pending shutdown" || ok "acquire disarms the pending shutdown"
: > "$XCRUN_CALLS"
idle_now one 1 "$stale" >/dev/null 2>&1
grep -q "shutdown UDID-A" "$XCRUN_CALLS" \
  && bad "a stale sleeper shut down a sim somebody is using" \
  || ok "a sleeper whose slot was taken since stands down"
check "…and leaves the new holder's slot alone" "$(agent two slot)" "1"

# Taken and released again: only the NEWEST release's sleeper may act.
SHOTS_RECLAIM=1 agent two release >/dev/null 2>&1
: > "$XCRUN_CALLS"
idle_now one 1 "$stale" >/dev/null 2>&1
grep -q "shutdown UDID-A" "$XCRUN_CALLS" \
  && bad "a superseded sleeper shut the sim down early" \
  || ok "a superseded sleeper stands down"
idle_now two 1 "$(cat "$(token_file 1)")" >/dev/null 2>&1
grep -q "shutdown UDID-A" "$XCRUN_CALLS" \
  && ok "the newest release's sleeper does the shutdown" \
  || bad "the newest sleeper did not shut the sim down"

reset_pool
mkdir -p "$TMP/devices/UDID-A/data"
dd if=/dev/zero of="$TMP/devices/UDID-A/data/fat" bs=1024 count=8192 >/dev/null 2>&1
agent one acquire "fat" >/dev/null 2>&1
SHOTS_RECLAIM=1 agent one release >/dev/null 2>&1
grep -q "erase UDID-A" "$XCRUN_CALLS" && bad "a fat device was erased at release" || ok "a fat device is not erased at release"
SHOTS_RECLAIM_MIN_MB=4 idle_now one 1 "$(cat "$(token_file 1)")" >/dev/null 2>&1
grep -q "erase UDID-A" "$XCRUN_CALLS" \
  && ok "a device over the threshold is erased at the idle shutdown" \
  || bad "a fat device was not erased"

# The important half: a queued agent wants the sim WARM.
reset_pool
agent one acquire "holder" >/dev/null 2>&1
agent two acquire "other"  >/dev/null 2>&1
agent_bg three acquire "waiting" >/dev/null 2>&1; three_pid=$!
waited=0
while [ "$(ls "$TMP/pool.lock.d.waiters" 2>/dev/null | grep -c .)" -lt 1 ] && [ "$waited" -lt 50 ]; do
  sleep 0.2; waited=$((waited + 1))
done
out="$(SHOTS_RECLAIM=1 SHOTS_RECLAIM_MIN_MB=0 agent one release 2>&1)"
grep -qE "(shutdown|erase) UDID-A" "$XCRUN_CALLS" \
  && bad "the sim was shut down with an agent queued for it" \
  || ok "a release with someone queued leaves the sim warm"
[ -e "$(token_file 1)" ] && bad "a release with someone queued armed a shutdown" || ok "…and arms no idle shutdown"
wait "$three_pid" 2>/dev/null
agent two release >/dev/null 2>&1; agent three release >/dev/null 2>&1

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
