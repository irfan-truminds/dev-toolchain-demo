#!/usr/bin/env bash
# Install this repo's git hooks -- the "adapter" half of one-check-many-triggers.
#
# The durable artifact is scripts/check-quality.sh. This script is disposable
# glue that points git at it. It exists mainly to REFUSE in the three cases
# where a hook installer normally guesses and gets it wrong:
#
#   1. core.hooksPath already points somewhere else  -> another manager owns hooks
#   2. .git/hooks already holds a non-ours hook       -> we would silently shadow it
#   3. git is too old for the mechanism requested     -> the hook would be declared and dead
#
# Case 3 is the one that bites: git does NOT warn about config keys it does not
# understand, so a config-based hook on git < 2.54 is committed, reviewed, and
# silently never runs.
#
#   ./scripts/install-hooks.sh              # install (refuses on conflict)
#   ./scripts/install-hooks.sh --check      # report only, change nothing
#   ./scripts/install-hooks.sh --force      # take over, after saying what it displaced
#   ./scripts/install-hooks.sh --uninstall

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 3

HOOKS_DIR=".githooks"
MODE="install"
case "${1:-}" in
  --check)     MODE="check" ;;
  --force)     MODE="force" ;;
  --uninstall) MODE="uninstall" ;;
  --help|-h)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")          ;;
  *)           echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
die()  { printf '  \033[31mREFUSED\033[0m %s\n' "$1" >&2
         [ -n "${2:-}" ] && printf '          fix: %s\n' "$2" >&2
         exit 1; }

# ---------------------------------------------------------------- preconditions
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository" "run this from inside the repo"

GIT_VERSION="$(git --version | awk '{print $3}')"
echo "git ${GIT_VERSION}"

# Version gate. We only USE the classic mechanism, but report the newer one
# honestly rather than letting someone assume it is available.
ver_ge() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
if ver_ge "$GIT_VERSION" "2.54"; then
  ok "git >= 2.54 -- config-based hooks ('git hook list') are available here"
else
  warn "git < 2.54 -- config-based hooks are NOT available."
  warn "      Declaring [hook \"x\"] in git config on this version is ignored WITHOUT ERROR."
  warn "      Using the classic ${HOOKS_DIR}/ + core.hooksPath mechanism instead."
fi

# ---------------------------------------------------------------- conflict 1
CURRENT="$(git config --local --get core.hooksPath || true)"
GLOBAL="$(git config --global --get core.hooksPath || true)"

if [ -n "$GLOBAL" ]; then
  warn "core.hooksPath is set GLOBALLY to '${GLOBAL}' -- it applies to every repo on this"
  warn "      machine. That is almost never what someone intended."
fi

# Only install/force may be blocked by this. --check reports, --uninstall cleans
# up -- and refusing to uninstall BECAUSE another manager is installed would be
# refusing at exactly the moment the user needs it. (Found by testing, not by
# reading: the first version of this script did precisely that.)
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$HOOKS_DIR" ]; then
  case "$MODE" in
    install) die "core.hooksPath is already set to '${CURRENT}' -- another hook manager owns this repo." \
                 "run with --force to take over, or 'git config --unset core.hooksPath' first" ;;
    force)   warn "displacing existing core.hooksPath='${CURRENT}'" ;;
    *)       warn "core.hooksPath is currently '${CURRENT}' (not ours)" ;;
  esac
fi

# ---------------------------------------------------------------- conflict 2
# Setting core.hooksPath SILENTLY shadows everything in .git/hooks. If anything
# real is in there, say so before it goes dark.
SHADOWED=()
for h in .git/hooks/*; do
  [ -e "$h" ] || continue
  case "$h" in *.sample) continue ;; esac
  [ -x "$h" ] && SHADOWED+=("$(basename "$h")")
done
if [ ${#SHADOWED[@]} -gt 0 ] && [ "$MODE" != "uninstall" ]; then
  warn "these active hooks in .git/hooks will be SHADOWED (not deleted, just never run):"
  for h in "${SHADOWED[@]}"; do warn "        .git/hooks/${h}"; done
  warn "      git gives no warning when this happens. That is why this line exists."
fi

# ---------------------------------------------------------------- report / act
if [ "$MODE" = "check" ]; then
  echo
  echo "core.hooksPath (local)  = ${CURRENT:-<unset>}"
  echo "core.hooksPath (global) = ${GLOBAL:-<unset>}"
  echo "would install           = ${HOOKS_DIR}/"
  [ "${CURRENT:-}" = "$HOOKS_DIR" ] && { ok "already installed"; exit 0; }
  echo "not installed"
  exit 1
fi

if [ "$MODE" = "uninstall" ]; then
  git config --unset core.hooksPath 2>/dev/null
  ok "core.hooksPath unset -- .git/hooks is live again"
  [ ${#SHADOWED[@]} -gt 0 ] && ok "un-shadowed: ${SHADOWED[*]}"
  exit 0
fi

# ---------------------------------------------------------------- write adapters
mkdir -p "$HOOKS_DIR"

# One adapter per trigger. Each is three lines and calls the same script with a
# different mode -- the whole point. If you are editing these, you are probably
# meant to be editing check-quality.sh instead.
write_adapter() {
  local hook="$1" mode="$2"
  cat > "${HOOKS_DIR}/${hook}" <<EOF
#!/usr/bin/env bash
# GENERATED by scripts/install-hooks.sh -- edit scripts/check-quality.sh, not this.
exec "\$(git rev-parse --show-toplevel)/scripts/check-quality.sh" ${mode}
EOF
  chmod +x "${HOOKS_DIR}/${hook}"
  ok "${HOOKS_DIR}/${hook}  ->  check-quality.sh ${mode}"
}

write_adapter pre-commit staged
write_adapter pre-push   pre-push

git config core.hooksPath "$HOOKS_DIR"
ok "core.hooksPath = ${HOOKS_DIR}"

echo
echo "Installed. Note what this did NOT do:"
echo "  - it changed git CONFIG, which is not cloned. Every teammate must run this too."
echo "  - a tracked hooks directory alone runs nothing. That is the safe default:"
echo "    cloning a repo does not execute its hooks."
echo "  - none of this survives --no-verify. That is what the server-side ruleset is for."
