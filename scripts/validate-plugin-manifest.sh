#!/usr/bin/env bash
# Validate .claude-plugin/plugin.json.
#
# `claude plugin validate <path>` prefers marketplace.json when both manifests
# are present at <path>/.claude-plugin/. So this script stages a temp tree
# that contains plugin.json (and the surrounding plugin layout) but NOT
# marketplace.json, then runs `claude plugin validate` there.
#
# Two-stage:
#   1. Official semantic check: `claude plugin validate --strict <temp-tree>`
#   2. JSON-Schema check via scripts/validate-manifest.cjs (Ajv2020).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
schema_path="${repo_root}/schemas/claude-plugin-manifest.schema.json"
plugin_json="${repo_root}/.claude-plugin/plugin.json"

echo "Validating Plugin manifest (.claude-plugin/plugin.json)"

# Verify devDependencies are present. We do not auto-install (lefthook may
# run validate scripts in parallel, racing on the same node_modules).
if ! node -e "require.resolve('ajv/dist/2020'); require.resolve('ajv-formats')" >/dev/null 2>&1; then
  echo "Missing dev deps. Run: npm ci --ignore-scripts --no-audit --no-fund" >&2
  exit 1
fi

# Stage a copy of the plugin layout WITHOUT marketplace.json, so the CLI
# resolves plugin.json and runs the plugin-specific validation pass.
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/cc-plugin-validate.XXXXXX")"
trap 'rm -rf "${tmp_root}"' EXIT

# Copy the directories that participate in plugin discovery. We deliberately
# exclude node_modules, .git, and tests/ to keep the temp tree small.
plugin_tree="${tmp_root}/plugin"
mkdir -p "${plugin_tree}/.claude-plugin"
cp "${plugin_json}" "${plugin_tree}/.claude-plugin/plugin.json"
for d in hooks rules; do
  if [ -d "${repo_root}/${d}" ]; then
    cp -R "${repo_root}/${d}" "${plugin_tree}/${d}"
  fi
done

claude plugin validate --strict "${plugin_tree}"

# JSON-Schema validation runs against the actual file in the repo.
node "${repo_root}/scripts/validate-manifest.cjs" "${schema_path}" "${plugin_json}"
