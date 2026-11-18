#!/bin/bash
# Claude owns its PRs in this repo: after opening one or pushing to it, it must start a background
# poll of the checks before the turn ends. A promise to "wait for CodeRabbit" with no poll running
# once left PR #224's review unread for nine hours, so this reminds it right after the push.
command=$(jq -r '.tool_input.command // empty')
case "$command" in
    *"gh pr create"* | *"git push"*) ;;
    *) exit 0 ;;
esac

cat <<'JSON'
{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "You just opened or pushed to a PR. Before ending this turn, start a background Bash loop (run_in_background) that polls `gh pr checks <n> --json name,state` and exits once no check is PENDING/QUEUED/IN_PROGRESS, judged in python, not by grepping the text columns. When it finishes, address the CodeRabbit comments and merge on green. Saying you will shepherd the PR is not a poll (memory: owns-prs-in-intellinest)."}}
JSON
