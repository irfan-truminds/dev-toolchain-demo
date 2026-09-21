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

## Example Enforcement
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

## Workflow Responsibilities
**Yes, you should use separate workflow files for each.**

Combining them into a single YAML file creates security vulnerabilities, bloated permission scopes, and maintenance friction. Decoupling them into dedicated workflows (`pr-quality.yml`, `deploy.yml`, `scheduled-security.yml`) aligns with industry best practices for the following reasons:

* **Security & Least Privilege:** PR workflows triggered by `pull_request` should run with read-only permissions and **no access to production secrets**. Deploy workflows require high-privilege credentials (Docker registries, cloud access). Mixing them risks exposing credentials to untrusted PR code.
* **Execution & Lifecycle Triggers:** PR checks run on open/update events, deploys run on merges to `main` or release tags, and security audits run on cron schedules or out-of-band events.
* **Clear UI & Branch Rulesets:** Distinct workflow files map cleanly to individual status checks in GitHub Rulesets, making it easy to block merges on quality gates without tangling deployment statuses.

---

## Architecture Breakdown & Best Practices

```text
.github/workflows/
├── pr-quality.yml          # Fast PR quality & security gates
├── deploy.yml              # Docker build, scan, and deployment pipeline
└── scheduled-security.yml  # Cron-based deep security & dependency scans

```

---

### 1. PR Checks (`.github/workflows/pr-quality.yml`)

This workflow acts as the non-negotiable quality gate for open pull requests.

#### Best Practices

* **Enforce Read-Only Scope:** Explicitly declare `permissions: { contents: read }`.
* **Cancel Outdated Runs:** Use `concurrency` with `cancel-in-progress: true` so re-pushed commits immediately kill older, redundant CI jobs.
* **Leverage Centralized Logic:** Execute your unified quality script (`./scripts/check-quality.sh ci`) instead of hardcoding redundant steps in YAML.

```yaml
name: PR Quality Gate

on:
  pull_request:
    branches: [ main, develop ]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      
      - name: Install Dependencies
        run: |
          pip install -r requirements.txt
          pip install -e .[dev] semgrep pip-audit pytest-cov
          
      - name: Install Gitleaks
        run: |
          wget -q https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz
          tar -xzf gitleaks_8.18.2_linux_x64.tar.gz gitleaks
          sudo mv gitleaks /usr/local/bin/

      - name: Run Unified Quality Suite
        run: ./scripts/check-quality.sh ci

```

---

### 2. Build, Test & Deploy Pipeline (`.github/workflows/deploy.yml`)

This pipeline builds, scans, and deploys the containerized application upon merging to `main` or pushing a release tag.

#### Best Practices

* **Build Once, Deploy Immutable Artifacts:** Build the container image once, tag it with the immutable Git SHA and SemVer tag, push it to a container registry (GHCR/ECR), and deploy that exact image across staging/production.
* **Scan Images Before Release:** Run container vulnerability scanners (like Trivy or Grype) on the built image before triggering deployment.
* **Use GitHub Environments:** Attach jobs to `environment: production` to utilize GitHub's built-in deployment protection rules, manual approval gates, and scoped environment secrets.
* **Build Cache Acceleration:** Use Buildx with GitHub Actions caching (`cache-from: type=gha`, `cache-to: type=gha`) to keep container build times sub-minute.

```yaml
name: Build & Deploy Container

on:
  push:
    branches: [ main ]
    tags: [ 'v*.*.*' ]

permissions:
  contents: read
  packages: write  # Needed for GHCR

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Scan Image for Vulnerabilities (Trivy)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.meta.outputs.tags }}
          format: 'table'
          exit-code: '1' # Fail deploy if CRITICAL vulnerabilities are found
          severity: 'CRITICAL,HIGH'

  deploy-prod:
    needs: build-and-scan
    runs-on: ubuntu-latest
    environment: production # Triggers manual approval gates & loads prod secrets
    steps:
      - name: Deploy to Cloud
        run: |
          echo "Deploying image tag: ${{ needs.build-and-scan.outputs.image-tag }}"
          # Insert deployment commands (e.g., helm upgrade, kubectl set image, or cloud API)

```

---

### 3. Scheduled Security Runs (`.github/workflows/scheduled-security.yml`)

A codebase that doesn't change can still become vulnerable as new CVEs and exploits are disclosed daily. Scheduled runs proactively audit static code, full Git history, and locked dependencies.

#### Best Practices

* **Decouple Native Dependabot from Custom Cron Scans:**
* Use GitHub's native `.github/dependabot.yml` file for automatic dependency PR generation (runs natively outside GitHub Actions).
* Use `scheduled-security.yml` for deep full-history audits, static analysis (Semgrep/CodeQL), and zero-day dependency checks via `pip-audit`.


* **Publish Results to GitHub Security Tab:** Output findings as SARIF files and upload them using `github/codeql-action/upload-sarif` so security issues appear directly under **Security > Code scanning**.

```yaml
name: Scheduled Security Audit

on:
  schedule:
    # Run every Monday at 02:00 AM UTC
    - cron: '0 2 * * 1'
  workflow_dispatch: # Allows manual triggering from GitHub UI

permissions:
  contents: read
  security-events: write # Required to upload SARIF security alerts

jobs:
  deep-security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Deep scan requires full git history

      - name: Full Repository Secret Audit (Gitleaks)
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Dependency Vulnerability Audit
        run: |
          pip install pip-audit
          pip-audit -r requirements.txt --format sarif -o pip-audit-results.sarif || true

      - name: Upload Security Findings to GitHub
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: pip-audit-results.sarif

```

---

### Workflow Responsibilities Summary

| Workflow File | Primary Triggers | Required Permissions | Key Tools / Actions |
| --- | --- | --- | --- |
| `pr-quality.yml` | `pull_request` | `contents: read` | `check-quality.sh ci`, `pytest`, `mypy`, `black` |
| `deploy.yml` | `push` (main/tags) | `packages: write`, Environment access | `docker buildx`, `trivy`, deployment CLI |
| `scheduled-security.yml` | `schedule` (cron), `workflow_dispatch` | `security-events: write` | `gitleaks detect`, `pip-audit`, SARIF upload |
| *(Native config)* `.github/dependabot.yml` | Scheduled interval (e.g., daily/weekly) | Managed natively by GitHub | Dependabot PRs |

## To-Do
- [] add sample build, test, deploy pipeline
- [x] test github push protection, PR checks
- [] setup scheduled dependency scans for CVEs, also explore codeql
- [] check if we need to set -euo pipefail in quality check script
- [] check if dependency audit needs to be moved to scheduled CI workflow instead of being part of PR checks, or keep in both

