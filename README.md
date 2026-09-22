# dev-toolchain-demo
dev-toolchain-demo

## SCM
* git
* Github
```bash
$ git -v
git version 2.43.0
$ git remote -v
origin  git@github.com:irfan-truminds/dev-toolchain-demo.git (fetch)
origin  git@github.com:irfan-truminds/dev-toolchain-demo.git (push)
```

## Package Mgmt (New)
```bash
# install dev dependencies (including pip-tools needed for pip-compile)
pip install -e .[dev]

# compile lockfile
pip-compile --generate-hashes pyproject.toml -o requirements.txt

# sync / install into your env, enforce byte-for-byte security verification against hashes
pip install --require-hashes -r requirements.txt
```


## Workflow Command Reference
```bash
# 1. Compile dependencies into a locked requirements.txt with SHA-256 hashes
pip-compile --generate-hashes pyproject.toml -o requirements.txt

# 2. Run formatters and linters
black --check src/ tests/
pylint src/ tests/

# 3. Execute strict type check
mypy src/ tests/

# 4. Scan dependencies for known CVEs using the hash-verified requirements
pip-audit -r requirements.txt

# 5. Run static code analysis & secret scanning

# Semgrep with three configs to combine local deterministic business logic rules with community registry packs
# 1. Local: Architecture, team rules, offline resilience
# 2. Registry: General Python vulnerabilities
# 3. Registry: Standard OWASP Top 10 web vulnerabilities
semgrep scan   --config=.semgrep.yml   --config=p/python   --config=p/owasp-top-ten   --error   src/ tests/


# Running as a pre-commit hook to prevent new secrets from entering git.
gitleaks protect --verbose

# CI only: Auditing past commits, branches, and full repository history in CI/CD pipelines.
gitleaks detect --verbose

# 6. Run test suite with coverage enforcement
pytest
```
## Handling leaked secrets
1. Revoke and Rotate secrets at the issuing service (AWS, Github, DB, etc)
2. Scrub Git History using `git filter-repo`
3. Use pre-commit hooks, push protection, CI scanners to continuously monitor and catch leaks

## Setting up git hooks
* git ignores .git/hooks by default - can't be committed or shared from here
* local hooks should run on staged changes (fast), whereas CI pipelines run against entire repo (slow)
* write and track a single source of truth script, reuse across git hooks, ci yaml files
* pre-commit Framework + CI Integration (Industry Standard)
```bash
pre-commit install --hook-type pre-commit --hook-type pre-push

# Test pre-commit hook
pre-commit run quality-check-staged --all-files

# Test pre-push hook
pre-commit run quality-check-push --hook-stage pre-push

```

## Server Side Hooks / Governance
* Fine grained server side git-hooks not always configurable (depends on vendor, hosting, etc)
* Some vendors like Github expose governance rules - unbypassable boundary that prevents unverified, unsafe, or non-compliant code from entering primary branches, even if local Git hooks are skipped using git commit --no-verify.
* Core Pillars:
    1. Repository Rulesets (modern branch protection): Block force pushes & Restrict deletions, Require signed commits, require linear history, require a pull request before merging, Require status checks to pass. Optional: Combine Rulesets with a tracked .github/CODEOWNERS file to mandate specialized team reviews whenever high-risk files or infrastructure directories are modified
    2. Server-Side Push Protection: If a known secret pattern (AWS keys, GitHub tokens, OpenAI keys, standard RSA private keys, or custom defined regexes) is detected, GitHub blocks the push directly in the SSH/HTTPS connection response. Enterprise accounts can define custom regular expressions in Organization settings to scan for internal proprietary tokens (e.g., company_live_secret_[a-zA-Z0-9]{32}).
    3. PR Status Check Enforcement (covered in Repository Rulesets)
    4. Supply Chain Security Alerts - Dependabot Alerts: Scans locked manifests (requirements.txt, poetry.lock, package-lock.json) against GitHub's Advisory Database and generates alerts for published CVEs. Dependabot Security Updates: Automatically opens automated Pull Requests to bump vulnerable dependencies to fixed versions as soon as a patch is available.
    5. Dependency Review Action (PR Blocking Gate) - Add the official Dependency Review action to your PR workflow to evaluate new dependencies before they are merged into main:
    6. GitHub Apps/Webhooks. - For compliance requirements beyond standard GitHub settings, server-side webhooks and GitHub Apps enforce external validation rules: A. Pre-Receive / Merge Validation Webhooks - For GitHub Enterprise Server (on-premise), custom pre-receive hooks execute custom shell or Docker scripts directly on GitHub's infrastructure prior to updating branch references. B. Organization Webhooks (Audit & Event Streaming) Configure organization-wide webhooks to stream audit logs to external SIEMs (Datadog, Splunk, AWS CloudWatch, or Panther):

