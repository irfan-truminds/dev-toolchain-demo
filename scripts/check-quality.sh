#!/usr/bin/env bash
set -euo pipefail

# Accept target files or default to full codebase
TARGETS="${@:-src tests}"

# TODO: add quality check mode (local, CI, agent, etc)

# echo "==> Running Code Formatting Check..."
# black --check $TARGETS

# echo "==> Running Code Linter Check..."
# pylint $TARGETS

# echo "==> Running Strict Type Checking..."
# mypy $TARGETS

# echo "==> Running SAST Security Scan..."
# semgrep scan   --config=.semgrep.yml   --config=p/python   --config=p/owasp-top-ten   --error $TARGETS

# # should be run in pre-push / CI
# echo "==> Running Tests..."
# pytest


#!/usr/bin/env bash
set -euo pipefail

# 1. Capture the stage mode (default to 'staged' if invoked directly without args)
MODE="${1:-staged}"
shift || true  # Shift $1 out so $@ now contains only file paths (if any)

if [ "$MODE" = "staged" ]; then
    echo "==> [PRE-COMMIT] Running staged quality gate..."
    
    # # $@ contains staged file paths passed by pre-commit
    # STAGED_PY_FILES=$(echo "$@" | grep '\.py$' || true)

    # Query Git directly for staged Python files
    STAGED_PY_FILES=$(git diff --cached --name-only --diff-filter=d | grep '\.py$' || true)

    if [ -n "$STAGED_PY_FILES" ]; then
        black --check $STAGED_PY_FILES
        mypy $STAGED_PY_FILES
    fi
    gitleaks protect --staged --verbose

elif [ "$MODE" = "pre-push" ]; then
    echo "==> [PRE-PUSH] Running pre-push quality & test gate..."
    mypy src/ tests/
    pylint src/ tests/
    semgrep scan   --config=.semgrep.yml   --config=p/python   --config=p/owasp-top-ten   --error $STAGED_PY
    #pytest --testmon
    pytest -m "unit"
    gitleaks protect --verbose

elif [ "$MODE" = "ci" ]; then
    echo "==> [CI] Running full remote quality suite..."
    black --check src/ tests/
    pylint src/ tests/
    mypy src/ tests/
    semgrep scan   --config=.semgrep.yml   --config=p/python   --config=p/owasp-top-ten   --error $STAGED_PY
    pip-audit -r requirements.txt
    gitleaks detect --verbose
    pytest --cov=src --cov-fail-under=80
else
    echo "Error: Unknown execution mode '$MODE'. Expected: staged, pre-push, or ci."
    exit 1
fi