#!/usr/bin/env bash
# Validate .claude-plugin/plugin.json against the JSON Schema.
# Two-stage: claude plugin validate (CLI) + ajv (schema).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
schema_path="${repo_root}/schemas/claude-plugin-manifest.schema.json"
plugin_json="${repo_root}/.claude-plugin/plugin.json"

echo "Validating Plugin manifest (.claude-plugin/plugin.json)"
claude plugin validate "${repo_root}"

# Use npx or pnpm dlx, whichever is available
if command -v pnpm >/dev/null 2>&1; then
  pnpm dlx -p ajv-cli -p ajv-formats ajv validate \
    --spec=draft2020 \
    -s "${schema_path}" \
    -d "${plugin_json}" \
    --all-errors \
    --errors=text \
    -c ajv-formats
else
  npx -y -p ajv-cli@latest -p ajv-formats@latest ajv validate \
    --spec=draft2020 \
    -s "${schema_path}" \
    -d "${plugin_json}" \
    --all-errors \
    --errors=text \
    -c ajv-formats
fi
