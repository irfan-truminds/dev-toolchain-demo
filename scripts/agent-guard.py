#!/usr/bin/env python3
"""Refuse agent shell commands that bypass the enforcement layers.

This is the one job that has no git or CI equivalent: git hooks fire on git
operations and CI fires on push, so neither of them ever sees `git commit
--no-verify` being *typed*. Only an agent hook sits in front of the shell.

Contract (deliberately the same shape as every check in this repo):
    stdin  -- the agent harness's hook payload, as JSON
    exit 0 -- allow
    exit 2 -- block, and the text on stderr is shown to the model

Vendor neutrality: the *rules* below are the durable artifact. Only
`extract_command()` knows about a specific vendor's payload shape, and adding
a vendor means adding one more key path there -- not editing the rules.

Honest limit, worth saying out loud when demoing this: it is still a
client-side, level-1 control. The config lives in the repo, the agent can edit
it, and the harness fails open if this script is missing. It raises the cost of
a bypass; it does not remove the ability. The unbypassable copy is the ruleset.
"""

import json
import re
import sys

# (pattern, why) -- `why` is written to the model, so it names the alternative.
RULES = [
    (r"--no-verify",
     "`--no-verify` skips the pre-commit and pre-push gates. Fix what the hook "
     "reported. If you believe the hook itself is wrong, stop and say so -- "
     "changing or disabling a gate is the human's call, not yours."),
    (r"\bgit\s+commit\b[^|;&]*\s-\w*n",
     "`git commit -n` is `--no-verify`. Same answer: fix the finding, not the gate."),
    (r"\bSKIP=",
     "`SKIP=` disables named pre-commit hooks for this run. If a hook must not "
     "run here, ask the human to change .pre-commit-config.yaml -- do not "
     "edit it yourself to get past this."),
    (r"\bHUSKY=0\b|\bPRE_COMMIT_ALLOW_NO_CONFIG\b",
     "That environment variable turns the hook manager off for this invocation."),
    (r"\bgit\s+config\b[^|;&]*core\.hooksPath",
     "Repointing core.hooksPath disables every tracked hook at once."),
    (r"\brm\b[^|;&]*\.git/hooks",
     "Deleting .git/hooks removes the gates silently -- nobody would see it in review."),
    (r"\bgit\s+push\b[^|;&]*--force(?!-with-lease)\b|\bgit\s+push\b[^|;&]*\s-f\b",
     "Use --force-with-lease. A bare --force can discard a teammate's commits."),

    # --- destructive commands -------------------------------------------------
    # These are not bypasses of a gate; they are the class of mistake that has
    # no gate at all. Git hooks fire on git operations and CI fires on push --
    # NEITHER of them ever sees `rm -rf`. A PreToolUse hook is the only layer
    # that sees a shell command before it runs, which is why this belongs here
    # and nowhere else in the ladder.
    #
    # The documented incidents involved no attacker: a cleanup request produced
    # `rm -rf tests/ patches/ plan/ ~/` and the trailing `~/` took the user's
    # home directory. Ordinary misinterpretation was enough.
    (r"\brm\b[^|;&]*(?:-\w*r\w*f|-\w*f\w*r)\b[^|;&]*(?:~|/\s*$|/\s|\$HOME|\*)",
     "Recursive force-delete of a home directory, a filesystem root, or a glob. "
     "There is no undo and no gate below this one. If you genuinely mean it, "
     "run it yourself outside the agent session."),
    (r"\brm\b[^|;&]*(?:-\w*r\w*f|-\w*f\w*r)\b[^|;&]*\.git\b",
     "Deleting .git destroys the repository's history, including anything not "
     "yet pushed. Use `git clean` or `git reset` -- both are recoverable."),
    (r"\bgit\s+(?:clean|checkout|restore)\b[^|;&]*-\w*(?:[xX]\w*d|d\w*[xX])\w*",
     "`git clean -xd` deletes ignored AND untracked files -- .env files, local "
     "configs and virtualenvs that are not in git and cannot be recovered from "
     "it. Add `-n` first and read what it would remove."),
    (r"\bgit\s+reset\b[^|;&]*--hard\b",
     "`git reset --hard` discards uncommitted work irreversibly. `git stash` "
     "keeps it and costs nothing."),
    (r"(?:\bmkfs\b|\bdd\b[^|;&]*\bof=/dev/|:\(\)\s*\{.*\|.*&\s*\}|\bchmod\b[^|;&]*-R[^|;&]*\s777\s*/)",
     "That command is destructive at the machine level, not the repo level. "
     "Nothing in this session's ladder sits below it."),
]

# Rules that are matched against the RAW command, quotes and all.
#
# The main RULES list runs against a copy with quoted strings removed, so that
# `git commit -m "document --no-verify"` is not refused. That is right for
# flags, and WRONG for SQL: every real `DROP TABLE` arrives inside quotes, so a
# SQL rule in the list above could never fire. A rule that cannot match is not
# a safe rule, it is a rule that reports nothing -- the "Validation OK" failure.
#
# So these scan the raw string, and buy back the precision by requiring a
# database client to be the thing being invoked. `grep -r "DROP TABLE"` and
# `git commit -m "drop table migration"` stay allowed.
RAW_RULES = [
    (r"\b(?:psql|mysql|mariadb|sqlite3|mongosh?|clickhouse-client)\b[^|;&]*"
     r"\b(?:DROP\s+(?:DATABASE|TABLE|SCHEMA)|TRUNCATE\s+TABLE)\b",
     "Destructive schema change issued through a database client. An agent ran "
     "one of these during an active code freeze and deleted a production "
     "database. If this is intended it belongs in a reviewed migration, not a "
     "shell call."),
]

# Vendor payload shapes. Add a key path to support another harness.
COMMAND_PATHS = [
    ("tool_input", "command"),      # Claude Code, Codex CLI, VS Code Copilot
    ("toolInput", "command"),       # Cursor
    ("input", "command"),
    ("command",),
]


def extract_command(payload):
    for path in COMMAND_PATHS:
        node = payload
        for key in path:
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
        # Fail LOUDLY but open: an unparseable payload is our bug, not the
        # agent's, and wedging the session over it helps nobody. A *blocking*
        # decision we cannot make is still reported.
        print("agent-guard: could not parse hook payload; command NOT checked",
              file=sys.stderr)
        return 0

    command = extract_command(payload)
    if not command:
        return 0

    # Drop quoted strings first, so a commit message that merely mentions a
    # flag is not a hit: git commit -m "document --no-verify" must pass.
    scannable = re.sub(r"\"[^\"]*\"|'[^']*'", " ", command)

    for pattern, why in RULES:
        if re.search(pattern, scannable):
            print(f"BLOCKED by agent-guard: {command}\n\n{why}", file=sys.stderr)
            return 2

    for pattern, why in RAW_RULES:
        if re.search(pattern, command, re.IGNORECASE):
            print(f"BLOCKED by agent-guard: {command}\n\n{why}", file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
