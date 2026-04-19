'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const HOOK_PATH = path.join(__dirname, '..', 'hooks', 'lsp-session-inject.cjs');
const RULE_PATH = path.join(__dirname, '..', 'rules', 'lsp-first.md');

describe('lsp-session-inject', () => {
  it('outputs valid JSON with systemMessage', () => {
    const stdout = execFileSync('node', [HOOK_PATH], {
      input: '{}',
      encoding: 'utf8',
    });
    const parsed = JSON.parse(stdout.trim());
    assert.ok(parsed.systemMessage, 'systemMessage should be present');
    assert.equal(typeof parsed.systemMessage, 'string');
  });

  it('systemMessage matches rules/lsp-first.md content', () => {
    const expected = fs.readFileSync(RULE_PATH, 'utf8').trim();
    const stdout = execFileSync('node', [HOOK_PATH], {
      input: '{}',
      encoding: 'utf8',
    });
    const parsed = JSON.parse(stdout.trim());
    assert.equal(parsed.systemMessage, expected);
  });

  it('exits 0 even when rules file would be missing', () => {
    const wrapper = `
      const path = require('path');
      const origReadFileSync = require('fs').readFileSync;
      require('fs').readFileSync = (p, ...args) => {
        if (p.includes('lsp-first.md')) throw new Error('ENOENT');
        return origReadFileSync(p, ...args);
      };
      require('${HOOK_PATH.replace(/\\/g, '\\\\')}');
    `;
    const result = execFileSync('node', ['-e', wrapper], {
      input: '{}',
      encoding: 'utf8',
      timeout: 5000,
    });
    assert.equal(result.trim(), '');
  });

  it('outputs nothing extra besides the JSON line', () => {
    const stdout = execFileSync('node', [HOOK_PATH], {
      input: '{}',
      encoding: 'utf8',
    });
    const lines = stdout.trim().split('\n').filter(Boolean);
    assert.equal(lines.length, 1, 'should output exactly one line');
    assert.doesNotThrow(() => JSON.parse(lines[0]));
  });
});
