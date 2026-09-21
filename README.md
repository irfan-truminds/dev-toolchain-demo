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
## Package Management: Identical Environments, Supply Chain Integrity
* pip
```bash
$ python3 -m venv .venv
$ source .venv/bin/activate
(.venv) $ pip install pip-tools requests black flake8 flake8-builtins pylint
(.venv) $ pip freeze > requirements.in
(.venv) $ pip-compile --generate-hashes requirements.in # generates requirements.txt
(.venv) $ pip uninstall requests
(.venv) $ # simulate hash mismatch (edit requirements.txt, or make the server present a file with different hash)
(.venv) $ pip install --require-hashes -r requirements.txt
ERROR: THESE PACKAGES DO NOT MATCH THE HASHES FROM THE REQUIREMENTS FILE. If you have updated the package versions, please update the hashes. Otherwise, examine the package contents carefully; someone may have tampered with them.
    requests==2.34.2 from https://files.pythonhosted.org/packages/a0/f4/c67b0b3f1b9245e8d266f0f112c500d50e5b4e83cb6f3b71b6528104182a/requests-2.34.2-py3-none-any.whl (from -r requirements.txt (line 225)):
        Expected sha256 2a0d60c172f83ac6ab31e4554906c0f3b3588d37b5cb91c061f4907e278e0
        Expected     or f288924cae4e29463698d6d60bc6a4da69c89185ad1cc4104f584e960b9ed
             Got        2a0d60c172f83ac6ab31e4554906c0f3b3588d37b5cb939b1c061f4907e278e0

(.venv) $

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

## To-Do
* add sample build, test, deploy pipeline
* test github push protection, PR checks
* setup scheduled dependency scans for CVEs, also explore codeql
* check if we need to set -euo pipefail in quality check script

ghp_hjdhdjdhjd
