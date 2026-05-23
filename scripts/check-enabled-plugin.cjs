#!/usr/bin/env node
'use strict';

/**
 * check-enabled-plugin.cjs — read enabledPlugins[<id>] from a settings.json.
 *
 * Used as the fallback path in scripts/lsp-status.sh when `claude plugin
 * list --json` isn't available. Reads the settings path from argv (never
 * via shell interpolation, so a HOME containing quotes is harmless).
 *
 * Usage:
 *   node scripts/check-enabled-plugin.cjs <settings.json> <plugin-id>
 *
 * Stdout: one of `enabled`, `disabled`, `missing`.
 * Exit code: 0 on enabled, 1 otherwise.
 */

const fs = require('fs');

const settingsPath = process.argv[2];
const pluginId = process.argv[3];
if (!settingsPath || !pluginId) {
  process.stderr.write('Usage: check-enabled-plugin.cjs <settings.json> <plugin-id>\n');
  process.exit(2);
}

try {
  const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  const v = (s && s.enabledPlugins) ? s.enabledPlugins[pluginId] : undefined;
  const status = v === true ? 'enabled' : v === false ? 'disabled' : 'missing';
  process.stdout.write(`${status}\n`);
  process.exit(status === 'enabled' ? 0 : 1);
} catch {
  process.stdout.write('missing\n');
  process.exit(1);
}