## Example Client Side Enforcement
```bash
(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$ git commit -m "fixes"
[WARNING] Unstaged files detected.
[INFO] Stashing unstaged files to /home/irf1551/.cache/pre-commit/patch1790053074-1469225.
Quality Gate (Staged Files)..............................................Failed
- hook id: quality-check-staged
- exit code: 1

==> [PRE-COMMIT] Running staged quality gate...
would reformat src/user.py
would reformat src/userhandler.py

Oh no! 💥 💔 💥
2 files would be reformatted.

[INFO] Restored changes from /home/irf1551/.cache/pre-commit/patch1790053074-1469225.




(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$ git push origin main
[WARNING] Unstaged files detected.
[INFO] Stashing unstaged files to /home/irf1551/.cache/pre-commit/patch1790053012-1467468.
Quality Gate (Pre-Push)..................................................Failed
- hook id: quality-check-push
- exit code: 1

==> [PRE-PUSH] Running pre-push quality & test gate...
src/userhandler.py:5: error: Missing type arguments for generic type "dict" 
[type-arg]
        def handle(self, payload: dict) -> None:
                                  ^
src/userhandler.py:12: error: Function is missing a type annotation 
[no-untyped-def]
        def save_user(self, user_data=[], id=None):
        ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
src/userhandler.py:16: error: Cannot instantiate abstract class "UserHandler"
with abstract attribute "handle"  [abstract]
        handler = UserHandler()  # <--- Triggers instantiation
                  ^~~~~~~~~~~~~
src/user.py:5: error: Function is missing a type annotation  [no-untyped-def]
    def get_user(id):
    ^~~~~~~~~~~~~~~~~
src/user.py:10: error: Argument 1 to "eval" has incompatible type "int";
expected "str | Buffer | CodeType"  [arg-type]
            "age": eval(2+3)
                        ^~~
tests/test_userhandler.py:4: error: Function is missing a return type
annotation  [no-untyped-def]
    def test_user_handler():
    ^~~~~~~~~~~~~~~~~~~~~~~~
tests/test_userhandler.py:5: error: Cannot instantiate abstract class
"UserHandler" with abstract attribute "handle"  [abstract]
        return UserHandler() is not None
               ^~~~~~~~~~~~~
tests/test_user.py:4: error: Function is missing a return type annotation 
[no-untyped-def]
    def test_get_user(   ):
    ^~~~~~~~~~~~~~~~~~~~~~~
tests/test_user.py:4: note: Use "-> None" if function does not return a value
tests/test_user.py:5: error: Call to untyped function "get_user" in typed
context  [no-untyped-call]
        assert get_user("1")
               ^~~~~~~~~~~~~
pyproject.toml: note: unused section(s): module = ['tests.*']
Found 9 errors in 4 files (checked 4 source files)

[INFO] Restored changes from /home/irf1551/.cache/pre-commit/patch1790053012-1467468.
error: failed to push some refs to 'github.com:irfan-truminds/dev-toolchain-demo.git'


```

