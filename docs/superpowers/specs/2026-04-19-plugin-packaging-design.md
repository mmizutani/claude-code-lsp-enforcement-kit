# LSP Enforcement Kit: Plugin Packaging Design

**Date**: 2026-04-19
**Status**: Draft

## Goal

Package the LSP Enforcement Kit as a Claude Code Plugin so users can install it via the plugin marketplace instead of running `install.sh`. Inject `rules/lsp-first.md` as a system prompt at session start via a SessionStart hook.

## Install Flow

```bash
claude plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit
claude plugin install lsp-enforcement-kit@claude-code-lsp-enforcement-kit
```

Or for local development:

```bash
claude --plugin-dir ./claude-code-lsp-enforcement-kit
```

## Directory Structure

The repo root is both the marketplace root and the plugin root:

```
claude-code-lsp-enforcement-kit/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace catalog (self-referencing)
├── hooks/
│   ├── hooks.json               # Hook configuration for plugin system
│   ├── lsp-first-guard.cjs      # PreToolUse: Grep blocker
│   ├── lsp-first-glob-guard.cjs # PreToolUse: Glob blocker
│   ├── lsp-first-read-guard.cjs # PreToolUse: Read gate
│   ├── bash-grep-block.cjs      # PreToolUse: Bash grep blocker
│   ├── lsp-pre-delegation.cjs   # PreToolUse: Agent pre-delegation
│   ├── lsp-usage-tracker.cjs    # PostToolUse: LSP call tracker
│   ├── lsp-session-reset.cjs    # SessionStart: wipe stale state
│   ├── lsp-session-inject.cjs   # SessionStart: inject lsp-first.md prompt
│   └── lib/
│       └── detect-lsp-provider.cjs  # Shared helper
├── rules/
│   └── lsp-first.md             # LSP-first navigation prompt
├── scripts/
│   └── lsp-status.sh            # Diagnostic script
├── tests/
│   ├── lsp-session-inject.test.cjs
│   ├── hooks-json.test.cjs
│   └── plugin-structure.test.cjs
├── README.md
├── CHANGELOG.md
├── LICENSE
└── SECURITY.md
```

## Files to Delete

- `install.sh` — replaced by plugin install
- `install.ps1` — replaced by plugin install

## Files to Rename (.js -> .cjs)

All hook scripts and the shared lib:
- `hooks/*.js` -> `hooks/*.cjs`
- `hooks/lib/*.js` -> `hooks/lib/*.cjs`

All internal `require()` paths updated accordingly:
- `require('./lib/detect-lsp-provider')` -> `require('./lib/detect-lsp-provider.cjs')`

## New Files

### `.claude-plugin/plugin.json`

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

### `.claude-plugin/marketplace.json`

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

### `hooks/hooks.json`

Three event types:

1. **SessionStart** — two hooks, both with `"matcher": ""` (match all):
   - `lsp-session-reset.cjs` — wipes stale per-cwd state
   - `lsp-session-inject.cjs` — reads `rules/lsp-first.md`, emits `{ systemMessage: <content> }`

2. **PreToolUse** — five entries:
   - `"matcher": "Grep"` -> `lsp-first-guard.cjs`
   - `"matcher": "Glob"` -> `lsp-first-glob-guard.cjs`
   - `"matcher": "Read"` -> `lsp-first-read-guard.cjs`
   - `"matcher": "Bash"` -> `bash-grep-block.cjs`
   - `"matcher": "Agent"` -> `lsp-pre-delegation.cjs`

3. **PostToolUse** — one entry:
   - Regex matcher covering cclsp + serena (standalone and plugin-wrapped forms): `mcp__(?:plugin_[^_]+_)?cclsp__|mcp__(?:plugin_[^_]+_)?serena__`
   - -> `lsp-usage-tracker.cjs`

All commands: `node "${CLAUDE_PLUGIN_ROOT}/hooks/<script>.cjs"`

### `hooks/lsp-session-inject.cjs`

```javascript
#!/usr/bin/env node
'use strict';

// Reads rules/lsp-first.md and emits it as a systemMessage on SessionStart.
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

Note: uses `__dirname` (not `${CLAUDE_PLUGIN_ROOT}`) since `__dirname` resolves to the script's actual location in the plugin cache, which is always correct regardless of cwd.

## Testing

Framework: `node:test` + `node:assert` (zero external dependencies).

### Test Plan

1. **`tests/lsp-session-inject.test.cjs`**:
   - Outputs valid JSON with `systemMessage` containing lsp-first.md content
   - Exits 0 even when rules file is missing
   - systemMessage content matches rules/lsp-first.md exactly

2. **`tests/hooks-json.test.cjs`**:
   - hooks.json is valid JSON
   - All referenced .cjs scripts exist
   - All matchers are present (Grep, Glob, Read, Bash, Agent, SessionStart, PostToolUse)
   - PostToolUse matcher regex is valid and matches expected tool names

3. **`tests/plugin-structure.test.cjs`**:
   - plugin.json is valid JSON with required fields
   - marketplace.json is valid JSON with required fields
   - Plugin name matches between plugin.json and marketplace.json plugin entry
   - All .cjs files in hooks/ use .cjs require paths (no bare .js requires to .cjs files)

Run: `node --test tests/`

## Unchanged

- All existing hook behavior — no functional changes
- State directory (`~/.claude/state/`) — absolute path, unaffected by plugin relocation
- `require()` resolution — `__dirname`-based, works in any install location

## Definition of Done

- [ ] `.claude-plugin/plugin.json` and `marketplace.json` created
- [ ] `hooks/hooks.json` created with all hook registrations
- [ ] `hooks/lsp-session-inject.cjs` created and tested
- [ ] All `.js` files renamed to `.cjs` with updated `require()` paths
- [ ] `install.sh` and `install.ps1` deleted
- [ ] All tests pass: `node --test tests/`
- [ ] Plugin loads without errors: `claude --plugin-dir .`
