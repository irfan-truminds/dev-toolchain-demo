---
name: review-test-quality
description: Reviews Python test files for tests that cannot fail, fixed sleeps, and missing traceability annotations. Use when the user asks to "review tests", "check test quality", "are these tests any good", "audit the test suite", or shares a test file and asks whether it actually verifies anything.
metadata:
  version: 1.0.0
---

Test suites fail quietly. A test that always passes still reports green, and nobody
notices until the bug it was supposed to catch reaches production. This skill finds
the mechanical problems with a script, then judges the parts a script cannot.

## When to invoke

When someone asks whether a test file is any good, wants a test review, or suspects a
suite is passing without verifying anything.

## Workflow

**Step 1 — run the mechanical checks.** These are decidable without reading for meaning:

```bash
python3 .claude/skills/review-test-quality/scripts/check_tests.py <path>
```

The script reports: tests with no assertion · assertions that cannot fail · fixed
`sleep()` calls · missing `# TC-` traceability annotations. Each finding names its fix.
Exit code 1 means findings, 0 means clean.

**Step 2 — judge what the script cannot.** The script proves a test *can* fail. It cannot
tell you whether it checks the *right thing*. For each test, answer:

- Would this test actually catch the regression it is named after?
- Does it assert the documented outcome, or merely that something happened?
- Are the error paths exercised, or only the happy path?

**Step 3 — report.** Mechanical findings first (with the script's exact fixes), then your
judgements, clearly separated. Never present a judgement as if the script found it.

## Gotchas

- A test may pass all mechanical checks and still be worthless. Step 2 is not optional.
- Do not edit the tests unless asked. Report first.

## Not in scope

- Writing new tests — that is a different job.
- Running the suite or diagnosing genuine failures.
- Non-Python test files.
