#!/usr/bin/env bash
# lsp-status.sh — LSP Enforcement Kit diagnostic (plugin install model).
#
# Verifies that:
#   1. The plugin is installed and enabled (any scope: user/project/local).
#   2. The cached plugin tree contains all .cjs hook scripts + the helper
#      + hooks.json.
#   3. The detect-lsp-provider helper resolves (informational — missing
#      providers degrade block-suggestions but do NOT disable enforcement).
#   4. The current cwd's runtime state file is present and consistent.
#
# Authoritative source of truth: `claude plugin list --json`. We fall back
# to scanning ~/.claude/settings.json:enabledPlugins only if the CLI is
# unavailable.
#
# Usage:
#   bash scripts/lsp-status.sh
#   bash <plugin-cache-dir>/scripts/lsp-status.sh
#
# Exits 0 if enforcement is active, 1 if any blocking issue is found.

set -euo pipefail

PLUGIN_ID="lsp-enforcement-kit@claude-code-lsp-enforcement-kit"
PLUGIN_NAME="lsp-enforcement-kit"
MARKETPLACE_NAME="claude-code-lsp-enforcement-kit"

CLAUDE_DIR="${HOME}/.claude"
STATE_DIR="${CLAUDE_DIR}/state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors only on a tty.
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; NC=$'\033[0m'
  COLOR_MODE="color"
else
  GREEN=''; RED=''; YELLOW=''; DIM=''; BOLD=''; NC=''
  COLOR_MODE="no-color"
fi

ok()   { printf '%s✓%s' "${GREEN}" "${NC}"; }
fail() { printf '%s✗%s' "${RED}" "${NC}"; }
warn() { printf '%s!%s' "${YELLOW}" "${NC}"; }

echo "${BOLD}LSP Enforcement Kit — Status${NC} (plugin install model)"
echo "============================================="
echo

PLUGIN_ROOT=""
ENABLED_STATUS="missing"
SCOPE=""
VERSION=""

# ── 1. Authoritative lookup via `claude plugin list --json` ────────────────
# We pipe the JSON into a Node helper and read 4 newline-separated raw values
# with `read -r`. Crucially: no `eval`, no JSON.stringify (JSON escaping is
# not shell escaping — `$(...)`/backticks in a value would still expand).
#
# Helper exit codes drive how we treat the result:
#   0 → plugin found, values printed → use them, skip fallback
#   1 → plugin authoritatively NOT in list → use the "missing" payload, skip
#       fallback (we trust the CLI; an out-of-date cache must not mask this)
#   2 → input wasn't valid JSON (CLI broken / misformatted) → fall through
#   *  → CLI itself unavailable / unreadable → fall through
cli_consulted=0
if command -v claude >/dev/null 2>&1; then
  if PLUGIN_QUERY="$(claude plugin list --json 2>/dev/null)"; then
    plugin_lookup="$(printf '%s' "${PLUGIN_QUERY}" \
      | node "${SCRIPT_DIR}/find-installed-plugin.cjs" "${PLUGIN_ID}" 2>/dev/null)" \
      && lookup_rc=0 || lookup_rc=$?

    case "${lookup_rc}" in
      0|1)
        # Authoritative result. Consume the 4 lines even when status=missing
        # so PLUGIN_ROOT correctly remains empty and we skip the fallback.
        {
          IFS= read -r PLUGIN_ROOT || PLUGIN_ROOT=""
          IFS= read -r ENABLED_STATUS || ENABLED_STATUS="missing"
          IFS= read -r SCOPE || SCOPE=""
          IFS= read -r VERSION || VERSION=""
        } <<EOF
${plugin_lookup}
EOF
        cli_consulted=1
        ;;
      *)
        # JSON parse failure or some other helper-internal error.
        # Treat this the same as "CLI unavailable" — fall through to scan.
        ;;
    esac
  fi
fi

# Fallback: only when the authoritative CLI lookup couldn't be made.
# A successful CLI lookup that *says* the plugin is missing must NOT be
# overridden by a stale ~/.claude/plugins/cache entry from a prior install.
if [ "${cli_consulted}" -eq 0 ] && [ -f "${CLAUDE_DIR}/settings.json" ]; then
  PLUGIN_ROOT_BASE="${CLAUDE_DIR}/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}"
  if [ -d "${PLUGIN_ROOT_BASE}" ]; then
    # `sort -V` exists on macOS BSD sort (10.7+) and GNU coreutils — both
    # current Claude Code targets. If a version directory exists at all,
    # the find/sort/tail chain returns the newest. We still defend against
    # an empty result (cache base exists but no version subdir was created).
    candidate="$(find "${PLUGIN_ROOT_BASE}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [ -n "${candidate}" ] && [ -d "${candidate}" ]; then
      PLUGIN_ROOT="${candidate}"
      VERSION="${PLUGIN_ROOT##*/}"
      SCOPE="user(fallback)"
    fi
  fi
  if status_out="$(node "${SCRIPT_DIR}/check-enabled-plugin.cjs" "${CLAUDE_DIR}/settings.json" "${PLUGIN_ID}" 2>/dev/null)"; then
    ENABLED_STATUS="${status_out%$'\n'}"
  else
    ENABLED_STATUS="${status_out%$'\n'}"
    [ -z "${ENABLED_STATUS}" ] && ENABLED_STATUS="missing"
  fi
fi

