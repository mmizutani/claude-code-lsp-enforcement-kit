'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const HOOKS_DIR = path.join(ROOT, 'hooks');
const HOOKS_JSON_PATH = path.join(HOOKS_DIR, 'hooks.json');

describe('hooks.json', () => {
  let config;

  it('exists and is valid JSON', () => {
    const raw = fs.readFileSync(HOOKS_JSON_PATH, 'utf8');
    config = JSON.parse(raw);
    assert.ok(config.hooks, 'top-level "hooks" key should exist');
  });

  it('has SessionStart, PreToolUse, and PostToolUse events', () => {
    config = config || JSON.parse(fs.readFileSync(HOOKS_JSON_PATH, 'utf8'));
    assert.ok(Array.isArray(config.hooks.SessionStart), 'SessionStart should be an array');
    assert.ok(Array.isArray(config.hooks.PreToolUse), 'PreToolUse should be an array');
    assert.ok(Array.isArray(config.hooks.PostToolUse), 'PostToolUse should be an array');
  });

  it('all referenced .cjs scripts exist', () => {
    config = config || JSON.parse(fs.readFileSync(HOOKS_JSON_PATH, 'utf8'));
    const scriptRe = /\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/([^"]+\.cjs)/;
    const allEntries = [
      ...config.hooks.SessionStart,
      ...config.hooks.PreToolUse,
      ...config.hooks.PostToolUse,
    ];
    for (const entry of allEntries) {
      for (const hook of entry.hooks) {
        const match = hook.command.match(scriptRe);
        assert.ok(match, `command should reference a .cjs script: ${hook.command}`);
        const scriptPath = path.join(HOOKS_DIR, match[1]);
        assert.ok(
          fs.existsSync(scriptPath),
          `referenced script should exist: ${match[1]}`,
        );
      }
    }
  });

  it('PreToolUse covers Grep, Glob, Read, Bash, Agent matchers', () => {
    config = config || JSON.parse(fs.readFileSync(HOOKS_JSON_PATH, 'utf8'));
    const matchers = config.hooks.PreToolUse.map((e) => e.matcher);
    for (const expected of ['Grep', 'Glob', 'Read', 'Bash', 'Agent']) {
      assert.ok(matchers.includes(expected), `PreToolUse should have matcher "${expected}"`);
    }
  });

  it('PostToolUse matcher regex matches known LSP provider tool names', () => {
    config = config || JSON.parse(fs.readFileSync(HOOKS_JSON_PATH, 'utf8'));
    const matcher = config.hooks.PostToolUse[0].matcher;
    const re = new RegExp(matcher);

    // Standalone cclsp
    assert.ok(re.test('mcp__cclsp__find_definition'));
    assert.ok(re.test('mcp__cclsp__get_diagnostics'));
    // Plugin-wrapped cclsp
    assert.ok(re.test('mcp__plugin_typescriptlsp_cclsp__find_definition'));
    // Standalone serena
    assert.ok(re.test('mcp__serena__find_symbol'));
    // Plugin-wrapped serena
    assert.ok(re.test('mcp__plugin_foo_serena__find_symbol'));
    // Non-LSP tools should NOT match
    assert.ok(!re.test('mcp__memory__create_entities'));
    assert.ok(!re.test('Bash'));
    assert.ok(!re.test('Read'));
  });

  it('SessionStart has both reset and inject hooks', () => {
    config = config || JSON.parse(fs.readFileSync(HOOKS_JSON_PATH, 'utf8'));
    const commands = config.hooks.SessionStart.flatMap((e) =>
      e.hooks.map((h) => h.command),
    );
    assert.ok(
      commands.some((c) => c.includes('lsp-session-reset.cjs')),
      'SessionStart should include lsp-session-reset.cjs',
    );
    assert.ok(
      commands.some((c) => c.includes('lsp-session-inject.cjs')),
      'SessionStart should include lsp-session-inject.cjs',
    );
  });
});
