#!/usr/bin/env bash
# One check script, four callers: the agent, pre-commit, pre-push, and CI.
# The checks are the same. What differs per mode is (a) how much is run and
# (b) what happens on the first failure -- because the *reader* is different.
#
#   agent     the model reads this. Fail fast and keep it short: every line
#             costs context, and it can only act on one finding per turn.
#   staged    a human at a commit prompt. Fast subset, changed files only.
#   pre-push  a human about to share work. Run everything and report ALL of
#             it -- one list beats five round trips.
#   ci        nobody is waiting. Run everything, report everything, no cap.
#
# Note we do NOT use `set -e`. Fail-fast is a per-mode decision below, not a
# global one; `set -e` would force one-finding-at-a-time on every caller.
set -uo pipefail

# Hooks are invoked by git and by agent harnesses, neither of which activates a
# virtualenv. Resolve the project's own tools first so a hook never silently
# runs a different mypy -- or none at all.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -d "$REPO_ROOT/.venv/bin" ] && PATH="$REPO_ROOT/.venv/bin:$PATH"
export PATH

MODE="${1:-staged}"
shift || true

FAILED=()          # names of checks that failed, for the summary
BROKEN=()          # checks whose TOOL was missing -- a different problem
FAIL_FAST=0        # set per mode
MAX_LINES=0        # 0 = uncapped
PARALLEL=0         # set per mode -- see the note below
ORDER=()           # check names in declaration order, for a stable report

# Parallelism is a per-mode decision for the same reason fail-fast is.
# Where nobody is waiting (pre-push, ci) the checks are independent and the
# wall-clock cost is the SLOWEST check, not their sum. Where a model is
# reading the output (agent) we stay sequential and fail fast: parallel output
# interleaves, and the agent can only act on one finding per turn anyway.
# SDLC_SERIAL=1 forces the sequential path. It exists so the parallel speedup
# can be MEASURED rather than asserted -- a performance claim nobody can
# reproduce is the same species as an unsourced statistic.
[ "${SDLC_SERIAL:-0}" = "1" ] && FORCE_SERIAL=1 || FORCE_SERIAL=0
TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT

# Which checks block when their own tooling is broken (fail closed) rather than
# degrading to a warning (fail open). The rule: fail closed for anything whose
# absence is irreversible or security-relevant, fail open for cosmetics.
# A secrets scanner that silently stops scanning is worse than no scanner,
# because it buys confidence nobody earned.
CRITICAL="secrets sast deps"

case "$MODE" in
  agent)    FAIL_FAST=1; MAX_LINES=40; PARALLEL=0 ;;
  staged)   FAIL_FAST=0;              PARALLEL=0 ;;
  pre-push) FAIL_FAST=0;              PARALLEL=1 ;;
  ci)       FAIL_FAST=0;              PARALLEL=1 ;;
  *) echo "Error: unknown mode '$MODE'. Expected: agent, staged, pre-push, or ci." >&2
     exit 64 ;;
esac

[ "$FORCE_SERIAL" -eq 1 ] && PARALLEL=0

# run_check <name> <command...>
# Dispatcher. Sequential modes run inline; parallel modes fan out and are
# collected in declaration order by collect(), so the REPORT stays stable even
# though the execution does not.
run_check() {
  local name="$1"
  ORDER+=("$name")
  if [ "$PARALLEL" -eq 1 ]; then
    [ -z "$TMPD" ] && TMPD="$(mktemp -d)"
    shift
    ( "$@" >"$TMPD/$name.out" 2>&1; echo $? >"$TMPD/$name.rc" ) &
    return 0
  fi
  shift
  _exec_check "$name" "$@"
}

# collect: wait for every background check, then replay them in ORDER.
collect() {
  [ "$PARALLEL" -eq 1 ] || return 0
  wait
  local name rc out
  for name in "${ORDER[@]}"; do
    [ -f "$TMPD/$name.rc" ] || continue
    rc="$(cat "$TMPD/$name.rc")"
    out="$(cat "$TMPD/$name.out")"
    _record "$name" "$rc" "$out"
  done
}

# _exec_check <name> <command...> -- run it now, inline.
_exec_check() {
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  _record "$name" "$rc" "$out" "$*"
}

