---
name: spec-test-cases
description: Writes numbered test case specifications (TC-nnn) from a requirement or a description of behaviour, each with a given/when/then and a stated oracle. Use when the user asks to "write test cases", "spec out tests", "what should we test for X", or needs TC ids before tests are automated. Do not use for writing test code — that is a separate job.
metadata:
  version: 1.0.0
---

Test cases are decided before they are coded. Writing them as numbered specifications means
coverage can be argued about, reviewed and traced — separately from whether anyone has got
round to automating them yet.

## When to invoke

When someone describes behaviour that needs testing and there are no `TC-` ids yet, or when a
test review found annotations pointing at test cases that do not exist.

## Workflow

**Step 1 — list the behaviours.** For the requirement given, enumerate what could be true or
false. Cover, at minimum: the happy path, each documented failure, and the boundaries of any
number or count mentioned (at, one below, one above).

**Step 2 — write one file per case** into `specs/` as `TC-<nnn>.md`, using the next free number:

```markdown
# TC-104 — Wrong password is rejected
given:   a registered user with a known password
when:    authenticate() is called with the wrong password
then:    it returns "denied" and the failure counter increases by 1
oracle:  return value == "denied"
level:   unit
```

**Step 3 — state the oracle explicitly.** The oracle is *what makes it pass or fail*. If it
cannot be written as a comparison, the case is not yet testable — say so rather than inventing
one.

## Gotchas

- Numbers are never reused. Check `specs/` for the highest existing id first.
- One case per behaviour. A case asserting three things cannot report which one broke.

## Not in scope

- Writing or editing test code.
- Judging existing tests — use `review-test-quality` for that.

## Companion skills

`review-test-quality` checks whether the tests written against these cases actually verify
them, and flags annotations that point at cases which do not exist.
