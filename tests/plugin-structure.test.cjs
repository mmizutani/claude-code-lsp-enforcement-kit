'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');

describe('plugin.json', () => {
  const pluginJsonPath = path.join(ROOT, '.claude-plugin', 'plugin.json');

  it('exists and is valid JSON', () => {
    const raw = fs.readFileSync(pluginJsonPath, 'utf8');
    assert.doesNotThrow(() => JSON.parse(raw));
  });

  it('has required "name" field', () => {
    const data = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
    assert.equal(data.name, 'lsp-enforcement-kit');
  });

  it('has version, description, and author', () => {
    const data = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
    assert.ok(data.version, 'version should be set');
    assert.ok(data.description, 'description should be set');
    assert.ok(data.author?.name, 'author.name should be set');
  });
});

describe('marketplace.json', () => {
  const marketplacePath = path.join(ROOT, '.claude-plugin', 'marketplace.json');

  it('exists and is valid JSON', () => {
    const raw = fs.readFileSync(marketplacePath, 'utf8');
    assert.doesNotThrow(() => JSON.parse(raw));
  });

  it('has required fields: name, owner.name, plugins', () => {
    const data = JSON.parse(fs.readFileSync(marketplacePath, 'utf8'));
    assert.ok(data.name, 'marketplace name should be set');
    assert.ok(data.owner?.name, 'owner.name should be set');
    assert.ok(Array.isArray(data.plugins), 'plugins should be an array');
    assert.ok(data.plugins.length > 0, 'plugins should not be empty');
  });

  it('plugin name matches plugin.json name', () => {
    const pluginJson = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'plugin.json'), 'utf8'),
    );
    const marketplace = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'),
    );
    const entry = marketplace.plugins[0];
    assert.equal(entry.name, pluginJson.name);
  });

  it('plugin source is "." (self-referencing)', () => {
    const data = JSON.parse(fs.readFileSync(marketplacePath, 'utf8'));
    assert.equal(data.plugins[0].source, '.');
  });
});

describe('require paths use .cjs extension', () => {
  it('no hook script requires detect-lsp-provider without .cjs', () => {
    const hooksDir = path.join(ROOT, 'hooks');
    const files = fs.readdirSync(hooksDir).filter((f) => f.endsWith('.cjs'));
    for (const file of files) {
      const content = fs.readFileSync(path.join(hooksDir, file), 'utf8');
      const staleRequires = content.match(/require\(['"]\.\/lib\/detect-lsp-provider['"]\)/g);
      assert.equal(
        staleRequires,
        null,
        `${file} has stale require without .cjs extension`,
      );
    }
  });
});
