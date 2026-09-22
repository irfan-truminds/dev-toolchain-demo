# Working in this repository

A deliberately broken Python service, used as the demo repo for the **AI-assisted SDLC** sessions.
`src/user.py` has a hardcoded credential, string-concatenated SQL and an `eval()`. The test suite
is green. Both of those are on purpose.

## Standing rules

- **Run it before saying it works.** Not "this should pass" — run it and paste what happened.
- **Never weaken an assertion to make a test pass.** Fix the code, or let the test fail.
- **Never bypass a gate.** No `--no-verify`, no `SKIP=`, no repointing `core.hooksPath`, no editing
  `.pre-commit-config.yaml` or `.github/workflows/` to get a red check to go green. If you think a
  gate is wrong, **stop and say so** — changing it is a human decision.
- **Say what you found before writing something new.** Search first.

## The checks, and how to run them by hand

One script, four callers. `./scripts/check-quality.sh <mode> [files…]`, where mode is
`agent` · `staged` · `pre-push` · `ci`. Everything else — the agent hooks, `pre-commit`, the CI
workflow — just calls it with a different mode.

## Skills

- `spec-test-cases` — write numbered `TC-nnn` specifications before automating them.
- `review-test-quality` — find tests that cannot fail, fixed sleeps and missing `# TC-` annotations.

<!-- Deliberately short. Everything phase-specific lives in a skill; everything mechanically
     checkable lives in a script. This file is read on every turn, and section 0 of session 2 is
     about what happens to a rule that lives only here. -->
