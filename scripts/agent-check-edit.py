#!/usr/bin/env python3
"""Run the fast quality checks on the file the agent just edited.

Pairs with agent-guard.py: that one refuses bad *commands*, this one checks bad
*edits*. Both are thin -- the actual checks live in check-quality.sh, which is
also what pre-commit, pre-push and CI call. One check, four callers.

    stdin  -- the harness's post-edit hook payload, as JSON
    exit 0 -- fine
    exit 2 -- findings; stderr is shown to the model, which fixes them in-turn
"""

import json
import os
import subprocess
import sys

# Only `extract_path` knows about vendor payload shapes. Adding a harness means
# adding a key path here, not touching the checks.
PATH_KEYS = [
    ("tool_input", "file_path"),    # Claude Code, VS Code Copilot
    ("tool_input", "path"),
    ("toolInput", "file_path"),     # Cursor
    ("file_path",),
    ("path",),
]

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "check-quality.sh")


def extract_path(payload):
    for keys in PATH_KEYS:
        node = payload
        for key in keys:
            if not isinstance(node, dict) or key not in node:
                node = None
                break
            node = node[key]
        if isinstance(node, str) and node.strip():
            return node
    return ""


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("agent-check-edit: unparseable payload; edit NOT checked", file=sys.stderr)
        return 0

    path = extract_path(payload)
    if not path.endswith(".py") or not os.path.exists(path):
        return 0

    result = subprocess.run(
        [SCRIPT, "agent", path], capture_output=True, text=True
    )
    if result.returncode != 0:
        print(result.stdout + result.stderr, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
