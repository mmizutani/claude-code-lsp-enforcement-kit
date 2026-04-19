#!/usr/bin/env bash
# Validate .claude-plugin/marketplace.json against the JSON Schema.
# Two-stage: claude plugin validate (CLI) + ajv (schema).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
schema_path="${repo_root}/schemas/claude-plugin-marketplace-manifest.schema.json"
marketplace_json="${repo_root}/.claude-plugin/marketplace.json"

echo "Validating Marketplace manifest (.claude-plugin/marketplace.json)"
claude plugin validate "${repo_root}"

# Use npx or pnpm dlx, whichever is available
if command -v pnpm >/dev/null 2>&1; then
  pnpm dlx -p ajv-cli -p ajv-formats ajv validate \
    --spec=draft2020 \
    -s "${schema_path}" \
    -d "${marketplace_json}" \
    --all-errors \
    --errors=text \
    -c ajv-formats
else
  npx -y -p ajv-cli@latest -p ajv-formats@latest ajv validate \
    --spec=draft2020 \
    -s "${schema_path}" \
    -d "${marketplace_json}" \
    --all-errors \
    --errors=text \
    -c ajv-formats
fi
