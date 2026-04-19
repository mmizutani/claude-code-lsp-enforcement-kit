# Plugin Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the LSP Enforcement Kit as a Claude Code Plugin with marketplace support, injecting `rules/lsp-first.md` via a SessionStart hook.

**Architecture:** The repo root serves as both the marketplace root and plugin root. A new `hooks/hooks.json` declares all hook registrations using `${CLAUDE_PLUGIN_ROOT}` paths. A new `lsp-session-inject.cjs` reads the rule file and emits it as a `systemMessage`. All existing `.js` hook scripts are renamed to `.cjs` for explicit CommonJS.

**Tech Stack:** Node.js (CommonJS), `node:test` + `node:assert` for testing, Claude Code Plugin system.

---

### Task 1: Rename hook scripts from .js to .cjs

**Files:**
- Rename: `hooks/lib/detect-lsp-provider.js` -> `hooks/lib/detect-lsp-provider.cjs`
- Rename: `hooks/lsp-first-guard.js` -> `hooks/lsp-first-guard.cjs`
- Rename: `hooks/lsp-first-glob-guard.js` -> `hooks/lsp-first-glob-guard.cjs`
- Rename: `hooks/lsp-first-read-guard.js` -> `hooks/lsp-first-read-guard.cjs`
- Rename: `hooks/bash-grep-block.js` -> `hooks/bash-grep-block.cjs`
- Rename: `hooks/lsp-pre-delegation.js` -> `hooks/lsp-pre-delegation.cjs`
- Rename: `hooks/lsp-usage-tracker.js` -> `hooks/lsp-usage-tracker.cjs`
- Rename: `hooks/lsp-session-reset.js` -> `hooks/lsp-session-reset.cjs`

- [ ] **Step 1: Rename the shared lib first**

```bash
cd /Users/minoru.mizutani/dev/workspace/claude-code-lsp-enforcement-kit
git mv hooks/lib/detect-lsp-provider.js hooks/lib/detect-lsp-provider.cjs
```

- [ ] **Step 2: Rename all hook scripts**

```bash
git mv hooks/lsp-first-guard.js hooks/lsp-first-guard.cjs
git mv hooks/lsp-first-glob-guard.js hooks/lsp-first-glob-guard.cjs
git mv hooks/lsp-first-read-guard.js hooks/lsp-first-read-guard.cjs
git mv hooks/bash-grep-block.js hooks/bash-grep-block.cjs
git mv hooks/lsp-pre-delegation.js hooks/lsp-pre-delegation.cjs
git mv hooks/lsp-usage-tracker.js hooks/lsp-usage-tracker.cjs
git mv hooks/lsp-session-reset.js hooks/lsp-session-reset.cjs
```

- [ ] **Step 3: Update require paths in files that import the shared lib**

Four files import `'./lib/detect-lsp-provider'`. Update each to `'./lib/detect-lsp-provider.cjs'`:

In `hooks/lsp-first-guard.cjs` line 7:
```javascript
// OLD: const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider');
// NEW:
const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider.cjs');
```

In `hooks/lsp-first-glob-guard.cjs` line 28:
```javascript
// OLD: const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider');
// NEW:
const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider.cjs');
```

In `hooks/bash-grep-block.cjs` line 9:
```javascript
// OLD: const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider');
// NEW:
const { buildSuggestion, buildStructuredBlockResponse } = require('./lib/detect-lsp-provider.cjs');
```

In `hooks/lsp-first-read-guard.cjs` line 8:
```javascript
// OLD: const { buildWarmupInstructions, buildFileWarmupCall } = require('./lib/detect-lsp-provider');
// NEW:
const { buildWarmupInstructions, buildFileWarmupCall } = require('./lib/detect-lsp-provider.cjs');
```

In `hooks/lsp-usage-tracker.cjs` line 19:
```javascript
// OLD: const { isLspProviderTool } = require('./lib/detect-lsp-provider');
// NEW:
const { isLspProviderTool } = require('./lib/detect-lsp-provider.cjs');
```

- [ ] **Step 4: Verify no stale .js requires remain**

```bash
grep -r "require.*detect-lsp-provider[^.]" hooks/ && echo "FAIL: stale require paths" || echo "OK: all require paths updated"
```

Expected: `OK: all require paths updated`

- [ ] **Step 5: Commit**

```bash
git add -A hooks/
git commit -m "refactor: rename hook scripts .js -> .cjs for explicit CommonJS"
```

---

### Task 2: Delete legacy install scripts

**Files:**
- Delete: `install.sh`
- Delete: `install.ps1`

- [ ] **Step 1: Remove the files**

```bash
git rm install.sh install.ps1
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove legacy install scripts (replaced by plugin install)"
```

---

### Task 3: Create plugin manifest and marketplace catalog

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create `.claude-plugin/` directory**

```bash
mkdir -p .claude-plugin
```

- [ ] **Step 2: Create `plugin.json`**

Write `.claude-plugin/plugin.json`:

```json
{
  "name": "lsp-enforcement-kit",
  "description": "Physical enforcement of LSP-first navigation in Claude Code. Stop burning tokens on Grep — make Claude navigate code like an IDE.",
  "version": "3.0.0",
  "author": {
    "name": "mmizutani"
  },
  "repository": "https://github.com/mmizutani/claude-code-lsp-enforcement-kit",
  "license": "MIT",
  "keywords": ["lsp", "enforcement", "navigation", "cclsp", "serena"]
}
```

- [ ] **Step 3: Create `marketplace.json`**

Write `.claude-plugin/marketplace.json`:

```json
{
  "name": "claude-code-lsp-enforcement-kit",
  "owner": {
    "name": "mmizutani"
  },
  "plugins": [
    {
      "name": "lsp-enforcement-kit",
      "source": ".",
      "description": "Physical enforcement of LSP-first navigation in Claude Code. Stop burning tokens on Grep."
    }
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/
git commit -m "feat: add plugin manifest and marketplace catalog"
```

---

### Task 4: Create hooks.json

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Create `hooks/hooks.json`**

Write `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-session-reset.cjs\""
          },
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-session-inject.cjs\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Grep",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-first-guard.cjs\""
          }
        ]
      },
      {
        "matcher": "Glob",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-first-glob-guard.cjs\""
          }
        ]
      },
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-first-read-guard.cjs\""
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/bash-grep-block.cjs\""
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-pre-delegation.cjs\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "mcp__(?:plugin_[^_]+_)?cclsp__|mcp__(?:plugin_[^_]+_)?serena__",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/lsp-usage-tracker.cjs\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: add hooks.json for plugin hook registration"
```

---

### Task 5: TDD — lsp-session-inject.cjs

**Files:**
- Create: `tests/lsp-session-inject.test.cjs`
- Create: `hooks/lsp-session-inject.cjs`

- [ ] **Step 1: Create tests directory**

```bash
mkdir -p tests
```

- [ ] **Step 2: Write the failing tests**

Write `tests/lsp-session-inject.test.cjs`:

```javascript
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
    // Run the script with __dirname overridden to a temp dir so rules/lsp-first.md
    // doesn't exist. We do this by wrapping in a one-liner that patches __dirname.
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
    // Should produce empty stdout (no JSON) since file is "missing"
    assert.equal(result.trim(), '');
  });

  it('outputs nothing extra besides the JSON line', () => {
    const stdout = execFileSync('node', [HOOK_PATH], {
      input: '{}',
      encoding: 'utf8',
    });
    const lines = stdout.trim().split('\n').filter(Boolean);
    assert.equal(lines.length, 1, 'should output exactly one line');
    // Must be valid JSON
    assert.doesNotThrow(() => JSON.parse(lines[0]));
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
node --test tests/lsp-session-inject.test.cjs
```

Expected: FAIL — `hooks/lsp-session-inject.cjs` does not exist yet.

- [ ] **Step 4: Write the minimal implementation**

Write `hooks/lsp-session-inject.cjs`:

```javascript
#!/usr/bin/env node
'use strict';

// lsp-session-inject.cjs — SessionStart hook
//
// Reads rules/lsp-first.md and emits it as a systemMessage.
// Must never block session start — exits 0 unconditionally.

const fs = require('fs');
const path = require('path');

const rulePath = path.join(__dirname, '..', 'rules', 'lsp-first.md');

try {
  const content = fs.readFileSync(rulePath, 'utf8').trim();
  if (content) {
    console.log(JSON.stringify({ systemMessage: content }));
  }
} catch {
  // Silent: hook must never block session start
}

process.exit(0);
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
node --test tests/lsp-session-inject.test.cjs
```

Expected: all 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add tests/lsp-session-inject.test.cjs hooks/lsp-session-inject.cjs
git commit -m "feat: add lsp-session-inject hook with tests (TDD)"
```

---

### Task 6: TDD — plugin structure validation tests

**Files:**
- Create: `tests/plugin-structure.test.cjs`

- [ ] **Step 1: Write the failing tests**

Write `tests/plugin-structure.test.cjs`:

```javascript
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
```

- [ ] **Step 2: Run tests to verify they pass**

These tests validate the already-created artifacts from Tasks 1 and 3. They should pass immediately.

```bash
node --test tests/plugin-structure.test.cjs
```

Expected: all tests PASS (the files already exist from Tasks 1 and 3).

- [ ] **Step 3: Commit**

```bash
git add tests/plugin-structure.test.cjs
git commit -m "test: add plugin structure validation tests"
```

---

### Task 7: TDD — hooks.json validation tests

**Files:**
- Create: `tests/hooks-json.test.cjs`

- [ ] **Step 1: Write the failing tests**

Write `tests/hooks-json.test.cjs`:

```javascript
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
```

- [ ] **Step 2: Run tests to verify they pass**

These tests validate the hooks.json created in Task 4. They should pass immediately.

```bash
node --test tests/hooks-json.test.cjs
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add tests/hooks-json.test.cjs
git commit -m "test: add hooks.json validation tests"
```

---

### Task 8: Run full test suite

- [ ] **Step 1: Run all tests**

```bash
node --test tests/
```

Expected: all tests across all 3 files PASS.

- [ ] **Step 2: Final commit with all changes**

Only needed if there are any uncommitted fixes. Otherwise, all work is already committed from Tasks 1-7.

```bash
git status
```

Expected: clean working tree (everything committed).
