#!/usr/bin/env bash
# lsp-status.sh — LSP Enforcement Kit diagnostic (plugin install model).
#
# Verifies that:
#   1. The plugin is installed via `/plugin install` (cache dir present)
#   2. The plugin is enabled in ~/.claude/settings.json (enabledPlugins)
#   3. All 7 .cjs hook scripts + the detect-lsp-provider helper are intact
#   4. At least one LSP MCP provider (cclsp / Serena) is configured
#   5. The current cwd's runtime state file is present and consistent
#
# Usage:
#   bash scripts/lsp-status.sh
#   # or, once installed, from anywhere:
#   bash ~/.claude/plugins/cache/claude-code-lsp-enforcement-kit/lsp-enforcement-kit/*/scripts/lsp-status.sh
#
# Exits 0 if enforcement is fully active, 1 if any blocking issue is found.
# Designed to be portable across macOS/Linux + bash/zsh.

set -euo pipefail

PLUGIN_NAME="lsp-enforcement-kit"
MARKETPLACE_NAME="claude-code-lsp-enforcement-kit"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
STATE_DIR="${CLAUDE_DIR}/state"
CACHE_BASE="${CLAUDE_DIR}/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}"

# Colors only if stdout is a tty.
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; DIM=''; BOLD=''; NC=''
fi

ok()   { printf '%s✓%s' "${GREEN}" "${NC}"; }
fail() { printf '%s✗%s' "${RED}" "${NC}"; }
warn() { printf '%s!%s' "${YELLOW}" "${NC}"; }

echo "${BOLD}LSP Enforcement Kit — Status${NC} (plugin install model)"
echo "============================================="
echo

# ── 1. Plugin cache directory ───────────────────────────────────────────────
if [ ! -d "${CACHE_BASE}" ]; then
  echo "  Plugin install:      $(fail) not installed"
  echo "  ${DIM}Run: /plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit${NC}"
  echo "  ${DIM}Then: /plugin install ${PLUGIN_KEY}${NC}"
  exit 1
fi

# Pick the most recent version subdirectory (lexicographic sort works for SemVer up to 9.x.x).
PLUGIN_ROOT="$(find "${CACHE_BASE}" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
VERSION="$(basename "${PLUGIN_ROOT}")"
printf '  Plugin install:      %s installed (v%s)\n' "$(ok)" "${VERSION}"
printf '  Plugin root:         %s%s%s\n' "${DIM}" "${PLUGIN_ROOT}" "${NC}"

# ── 2. enabledPlugins entry ─────────────────────────────────────────────────
if [ ! -f "${SETTINGS}" ]; then
  echo "  enabledPlugins:      $(fail) ${SETTINGS} missing"
  exit 1
fi

ENABLED_STATUS="$(node -e "
  try {
    const s = JSON.parse(require('fs').readFileSync('${SETTINGS}','utf8'));
    const v = (s.enabledPlugins || {})['${PLUGIN_KEY}'];
    console.log(v === true ? 'enabled' : v === false ? 'disabled' : 'missing');
  } catch (e) { console.log('parse-error'); }
" 2>/dev/null)"

case "${ENABLED_STATUS}" in
  enabled)   printf '  enabledPlugins:      %s enabled (%s)\n' "$(ok)"   "${PLUGIN_KEY}" ;;
  disabled)  printf '  enabledPlugins:      %s disabled — run "/plugin enable %s"\n' "$(warn)" "${PLUGIN_KEY}" ;;
  missing)   printf '  enabledPlugins:      %s no entry — run "/plugin install %s"\n' "$(fail)" "${PLUGIN_KEY}" ;;
  *)         printf '  enabledPlugins:      %s could not parse ${SETTINGS}\n' "$(fail)" ;;
esac