# _record <name> <rc> <output> [cmd] -- the reporting half, shared by both paths.
_record() {
  local name="$1" rc="$2" out="$3" cmd="${4:-}"

  # pytest exit 5 = "no tests were collected". A test selection that matches
  # nothing is not a pass -- it is a gate that ran zero tests and said OK.
  # Verified: `pytest -m fsat` exits 5, and --strict-markers does NOT catch a
  # typo in a -m expression (it only catches unregistered decorators).
  if [ $rc -eq 5 ] && [[ "$name" == tests* ]]; then
    BROKEN+=("$name")
    echo "--- $name: SELECTED NO TESTS (blocking -- a gate over nothing passes every time) ---"
    echo "$out"
    [ "$FAIL_FAST" -eq 1 ] && finish
    return 0
  fi

  # 127 = the tool is not installed. That is OUR failure, not the code's, and
  # reporting it as a code finding is how people learn to distrust the gate.
  if [ $rc -eq 127 ]; then
    if [[ " $CRITICAL " == *" $name "* ]]; then
      BROKEN+=("$name")
      echo "--- $name: TOOL MISSING (blocking -- this check is security-relevant) ---"
      echo "$out"
      [ "$FAIL_FAST" -eq 1 ] && finish
    else
      echo "--- $name: SKIPPED, tool not installed (not blocking) ---"
      echo "$out"
    fi
    return 0
  fi

  if [ $rc -ne 0 ]; then
    FAILED+=("$name")
    echo "--- $name: FAILED ---"
    if [ "$MAX_LINES" -gt 0 ]; then
      echo "$out" | head -n "$MAX_LINES"
      local total; total=$(echo "$out" | wc -l)
      [ "$total" -gt "$MAX_LINES" ] && echo "... ($((total - MAX_LINES)) more lines suppressed; run '$cmd' to see all)"
    else
      echo "$out"
    fi
    [ "$FAIL_FAST" -eq 1 ] && finish
  fi
  return 0
}

finish() {
  collect
  local bad=0
  if [ ${#BROKEN[@]} -gt 0 ]; then
    echo
    echo "==> ${#BROKEN[@]} check(s) COULD NOT RUN: ${BROKEN[*]}"
    echo "    Install the toolchain (pip install -e '.[dev]') -- these are not optional."
    bad=1
  fi
  if [ ${#FAILED[@]} -gt 0 ]; then
    echo
    echo "==> ${#FAILED[@]} check(s) failed: ${FAILED[*]}"
    bad=1
  fi
  [ $bad -eq 1 ] && exit 1
  echo "==> all checks passed"
  exit 0
}

staged_py_files() {
  git diff --cached --name-only --diff-filter=d | grep '\.py$' || true
}

case "$MODE" in

  agent)
    # Fires after every model edit. Budget: keep it under a couple of seconds.
    # Operates ONLY on the paths it was handed -- never the whole repo.
    FILES="$*"
    [ -z "$FILES" ] && { echo "==> [AGENT] no files given, nothing to check"; exit 0; }
    echo "==> [AGENT] checking: $FILES"
    run_check "format"  black --check $FILES
    run_check "types"   mypy $FILES
    # Scan ONLY the edited paths. `--source .` walks the whole repo and cost
    # 14s here against 8ms for one file -- the difference between a hook people
    # keep and a hook people rip out.
    for f in $FILES; do
      run_check "secrets" gitleaks detect --no-git --source "$f" --redact --no-banner
    done
    # Fast tests run here too. "Tests are too slow for a hook" is a claim about
    # YOUR suite, not about tests -- the `fast` marker is how you make that
    # claim checkable instead of assumed. This subset is ~20 ms.
    run_check "tests-fast" pytest -m fast -q --no-header -p no:cacheprovider
    finish
    ;;

  staged)
    echo "==> [PRE-COMMIT] Running staged quality gate..."
    STAGED_PY_FILES=$(staged_py_files)
    if [ -n "$STAGED_PY_FILES" ]; then
      run_check "format" black --check $STAGED_PY_FILES
      run_check "types"  mypy $STAGED_PY_FILES
    else
      echo "(no staged python files)"
    fi
    run_check "secrets"    gitleaks protect --staged --verbose
    run_check "tests-fast" pytest -m fast -q --no-header
    finish
    ;;

  pre-push)
    echo "==> [PRE-PUSH] Running pre-push quality & test gate..."
    run_check "types"   mypy src/ tests/
    run_check "lint"    pylint src/ tests/
    run_check "sast"    semgrep scan --config=.semgrep.yml --config=p/python \
                                     --config=p/owasp-top-ten --error src/ tests/
    run_check "tests"   pytest          # everything: fast AND slow
    run_check "secrets" gitleaks protect --verbose
    finish
    ;;

  ci)
    echo "==> [CI] Running full remote quality suite..."
    run_check "format"  black --check src/ tests/
    run_check "lint"    pylint src/ tests/
    run_check "types"   mypy src/ tests/
    run_check "sast"    semgrep scan --config=.semgrep.yml --config=p/python \
                                     --config=p/owasp-top-ten --error src/ tests/
    run_check "deps"    pip-audit -r requirements.txt
    run_check "secrets" gitleaks detect --verbose
    run_check "tests"   pytest --cov=src --cov-fail-under=80
    finish
    ;;
esac
