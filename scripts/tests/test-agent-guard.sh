#!/usr/bin/env bash
# Tests for scripts/agent-guard.py -- the PreToolUse hook.
#
# The ALLOW cases matter more than the BLOCK cases. A guard that refuses
# `git commit -m "document --no-verify"` or `rm -rf build` gets switched off
# within a week, and then it protects nothing. Every false positive here was
# a real bug in an earlier version of the guard.
#
#   ./scripts/tests/test-agent-guard.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 3

pass=0; fail=0
chk() { # chk <expect: BLOCK|ALLOW> <command>
  local want="$1" cmd="$2" out rc
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$cmd")" \
        | ./scripts/agent-guard.py 2>&1); rc=$?
  local got="ALLOW"; [ $rc -eq 2 ] && got="BLOCK"
  if [ "$got" = "$want" ]; then pass=$((pass+1)); printf '  ok    %-6s %s\n' "$got" "$cmd"
  else fail=$((fail+1)); printf '  FAIL  want=%s got=%s  %s\n' "$want" "$got" "$cmd"; fi
}
echo "--- must BLOCK (destructive) ---"
chk BLOCK 'rm -rf ~/'
chk BLOCK 'rm -rf tests/ patches/ plan/ ~/'
chk BLOCK 'rm -fr $HOME'
chk BLOCK 'rm -rf /'
chk BLOCK 'rm -rf .git'
chk BLOCK 'rm -rf build/*'
chk BLOCK 'git clean -xdf'
chk BLOCK 'git reset --hard origin/main'
chk BLOCK 'dd if=/dev/zero of=/dev/sda'
chk BLOCK 'chmod -R 777 /'
chk BLOCK 'psql -c "DROP TABLE users"'
echo "--- must still BLOCK (bypasses) ---"
chk BLOCK 'git commit --no-verify -m wip'
chk BLOCK 'git push --force'
echo "--- must ALLOW (the false positives that make a guard hated) ---"
chk ALLOW 'rm -rf build'
chk ALLOW 'rm -f stale.log'
chk ALLOW 'rm build/output.o'
chk ALLOW 'git clean -n'
chk ALLOW 'git reset HEAD~1'
chk ALLOW 'git reset --soft HEAD~1'
chk ALLOW 'git push --force-with-lease'
chk ALLOW 'git commit -m "docs: explain rm -rf ~/ and --no-verify"'
chk ALLOW 'grep -r "DROP TABLE" migrations/'
chk ALLOW 'pytest -m fast'

# --- what the refusal SAYS, not just that it refuses --------------------------
# The message goes to the model, which acts on it. A message that suggests
# editing or removing the gate hands the constrained party permission to
# renegotiate the constraint -- and an agent will take the suggestion. Every
# refusal must point at the finding or at a human, never at the hook.
echo "--- the refusal message must not invite editing the gate ---"
msg() { # msg <command> -- prints the block message
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | ./scripts/agent-guard.py 2>&1
}
for cmd in 'git commit --no-verify -m wip' 'SKIP=quality-check-staged git commit -m x'; do
  out=$(msg "$cmd")
  if printf '%s' "$out" | grep -Eqi 'change the hook|remove it from|edit the (hook|config)|disable the (hook|check)'; then
    fail=$((fail+1)); printf '  FAIL  message invites editing the gate: %s\n' "$cmd"
  else
    pass=$((pass+1)); printf '  ok    message points elsewhere: %s\n' "$cmd"
  fi
done

echo
echo "passed=$pass failed=$fail"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
