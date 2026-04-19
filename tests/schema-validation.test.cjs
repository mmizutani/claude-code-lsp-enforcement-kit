'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const SCHEMAS_DIR = path.join(ROOT, 'schemas');

describe('JSON schemas are valid', () => {
  it('plugin manifest schema is valid JSON', () => {
    const raw = fs.readFileSync(
      path.join(SCHEMAS_DIR, 'claude-plugin-manifest.schema.json'),
      'utf8',
    );
    const schema = JSON.parse(raw);
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
    assert.ok(schema.properties.name, 'should define name property');
    assert.deepEqual(schema.required, ['name']);
  });

  it('marketplace manifest schema is valid JSON', () => {
    const raw = fs.readFileSync(
      path.join(SCHEMAS_DIR, 'claude-plugin-marketplace-manifest.schema.json'),
      'utf8',
    );
    const schema = JSON.parse(raw);
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
    assert.deepEqual(schema.required, ['name', 'owner', 'plugins']);
  });

  it('marketplace schema accepts "." as a valid plugin source', () => {
    const raw = fs.readFileSync(
      path.join(SCHEMAS_DIR, 'claude-plugin-marketplace-manifest.schema.json'),
      'utf8',
    );
    const schema = JSON.parse(raw);
    const sourceOptions = schema.$defs.pluginSource.oneOf;
    const dotOption = sourceOptions.find((opt) => opt.const === '.');
    assert.ok(dotOption, 'pluginSource should accept "." as a valid source');
    assert.equal(dotOption.type, 'string');
  });
});

describe('manifests conform to their schemas (structural checks)', () => {
  it('plugin.json name is kebab-case', () => {
    const data = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'plugin.json'), 'utf8'),
    );
    assert.match(data.name, /^[a-z0-9]+(-[a-z0-9]+)*$/);
  });

  it('plugin.json version is semver', () => {
    const data = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'plugin.json'), 'utf8'),
    );
    assert.match(
      data.version,
      /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([\w.-]+))?(?:\+([\w.-]+))?$/,
    );
  });

  it('marketplace.json name is kebab-case', () => {
    const data = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'),
    );
    assert.match(data.name, /^[a-z0-9]+(-[a-z0-9]+)*$/);
  });

  it('marketplace.json does not use reserved names', () => {
    const reserved = [
      'claude-code-marketplace',
      'claude-code-plugins',
      'claude-plugins-official',
      'anthropic-marketplace',
      'anthropic-plugins',
      'agent-skills',
      'life-sciences',
    ];
    const data = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'),
    );
    assert.ok(
      !reserved.includes(data.name),
      `marketplace name "${data.name}" must not be a reserved name`,
    );
  });

  it('all plugin entries have kebab-case names and valid source', () => {
    const data = JSON.parse(
      fs.readFileSync(path.join(ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'),
    );
    for (const plugin of data.plugins) {
      assert.match(plugin.name, /^[a-z0-9]+(-[a-z0-9]+)*$/);
      assert.ok(
        plugin.source === '.' ||
          (typeof plugin.source === 'string' && plugin.source.startsWith('./')) ||
          (typeof plugin.source === 'object' && plugin.source.source),
        `plugin "${plugin.name}" should have a valid source`,
      );
    }
  });
});