# ── 3. Hook & helper file inventory ─────────────────────────────────────────
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
status_icon="$(ok)"
[ "${installed}" -eq "${hooks_total}" ] || status_icon="$(fail)"
printf '  Hook scripts:        %s %d/%d' "${status_icon}" "${installed}" "${hooks_total}"
if [ ${#missing[@]} -gt 0 ]; then
  printf ' %s(missing: %s)%s' "${DIM}" "${missing[*]}" "${NC}"
fi
echo

helper_ok="no"
if [ -f "${PLUGIN_ROOT}/hooks/lib/detect-lsp-provider.cjs" ]; then helper_ok="yes"; fi
helper_icon="$([ "${helper_ok}" = "yes" ] && ok || fail)"
printf '  Shared helper:       %s detect-lsp-provider.cjs %s\n' "${helper_icon}" "${helper_ok}"

hooks_json_ok="no"
if [ -f "${PLUGIN_ROOT}/hooks/hooks.json" ]; then hooks_json_ok="yes"; fi
hj_icon="$([ "${hooks_json_ok}" = "yes" ] && ok || fail)"
printf '  hooks.json:          %s %s\n' "${hj_icon}" "${hooks_json_ok}"

# ── 4. Detected LSP providers ───────────────────────────────────────────────
if [ "${helper_ok}" = "yes" ]; then
  providers="$(node -e "
    try {
      const lib = require('${PLUGIN_ROOT}/hooks/lib/detect-lsp-provider.cjs');
      const p = lib.detectProviders();
      console.log(p.length ? p.join(', ') : '(none detected)');
    } catch (e) { console.log('(helper error: ' + e.message + ')'); }
  " 2>/dev/null)"
  if [ "${providers}" = "(none detected)" ]; then
    printf '  LSP providers:       %s %s\n' "$(warn)" "${providers}"
    printf '    %sInstall cclsp or Serena to unlock LSP-specific block suggestions.%s\n' "${DIM}" "${NC}"
  else
    printf '  LSP providers:       %s %s\n' "$(ok)" "${providers}"
  fi
fi

# ── 5. Per-cwd runtime state ────────────────────────────────────────────────
CWD_HASH="$(node -e "console.log(require('crypto').createHash('md5').update(process.cwd()).digest('hex').slice(0,12))" 2>/dev/null || echo "")"
FLAG="${STATE_DIR}/lsp-ready-${CWD_HASH}"

echo
echo "${BOLD}Runtime state for cwd${NC} ($(pwd))"
echo "----------------------"
if [ -n "${CWD_HASH}" ] && [ -f "${FLAG}" ]; then
  eval "$(node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync('${FLAG}','utf8'));
      console.log('WARMUP_DONE=' + (d.warmup_done ? 'yes' : 'no'));
      console.log('NAV_COUNT=' + (d.nav_count || 0));
      console.log('READ_COUNT=' + (d.read_count || 0));
      const lt = (d.last_tool || '(none)').replace(/[\$\`\"]/g, '');
      console.log('LAST_TOOL=' + JSON.stringify(lt));
      const age = Math.round((Date.now() - (d.timestamp || 0)) / 60000);
      console.log('AGE_MIN=' + age);
    } catch (e) {
      console.log('WARMUP_DONE=error');
      console.log('NAV_COUNT=0');
      console.log('READ_COUNT=0');
      console.log('LAST_TOOL=\"?\"');
      console.log('AGE_MIN=0');
    }
  " 2>/dev/null)"
  printf '  Warmup done:         %s\n' "${WARMUP_DONE}"
  printf '  nav_count:           %d %s(LSP navigation calls)%s\n' "${NAV_COUNT}" "${DIM}" "${NC}"
  printf '  read_count:          %d %s(unique code files Read)%s\n' "${READ_COUNT}" "${DIM}" "${NC}"
  printf '  Last tool:           %s %s(%d min ago)%s\n' "${LAST_TOOL}" "${DIM}" "${AGE_MIN}" "${NC}"
  printf '  Flag file:           %s%s%s\n' "${DIM}" "${FLAG}" "${NC}"

  echo
  if [ "${WARMUP_DONE}" = "yes" ] && [ "${NAV_COUNT}" -ge 2 ]; then
    echo "  $(ok) Surgical mode active — all Reads unlimited for this session."
  elif [ "${WARMUP_DONE}" = "yes" ] && [ "${NAV_COUNT}" -ge 1 ]; then
    echo "  $(warn) Gate 4 open (Reads 4–5 allowed). One more LSP nav call to unlock surgical mode."
  elif [ "${WARMUP_DONE}" = "yes" ]; then
    echo "  $(warn) Warmup done, 0 nav calls. Gate 3 warns / Gate 4 blocks on next Reads."
  else
    echo "  $(warn) Not warmed up. Gate 1 will block the first Read of a code file."
  fi
else
  echo "  ${DIM}No state file for this cwd yet. The next Read of a code file will trigger Gate 1 warmup.${NC}"
  [ -n "${CWD_HASH}" ] && printf '  %sExpected path: %s%s\n' "${DIM}" "${FLAG}" "${NC}"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "${BOLD}Summary${NC}"
echo "-------"
all_ok=1
[ "${installed}" -eq "${hooks_total}" ] || all_ok=0
[ "${helper_ok}" = "yes" ] || all_ok=0
[ "${hooks_json_ok}" = "yes" ] || all_ok=0
[ "${ENABLED_STATUS}" = "enabled" ] || all_ok=0

if [ "${all_ok}" -eq 1 ]; then
  echo "  ${GREEN}All checks passed.${NC} Enforcement is active."
  echo "  ${DIM}Try Grep(\"SomeCamelSymbol\") in a fresh Claude Code session to verify.${NC}"
  exit 0
fi

echo "  ${RED}Issues detected.${NC} Re-install with:"
echo "    /plugin marketplace update ${MARKETPLACE_NAME}"
echo "    /plugin install ${PLUGIN_KEY}"
exit 1
