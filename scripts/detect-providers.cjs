#!/usr/bin/env node
'use strict';

/**
 * detect-providers.cjs — call detectProviders() in the installed helper.
 *
 * scripts/lsp-status.sh previously inlined this with `node -e "...'${PATH}'..."`,
 * which is a JS-injection sink if the cache path contains quotes. Now the
 * plugin root is passed as argv and used via path.join — no string templating.
 *
 * Usage:
 *   node scripts/detect-providers.cjs <plugin-root>
 *
 * Output (single line):
 *   cclsp, serena   — detected providers, comma-joined
 *   (none detected) — helper resolved but returned no providers
 *
 * Exit code:
 *   0 — at least one provider detected
 *   1 — zero providers
 *   2 — helper missing or threw
 */

const path = require('path');

const pluginRoot = process.argv[2];
if (!pluginRoot) {
  process.stderr.write('Usage: detect-providers.cjs <plugin-root>\n');
  process.exit(2);
}

const helperPath = path.join(pluginRoot, 'hooks', 'lib', 'detect-lsp-provider.cjs');

try {
  const helper = require(helperPath);
  const providers = helper.detectProviders();
  if (Array.isArray(providers) && providers.length > 0) {
    process.stdout.write(`${providers.join(', ')}\n`);
    process.exit(0);
  }
  process.stdout.write('(none detected)\n');
  process.exit(1);
} catch (err) {
  const msg = String(err && err.message ? err.message : err).replace(/[\x00-\x1f\x7f]/g, '');
  process.stderr.write(`detect-providers: helper failed (${msg})\n`);
  process.stdout.write('(helper error)\n');
  process.exit(2);
}
