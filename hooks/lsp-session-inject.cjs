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
