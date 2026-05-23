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
claude plugin validate "${repo_root}"

# Ensure local ajv is available (npm install once per clone). On a clean
# checkout this runs in a few seconds; afterwards it's a no-op.
if [ ! -d "${repo_root}/node_modules/ajv" ]; then
  echo "Installing ajv & ajv-formats (one-time)..."
  (cd "${repo_root}" && npm install --silent --no-audit --no-fund)
fi

node "${repo_root}/scripts/validate-manifest.cjs" "${schema_path}" "${marketplace_json}"