if [ -z "${PLUGIN_ROOT}" ] || [ ! -d "${PLUGIN_ROOT}" ]; then
  echo "  Plugin install:      $(fail) not installed"
  echo "  ${DIM}Run: /plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit${NC}"
  echo "  ${DIM}Then: /plugin install ${PLUGIN_ID}${NC}"
  exit 1
fi

printf '  Plugin install:      %s installed (v%s, scope=%s)\n' "$(ok)" "${VERSION:-unknown}" "${SCOPE:-unknown}"
printf '  Plugin root:         %s%s%s\n' "${DIM}" "${PLUGIN_ROOT}" "${NC}"

case "${ENABLED_STATUS}" in
  enabled)  printf '  Plugin status:       %s enabled\n' "$(ok)" ;;
  disabled) printf '  Plugin status:       %s disabled — run "/plugin enable %s"\n' "$(warn)" "${PLUGIN_ID}" ;;
  missing)  printf '  Plugin status:       %s no enabledPlugins entry — run "/plugin install %s"\n' "$(fail)" "${PLUGIN_ID}" ;;
  *)        printf '  Plugin status:       %s could not determine (got "%s")\n' "$(fail)" "${ENABLED_STATUS}" ;;
esac

# ── 2. Hook & helper file inventory ─────────────────────────────────────────
EXPECTED_HOOKS=(
  bash-grep-block.cjs
  lsp-first-guard.cjs
  lsp-first-glob-guard.cjs
  lsp-first-read-guard.cjs
  lsp-pre-delegation.cjs
  lsp-session-inject.cjs
  lsp-session-reset.cjs
  lsp-usage-tracker.cjs
)
installed=0
missing=()
for h in "${EXPECTED_HOOKS[@]}"; do
  if [ -f "${PLUGIN_ROOT}/hooks/${h}" ]; then
    installed=$((installed + 1))
  else
    missing+=("${h}")
  fi
done

hooks_total=${#EXPECTED_HOOKS[@]}
hooks_icon="$(ok)"
[ "${installed}" -eq "${hooks_total}" ] || hooks_icon="$(fail)"
printf '  Hook scripts:        %s %d/%d' "${hooks_icon}" "${installed}" "${hooks_total}"
if [ ${#missing[@]} -gt 0 ]; then
  printf ' %s(missing: %s)%s' "${DIM}" "${missing[*]}" "${NC}"
fi
echo

if [ -f "${PLUGIN_ROOT}/hooks/lib/detect-lsp-provider.cjs" ]; then
  helper_ok=1
  printf '  Shared helper:       %s detect-lsp-provider.cjs\n' "$(ok)"
else
  helper_ok=0
  printf '  Shared helper:       %s detect-lsp-provider.cjs missing\n' "$(fail)"
fi

if [ -f "${PLUGIN_ROOT}/hooks/hooks.json" ]; then
  hooks_json_ok=1
  printf '  hooks.json:          %s present\n' "$(ok)"
else
  hooks_json_ok=0
  printf '  hooks.json:          %s missing\n' "$(fail)"
fi

# ── 3. Detected LSP providers (informational) ───────────────────────────────
if [ "${helper_ok}" -eq 1 ]; then
  set +e
  providers_out="$(node "${SCRIPT_DIR}/detect-providers.cjs" "${PLUGIN_ROOT}" 2>/dev/null)"
  providers_rc=$?
  set -e
  case "${providers_rc}" in
    0) printf '  LSP providers:       %s %s\n' "$(ok)"   "${providers_out}" ;;
    1)
      printf '  LSP providers:       %s %s\n' "$(warn)" "${providers_out}"
      printf '    %sInstall cclsp or Serena for LSP-specific block suggestions (enforcement still fires).%s\n' "${DIM}" "${NC}" ;;
    *) printf '  LSP providers:       %s helper error\n' "$(fail)" ;;
  esac
fi

# ── 4. Per-cwd runtime state ────────────────────────────────────────────────
CWD_HASH="$(node -e "console.log(require('crypto').createHash('md5').update(process.cwd()).digest('hex').slice(0,12))" 2>/dev/null || echo "")"
FLAG="${STATE_DIR}/lsp-ready-${CWD_HASH}"

echo
echo "${BOLD}Runtime state for cwd${NC} ($(pwd))"
echo "----------------------"
if [ -n "${CWD_HASH}" ]; then
  set +e
  node "${SCRIPT_DIR}/print-runtime-state.cjs" "${FLAG}" "${COLOR_MODE}" | grep -v '^STATUS='
  set -e
else
  echo "  ${DIM}Could not compute cwd hash (node missing?).${NC}"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "${BOLD}Summary${NC}"
echo "-------"
all_ok=1
[ "${installed}" -eq "${hooks_total}" ] || all_ok=0
[ "${helper_ok}" -eq 1 ]              || all_ok=0
[ "${hooks_json_ok}" -eq 1 ]          || all_ok=0
[ "${ENABLED_STATUS}" = "enabled" ]   || all_ok=0
# Note: LSP-provider detection is intentionally NOT included — enforcement
# still fires without one, the kit just falls back to generic block hints.

if [ "${all_ok}" -eq 1 ]; then
  echo "  ${GREEN}All checks passed.${NC} Enforcement is active."
  echo "  ${DIM}Try Grep(\"SomeCamelSymbol\") in a fresh Claude Code session to verify.${NC}"
  exit 0
fi

echo "  ${RED}Issues detected.${NC} Re-install with:"
echo "    /plugin marketplace update ${MARKETPLACE_NAME}"
echo "    /plugin install ${PLUGIN_ID}"
exit 1