## Example Server Side Enforcement
```bash
(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$ git push origin feat/server-side-hooks --no-verify
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 351 bytes | 351.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
remote: error: GH013: Repository rule violations found for refs/heads/feat/server-side-hooks.
remote: Review all repository rules at https://github.com/irfan-truminds/dev-toolchain-demo/rules?ref=refs%2Fheads%2Ffeat%2Fserver-side-hooks
remote: 
remote: - Changes must be made through a pull request.
remote: 
remote: - Required status check "Execute Unified Quality Suite" is expected.
remote: 
To github.com:irfan-truminds/dev-toolchain-demo.git
 ! [remote rejected] feat/server-side-hooks -> feat/server-side-hooks (push declined due to repository rule violations)
error: failed to push some refs to 'github.com:irfan-truminds/dev-toolchain-demo.git'

(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$
(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$
(.venv) irf1551@irf1551-Latitude-3420:~/repos/dev-toolchain-demo$ git push origin feat/server-side-hooks --no-verify
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 385 bytes | 385.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
remote: error: GH013: Repository rule violations found for refs/heads/feat/server-side-hooks.
remote: 
remote: - GITHUB PUSH PROTECTION
remote:   —————————————————————————————————————————
remote:     Resolve the following violations before pushing again
remote: 
remote:     - Push cannot contain secrets
remote: 
remote:     
remote:      (?) Learn how to resolve a blocked push
remote:      https://docs.github.com/code-security/secret-scanning/working-with-secret-scanning-and-push-protection/working-with-push-protection-from-the-command-line#resolving-a-blocked-push
remote:     
remote:     
remote:       —— Slack API Token ———————————————————————————————————
remote:        locations:
remote:          - commit: 441d42d0b3f77b80aa76eb0626129d5c161620a4
remote:            path: test_secret.txt:4
remote:     
remote:        (?) To push, remove secret from commit(s) or follow this URL to allow the secret.
remote:        https://github.com/irfan-truminds/dev-toolchain-demo/security/secret-scanning/unblock-secret/3JdKLCxsYFiQPsrcF0scHm1fXnH
remote:     
remote: 
remote: 
To github.com:irfan-truminds/dev-toolchain-demo.git
 ! [remote rejected] feat/server-side-hooks -> feat/server-side-hooks (push declined due to repository rule violations)
error: failed to push some refs to 'github.com:irfan-truminds/dev-toolchain-demo.git'
```

## Workflow Responsibilities Summary

| Workflow File | Primary Triggers | Required Permissions | Key Tools / Actions |
| --- | --- | --- | --- |
| `pr-quality.yml` | `pull_request` | `contents: read` | `check-quality.sh ci`, `pytest`, `mypy`, `black` |
| `deploy.yml` | `push` (main/tags) | `packages: write`, Environment access | `docker buildx`, `trivy`, deployment CLI |
| `scheduled-security.yml` | `schedule` (cron), `workflow_dispatch` | `security-events: write` | `gitleaks detect`, `pip-audit`, SARIF upload |
| *(Native config)* `.github/dependabot.yml` | Scheduled interval (e.g., daily/weekly) | Managed natively by GitHub | Dependabot PRs |


## To-Do (human)
- [] add sample build, test, deploy pipeline
- [x] test github push protection, PR checks
- [x] setup scheduled dependency scans for CVEs, also explore codeql


## To-Do (AI)
Research on these topics:
- [] check if we need to set -euo pipefail in quality check script - is it better to fail fast or have all results first?
- [] check if dependency audit needs to be moved to scheduled CI workflow instead of being part of PR checks, or keep in both
- [] check how to reorganize security audit tools (semgrep, codeql, gitleaks, etc) - how to use them in CI and github "security and quality tab" which has dependencies, code scanning, and secret scanning separately
- [] how To configure developer credentials, SSH keys, Claude Code CLI state, and Model Context Protocol (MCP) servers inside a Dev Container, - potential solution: leverage host bind mounts, environment variables, and lifecycle scripts inside .devcontainer/devcontainer.json.

