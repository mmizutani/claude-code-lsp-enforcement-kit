#!/usr/bin/env bash
# Validate .claude-plugin/marketplace.json.
# Two-stage: (1) `claude plugin validate` (official semantic checks)
#            (2) inline ajv2020 via scripts/validate-manifest.cjs (schema-level).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
schema_path="${repo_root}/schemas/claude-plugin-marketplace-manifest.schema.json"
marketplace_json="${repo_root}/.claude-plugin/marketplace.json"

echo "Validating Marketplace manifest (.claude-plugin/marketplace.json)"

# When marketplace.json is present alongside plugin.json, the CLI validates
# the marketplace (confirmed by inspecting the CLI's output line, which
# always says "Validating marketplace manifest" in that case). So running
# the unstaged repo here is the correct call for marketplace validation.
claude plugin validate --strict "${repo_root}"

if ! (cd "${repo_root}" && node -e "require.resolve('ajv/dist/2020'); require.resolve('ajv-formats')") >/dev/null 2>&1; then
  echo "Missing dev deps in ${repo_root}/node_modules. Run: npm ci --ignore-scripts --no-audit --no-fund" >&2
  exit 1
fi

node "${repo_root}/scripts/validate-manifest.cjs" "${schema_path}" "${marketplace_json}"
