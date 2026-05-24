#!/usr/bin/env node
'use strict';

/**
 * find-installed-plugin.cjs — look up a plugin by id in `claude plugin list --json`
 * output and emit 4 newline-separated raw values: installPath, status, scope, version.
 *
 * Designed to be consumed by bash via `read -r`. We never let JSON values
 * re-enter `eval`, even via JSON.stringify — JSON escaping is NOT shell
 * escaping, and `$(...)`/backticks would still expand under `eval`.
 *
 * Usage:
 *   claude plugin list --json | node scripts/find-installed-plugin.cjs <plugin-id>
 *
 * Stdout (always 4 lines, even when not found):
 *   <installPath>
 *   <status>     # one of: enabled, disabled, missing
 *   <scope>      # user / project / local / managed, or empty
 *   <version>    # plugin version string, or empty
 *
 * Control characters (NUL, CR, LF) are stripped from every value before
 * emission, so a malicious manifest can never inject an extra `read`-able line.
 *
 * Exit code:
 *   0 — plugin found and entry parsed
 *   1 — plugin not in the list (4 empty/missing lines still written)
 *   2 — input was not valid JSON
 */

const id = process.argv[2];
if (!id) {
  process.stderr.write('Usage: find-installed-plugin.cjs <plugin-id> (reads claude plugin list --json from stdin)\n');
  process.exit(2);
}

const CTRL = new RegExp('[\\x00\\r\\n]', 'g');
function clean(value) {
  if (typeof value !== 'string') return '';
  return value.replace(CTRL, '');
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  raw += chunk;
});
process.stdin.on('end', () => {
  let list;
  try {
    list = JSON.parse(raw);
  } catch (err) {
    // Emit blanks so bash's `read` calls don't dangle.
    process.stdout.write('\n\n\n\n');
    process.exit(2);
  }
  if (!Array.isArray(list)) {
    process.stdout.write('\n\n\n\n');
    process.exit(2);
  }
  const entry = list.find((e) => e && e.id === id);
  if (!entry) {
    process.stdout.write(['', 'missing', '', ''].join('\n') + '\n');
    process.exit(1);
  }
  const status =
    entry.enabled === true ? 'enabled' : entry.enabled === false ? 'disabled' : 'missing';
  process.stdout.write(
    [
      clean(entry.installPath),
      clean(status),
      clean(entry.scope),
      clean(entry.version),
    ].join('\n') + '\n',
  );
  process.exit(0);
});
