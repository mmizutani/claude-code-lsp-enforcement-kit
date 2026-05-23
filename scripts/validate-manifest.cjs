#!/usr/bin/env node
'use strict';

/**
 * validate-manifest.cjs — JSON-Schema validator for plugin & marketplace manifests.
 *
 * Why this exists (and not ajv-cli): ajv-cli compiled in JIT mode runs out of
 * heap (>4 GB) on our draft-2020-12 marketplace schema. Calling Ajv directly
 * with the standalone runtime compiler is well under 100 MB and ~200 ms,
 * works on Node 18+, and doesn't need a network round-trip to npm.
 *
 * Usage:
 *   node scripts/validate-manifest.cjs <schema.json> <data.json>
 *
 * Exits 0 on success, 1 on schema/data load error, 2 on validation failure.
 */

const fs = require('fs');
const path = require('path');

const [, , schemaArg, dataArg] = process.argv;
if (!schemaArg || !dataArg) {
  console.error('Usage: node scripts/validate-manifest.cjs <schema.json> <data.json>');
  process.exit(1);
}

let Ajv2020, addFormats;
try {
  Ajv2020 = require('ajv/dist/2020');
  addFormats = require('ajv-formats');
} catch (err) {
  console.error('Missing dependencies. Install with:');
  console.error('  npm install --no-save --prefix "$(mktemp -d)" ajv ajv-formats');
  console.error('or rely on the `npm exec` wrapper in scripts/validate-*-manifest.sh.');
  console.error('');
  console.error('Underlying error:', err.message);
  process.exit(1);
}

function loadJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (err) {
    console.error(`Cannot read or parse ${file}: ${err.message}`);
    process.exit(1);
  }
}

const schemaPath = path.resolve(schemaArg);
const dataPath = path.resolve(dataArg);
const schema = loadJson(schemaPath);
const data = loadJson(dataPath);

const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);

let validate;
try {
  validate = ajv.compile(schema);
} catch (err) {
  console.error(`Schema compilation failed (${schemaPath}):`);
  console.error(err.message);
  process.exit(1);
}

const ok = validate(data);
if (ok) {
  console.log(`✓ ${path.basename(dataPath)} conforms to ${path.basename(schemaPath)}`);
  process.exit(0);
}

console.error(`✗ ${path.basename(dataPath)} FAILS ${path.basename(schemaPath)}`);
for (const err of validate.errors || []) {
  const loc = err.instancePath || '(root)';
  console.error(`  ${loc}: ${err.message}`);
  if (err.params && Object.keys(err.params).length) {
    console.error(`    params: ${JSON.stringify(err.params)}`);
  }
}
process.exit(2);
