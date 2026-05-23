<h1 align="center">LSP Enforcement Kit</h1>

<p align="center">
  <strong>Physical enforcement of LSP-first navigation in Claude Code.</strong>
  <br>
  Stop burning tokens on Grep. Make Claude navigate code like an IDE — 100% of the time.
</p>

<p align="center">
  <a href="https://github.com/mmizutani/claude-code-lsp-enforcement-kit/releases"><img src="https://img.shields.io/github/v/release/mmizutani/claude-code-lsp-enforcement-kit?style=for-the-badge&color=6366f1" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mmizutani/claude-code-lsp-enforcement-kit?style=for-the-badge&color=10b981" alt="License"></a>
  <a href="https://github.com/mmizutani/claude-code-lsp-enforcement-kit/stargazers"><img src="https://img.shields.io/github/stars/mmizutani/claude-code-lsp-enforcement-kit?style=for-the-badge&color=f59e0b" alt="Stars"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-8b5cf6?style=for-the-badge" alt="Claude Code plugin">
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> &bull;
  <a href="#-the-problem">Why</a> &bull;
  <a href="#-token-savings-grep-vs-lsp-per-operation">Savings</a> &bull;
  <a href="#-architecture-6-hooks--1-tracker">Architecture</a> &bull;
  <a href="#-how-each-hook-works">Hooks</a> &bull;
  <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center">
  <img src="assets/token-savings.png" alt="LSP vs Grep token savings — 73% per week" width="720">
</p>

---

## In Action

When Claude tries to `Grep` for a code symbol, the hook blocks with a copy-pasteable LSP command:

```
⛔ LSP-FIRST BLOCK: Pattern contains code symbol(s) — use LSP instead
Symbols: handleSubmit, UserService

LSP tools:
  handleSubmit:
    mcp__cclsp__find_references("handleSubmit")  (cclsp)

  UserService:
    mcp__cclsp__find_workspace_symbols("UserService")  (cclsp)
```

When Claude tries to `Read` a code file without warming up LSP, the progressive gate blocks:

```
🛡️  LSP-FIRST READ GATE — Gate 1: warmup required

  Call one of these first:
    mcp__cclsp__get_diagnostics("src/page.tsx")  (cclsp)

  CONCRETE CALL FOR THIS FILE (works in any project):
    mcp__cclsp__get_diagnostics("src/page.tsx")

  After warmup: 2 free Reads, then need LSP navigation.
```

No generic advice. Every block message is parametrized by the actual file Claude tried to touch.

---

## ⚡ Quick Start

Install as a [Claude Code plugin](https://code.claude.com/docs/en/plugins) — no file copying, no settings.json surgery:

```text
/plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit
/plugin install lsp-enforcement-kit@claude-code-lsp-enforcement-kit
```

Restart Claude Code. Done. All seven hooks register automatically, the LSP-first rule injects on session start, and the kit picks up `cclsp` / Serena from your existing MCP config.

Uninstall: `/plugin uninstall lsp-enforcement-kit@claude-code-lsp-enforcement-kit` — everything goes away cleanly, no leftover files in `~/.claude/hooks/`.

---

## 🎯 The Problem

Claude Code defaults to **Grep + Read** for code navigation. This works, but it's wasteful:

```
"Where is handleSubmit defined?"

Grep approach:
  Grep("handleSubmit") → 23 matches, ~1500 tokens of output
  Read file1.tsx (wrong) → 2500 tokens
  Read file2.tsx (still wrong) → 2500 tokens
  Read file3.tsx (found it) → 2500 tokens
  ─────────────────────────────────────
  Total: ~9,000 tokens, 4 tool calls

LSP approach:
  find_definition("handleSubmit") → form-actions.ts:42, ~80 tokens
  Read form-actions.ts:35-55 → ~150 tokens
  ─────────────────────────────────────
  Total: ~230 tokens, 2 tool calls
```

**~40x fewer tokens. Same answer.**

A rule in CLAUDE.md saying "use LSP" helps ~60% of the time. Hooks make it 100%.

## 💰 Token Savings: Grep vs LSP Per Operation

| Task | Grep approach | LSP approach | Saved |
|------|--------------|--------------|-------|
| Find definition of `handleSubmit` | Grep → 23 matches (~1500 tok) + 2 wrong Reads (~5000 tok) = **~6500 tok** | `find_definition` → file:line (~80 tok) + 1 targeted Read (~500 tok) = **~580 tok** | **91%** |
| Find all usages of `UserService` | Grep → 15 matches (~1200 tok), scan results (~300 tok) = **~1500 tok** | `find_references` → 8 file:line pairs (~150 tok) = **~150 tok** | **90%** |
| Check type of `formData` | Read full file (~2500 tok), search visually = **~2500 tok** | `get_hover` → type signature (~60 tok) = **~60 tok** | **98%** |
| Find component `InviteForm` | Glob (~200 tok) + Grep (~800 tok) + Read wrong file (~2500 tok) = **~3500 tok** | `find_workspace_symbols` → exact location (~100 tok) = **~100 tok** | **97%** |
| Who calls `validateToken`? | Grep → noisy results (~1500 tok) + 3 Reads to verify (~6000 tok) = **~7500 tok** | `get_incoming_calls` → caller list (~200 tok) + 1 Read (~500 tok) = **~700 tok** | **91%** |

## 📊 Real-World Data: 1 Week, 2 Projects

Aggregate from a week of development across 2 TypeScript projects:

| Metric | With LSP | Without LSP (estimated) |
|--------|----------|------------------------|
| LSP navigation calls | 39 | — |
| Grep calls on code symbols | 0 (blocked) | ~120 |
| Unique code files Read | 53 | ~180 |
| Estimated navigation tokens | **~85k** | **~320k** |
| **Tokens saved** | | **~235k (~73%)** |

**How the estimate works:**
- Each blocked Grep saves ~1200 tokens of noisy output
- Each avoided Read saves ~1500 tokens of file content loaded into context
- 39 LSP calls cost ~4k tokens total (precise, compact results)
- Without LSP: ~120 Greps + ~180 Reads = ~315k tokens for the same navigation work
- With LSP: 39 nav calls + 53 targeted Reads = ~84k tokens

## 🔌 Works with any LSP MCP server

v2.1 introduces **provider-aware block messages**. The kit detects which LSP MCP server(s) you have installed and tailors its suggestions accordingly:

- [**cclsp**](https://github.com/ktnyt/cclsp) — standalone MCP server or bundled via the `typescript-lsp` Claude Code plugin. Suggestions use `mcp__cclsp__find_definition`, `find_references`, `find_workspace_symbols`, etc.
- [**Serena**](https://github.com/oraios/serena) — high-level symbol MCP server (MIT, by Oraios AI). Multi-language support (Python, Go, Rust, Java, TypeScript, Vue, and more via its bundled `solidlsp` wrapper). Suggestions use `mcp__serena__find_symbol`, `find_referencing_symbols`, `get_symbols_overview`.
- **Both installed** — suggestions show entries for both providers.
- **Neither installed** — generic fallback with install hints for both.

Detection reads user-level Claude Code config (`~/.claude.json`, `~/.claude/settings.json`) and matches known server names. The shared helper is in [`hooks/lib/detect-lsp-provider.cjs`](hooks/lib/detect-lsp-provider.cjs) — adding a new provider means adding one entry to its `PROVIDERS` registry, with no changes to the individual hooks.

## 🏗️ Architecture: 7 Hooks + 1 Tracker

Every hook is registered in [`hooks/hooks.json`](hooks/hooks.json) and resolved via `${CLAUDE_PLUGIN_ROOT}` so the plugin runs from any install location.

```
                    PreToolUse                           PostToolUse
                    ──────────                           ───────────

 Grep call ──→ [lsp-first-guard.cjs] ──→ BLOCK
                  detects code symbols,
                  suggests LSP equivalent

 Glob call ──→ [lsp-first-glob-guard.cjs] ──→ BLOCK
                  blocks *UserService*, **/handleFoo*.ts;
                  allows *.ts, *subdomain*, src/**

 Bash(grep) ──→ [bash-grep-block.cjs] ──→ BLOCK
                  catches grep/rg/ag/ack
                  in shell commands

 Read(.tsx) ──→ [lsp-first-read-guard.cjs] ──→ GATE
                  5 progressive gates
                  (warmup → orient → nav → surgical)

 Agent(impl) ─→ [lsp-pre-delegation.cjs] ──→ BLOCK
                  subagents can't access MCP,
                  orchestrator must pre-resolve

 LSP call ─────────────────────────────────────→ [lsp-usage-tracker.cjs]
                                                   tracks nav_count,
                                                   read_count, state

                    SessionStart
                    ────────────

 New session ──→ [lsp-session-reset.cjs] ──→ WIPE
                    clears stale nav_count for current cwd,
                    forces fresh warmup + re-enforces gates

              ──→ [lsp-session-inject.cjs] ──→ INJECT
                    pushes rules/lsp-first.md into the
                    session as a systemMessage
```

> **v2 → v3 note:** v3 ships the kit as a Claude Code plugin instead of
> `install.sh`. Hook scripts are now `.cjs`, registered through
> `hooks/hooks.json`, and resolved via `${CLAUDE_PLUGIN_ROOT}`. The
> enforcement contract is identical; only the install method changed.
> If you ran the old `install.sh`, delete the entries from
> `~/.claude/settings.json` before installing the plugin to avoid
> double-firing hooks.

## 🔧 How Each Hook Works

### 1. `lsp-first-guard.cjs` — Grep Blocker

**Hook type:** PreToolUse | **Matcher:** `Grep`

Intercepts every Grep call. Detects code symbols in the pattern. Blocks with a suggestion to use the correct LSP tool.

| Pattern | Detected as | Action |
|---------|------------|--------|
| `getUserById` | camelCase symbol | BLOCK |
| `UserService` | PascalCase symbol | BLOCK |
| `router.refresh` | dotted symbol | BLOCK |
| `write_audit_log` | snake_case function | BLOCK |
| `create-folder-modal` | component filename | BLOCK |
| `TODO` | keyword | allow |
| `NEXT_PUBLIC_URL` | env var (SCREAMING_SNAKE) | allow |
| `flex-col` | CSS class | allow |
| `*.md`, `*.json`, `*.sql` | non-code file glob | allow |
| `.task/`, `node_modules/` | non-code path | allow |

**Block message example** (with both cclsp and Serena detected):
```
⛔ LSP-FIRST BLOCK: 1 code symbol(s) in Grep — use LSP instead
Symbols: handleSubmit
LSP tools:
  handleSubmit:
    mcp__cclsp__find_references("handleSubmit")  (cclsp)
    mcp__serena__find_referencing_symbols("handleSubmit")  (Serena)
```
If only one provider is installed, only that suggestion appears.

### 2. `lsp-first-glob-guard.cjs` — Glob Symbol Blocker

**Hook type:** PreToolUse | **Matcher:** `Glob`

Closes the gap where Claude searches for a symbol by *filename pattern* instead of content. Without this hook, `Glob("*UserService*")` silently returns the file, Claude reads it, and LSP enforcement never fires.

The guard parses the glob pattern, extracts alphabetic tokens, and blocks if any token looks like a code symbol (PascalCase, camelCase, or snake_case with 3+ parts). Lowercase-only tokens and short generic words are always allowed.

| Pattern | Detected as | Action |
|---------|------------|--------|
| `*UserService*` | PascalCase symbol | BLOCK |
| `**/AuthProvider.tsx` | PascalCase in path | BLOCK |
| `*createOrder*` | camelCase symbol | BLOCK |
| `*handleSubmit*` | camelCase handler | BLOCK |
| `*get_user_sessions*` | snake_case function | BLOCK |
| `src/**/*.ts` | extension pattern | allow |
| `*.tsx`, `**/*.json` | extension pattern | allow |
| `*subdomain*`, `*auth*` | lowercase concept | allow |
| `**/middleware*` | file concept | allow |
| `tsconfig.json`, `next.config.ts` | framework config | allow |
| `README.md` | docs | allow |

**Allowed by design:** lowercase concept searches (`*auth*`, `*subdomain*`) are legitimate file discovery by topic. Only symbol-shaped tokens (casing patterns) are blocked, because those should use `find_workspace_symbols` instead.

### 3. `bash-grep-block.cjs` — Shell Grep Blocker

**Hook type:** PreToolUse | **Matcher:** `Bash`

Same detection logic, but for `Bash(grep "UserService" src/)`, `Bash(rg handleSubmit)`, etc. Claude sometimes tries to bypass the Grep hook by shelling out.

Allows: `git grep` (history search), non-code paths, non-code file type filters.

### 4. `lsp-first-read-guard.cjs` — Progressive Read Gate

**Hook type:** PreToolUse | **Matcher:** `Read`

The most sophisticated hook. Forces a "navigate first, read targeted" workflow through 5 gates:

```
Gate 1 — Warmup Required
  No LSP state file → BLOCK
  Must call get_diagnostics(<any .ts file>) first

Gate 2 — Free Orientation (reads 1-2)
  ALLOW — explore freely, no restrictions

Gate 3 — Warning (read 3)
  WARN if no LSP nav calls yet
  "Next Read will be BLOCKED"

Gate 4 — Navigation Required (reads 4-5)
  BLOCK if nav_count < 1
  Must use at least 1 LSP navigation call

Gate 5 — Surgical Mode (reads 6+)
  BLOCK if nav_count < 2
  After 2 nav calls → unlimited reads forever
```

**Session flow:**
```
Session starts
  │
  ├─ Read(page.tsx) → Gate 1 BLOCKS → "warmup required"
  │
  ├─ get_diagnostics(file.ts) → tracker writes warmup_done=true
  │
  ├─ Read(page.tsx) → Gate 2 allows (1 of 2 free)
  ├─ Read(actions.ts) → Gate 2 allows (2 of 2 free)
  ├─ Read(types.ts) → Gate 3 WARNS
  ├─ Read(helpers.ts) → Gate 4 BLOCKS
  │
  ├─ find_workspace_symbols("MyFunc") → tracker: nav_count=1
  │
  ├─ Read(helpers.ts) → unlocked (reads 4-5)
  ├─ Read(utils.ts) → unlocked
  ├─ Read(service.ts) → Gate 5 BLOCKS
  │
  ├─ find_references("MyFunc") → tracker: nav_count=2
  │
  └─ SURGICAL MODE — all Reads unlimited
```

**Always allowed (no gate):**
- Non-code files: `.md`, `.json`, `.yaml`, `.env`, `.sql`, `.css`, `.html`
- Config files: `tsconfig.json`, `next.config.ts`, `package.json`
- Test files: `*.test.ts`, `*.spec.tsx`
- Non-code paths: `.task/`, `.claude/`, `node_modules/`, `__tests__/`

**Dedup:** Reading the same file at different line ranges counts as 1 Read.

### 5. `lsp-pre-delegation.cjs` — Agent Pre-Resolution

**Hook type:** PreToolUse | **Matcher:** `Agent`

Claude Code subagents **cannot access MCP tools** — this is an architectural limitation of the platform. Without this hook, every delegated agent falls back to Grep+Read, bypassing all LSP enforcement.

```
// BLOCKED — no LSP context
Agent({
  prompt: "Fix handleSubmit in the form component",
  isolation: "worktree"
})

// ALLOWED — pre-resolved LSP context
Agent({
  prompt: `Fix handleSubmit error handling.

    ## LSP CONTEXT (pre-resolved by orchestrator)
    - handleSubmit: defined at form-actions.ts:42, called from page.tsx:15
    - FormComponent: defined at form.tsx:8, used in page.tsx:120`,
  isolation: "worktree"
})
```

**Three enforcement tiers:**

| Tier | Agents | Enforcement |
|------|--------|-------------|
| Force | `frontend-explorer`, `backend-explorer`, `db-explorer` | Always BLOCK without LSP context |
| Standard | Implementation agents, worktree-isolated agents | BLOCK during implement phase |
| Exempt | Reviewers, testers, planners, auditors | Never enforced (read-only) |

### 6. `lsp-session-reset.cjs` — Stale State Wiper

**Hook type:** SessionStart | **Matcher:** `true` (runs on every session start)

The Read guard's state file (`~/.claude/state/lsp-ready-<cwd-hash>`) has a 24-hour expiry. Without this hook, a new session inherits yesterday's `nav_count` — and if that count was ≥ 2, the guard is permanently in **surgical mode** for today's session: unlimited Reads with zero LSP calls required. A full bypass of the enforcement chain.

This hook runs once on session start and deletes the state file for the current cwd. The next Read triggers Gate 1 (warmup required), forcing at least one `get_diagnostics` call before any code file can be opened. After warmup, the standard progression kicks in (Gate 2 → 3 → 4 → 5) requiring real LSP navigation calls before surgical mode unlocks.

**Session lifecycle with reset:**
```
Session start
  │
  ├─ lsp-session-reset.js → unlinks lsp-ready-<hash>
  │
  ├─ Read(page.tsx) → Gate 1 BLOCKS → "warmup required"
  │
  ├─ get_diagnostics(file.ts) → tracker writes warmup_done=true
  │
  ├─ Read × 2 (free) → Gate 3 warn → Gate 4 block → LSP nav → …
  │
  └─ (2 nav calls later) SURGICAL MODE unlocked
```

**Safety:** the hook only deletes the flag for the current cwd — other projects' state files are left alone. Failure is silent (never blocks session start).

### 7. `lsp-usage-tracker.cjs` — State Tracker

**Hook type:** PostToolUse | **Matcher:** all `mcp__cclsp__*` tools

Tracks successful LSP calls in a per-project state file. Other hooks read this state to make gate decisions.

**State file:** `~/.claude/state/lsp-ready-<md5-hash-of-cwd>`

```json
{
  "cwd": "/path/to/project",
  "warmup_done": true,
  "nav_count": 25,
  "read_count": 38,
  "read_files": ["src/page.tsx", "src/actions.ts"],
  "timestamp": 1775818285727,
  "last_tool": "mcp__cclsp__find_references"
}
```

**Cold start handling:** Detects the cclsp "No Project" error (upstream bug where `find_workspace_symbols` doesn't prime the TypeScript project). Emits a `systemMessage` with the correct fix — call a file-based tool first. It's an ordering bug, not a timing issue.

## 📦 Installation

### Prerequisites

- [Claude Code](https://code.claude.com) — CLI ≥ 2.1, Desktop app, or IDE extension
- Node.js ≥ 18 (Claude Code already requires it; nothing extra to install)
- An LSP MCP provider — at least one of:
  - [**cclsp**](https://github.com/ktnyt/cclsp) — TypeScript/JavaScript out of the box, multi-language via `cclsp.json` (see the [Python / Go / Rust](#-optional-python-go-rust-support) section)
  - [**Serena**](https://github.com/oraios/serena) — multi-language (Python, Go, Rust, Java, TS, Vue, …) via its bundled `solidlsp`
  - Anthropic's bundled `typescript-lsp` plugin works too (it ships cclsp)

### Recommended — install from the public marketplace

```text
/plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit
/plugin install lsp-enforcement-kit@claude-code-lsp-enforcement-kit
```

That's it. Claude Code clones this repo into its plugin cache, registers all seven hooks via `hooks/hooks.json`, and injects the LSP-first rule on each new session. No files are written to `~/.claude/hooks/`, and your `~/.claude/settings.json` is not modified beyond the standard `enabledPlugins` toggle.

Update to a new release: `/plugin marketplace update claude-code-lsp-enforcement-kit`.

### Local development install

When iterating on the kit itself, install from a local clone instead of GitHub:

```bash
git clone https://github.com/mmizutani/claude-code-lsp-enforcement-kit.git
cd claude-code-lsp-enforcement-kit
```

```text
/plugin marketplace add ./
/plugin install lsp-enforcement-kit@claude-code-lsp-enforcement-kit
```

Hooks reload on every Claude Code session start — edit a `.cjs`, restart, see the change.

### Disable or uninstall

```text
/plugin disable lsp-enforcement-kit@claude-code-lsp-enforcement-kit   # keep installed, suspend hooks
/plugin uninstall lsp-enforcement-kit@claude-code-lsp-enforcement-kit # remove entirely
/plugin marketplace remove claude-code-lsp-enforcement-kit             # forget the marketplace
```

### Verify

Restart Claude Code, then ask `Where is handleSubmit defined?` — Claude should use `find_definition`, not Grep. Or trigger a guard intentionally:

```
You: Run Grep("handleSubmit") on src/
Claude: ⛔ LSP-FIRST BLOCK — code symbols in Grep, use mcp__cclsp__find_references("handleSubmit") instead
```

Inspect the full install (recommended one-liner):

```bash
bash ~/.claude/plugins/cache/claude-code-lsp-enforcement-kit/lsp-enforcement-kit/*/scripts/lsp-status.sh
```

This checks: plugin cache present → enabledPlugins entry → all 8 hook scripts intact → shared helper resolves → at least one LSP MCP provider detected → current-cwd runtime state. Exits non-zero if anything is off, with the exact command to fix it.

Or peek at the raw runtime state for the cwd you're in:

```bash
ls ~/.claude/state/lsp-ready-*    # one flag file per cwd you've worked in
cat ~/.claude/state/lsp-ready-*   # warmup_done, nav_count, read_count, last_tool
```

## 📚 LSP Tool Reference

| Tool | Question It Answers | Output |
|------|-------------------|--------|
| `find_definition` | Where is X defined? | file:line of definition |
| `find_references` | Where is X used? | All file:line usages |
| `find_workspace_symbols` | Find anything named X | All matching symbols in project |
| `find_implementation` | What implements this interface? | Concrete implementations |
| `get_incoming_calls` | What calls X? | All callers with file:line |
| `get_outgoing_calls` | What does X call? | All callees with file:line |
| `get_hover` | What type is X? | Type signature + docs |
| `get_diagnostics` | Any errors in this file? | TypeScript errors/warnings |

## 🐍 Optional: Python, Go, Rust Support

The built-in plugin only covers TypeScript/JavaScript. For other languages, install `cclsp` — a standalone MCP server that connects Claude Code to any Language Server:

```bash
npm install -g cclsp
```

Then install the language server for your language:

```bash
# Python
pip install python-lsp-server

# Go
go install golang.org/x/tools/gopls@latest

# Rust
rustup component add rust-analyzer
```

Create `~/.config/claude/cclsp.json`:

```json
{
  "servers": [
    {
      "extensions": ["py", "pyi"],
      "command": ["pylsp"]
    },
    {
      "extensions": ["go"],
      "command": ["gopls", "serve"]
    },
    {
      "extensions": ["rs"],
      "command": ["rust-analyzer"]
    }
  ]
}
```

Add to your Claude Code MCP config (`~/.claude.json`):

```json
{
  "mcpServers": {
    "cclsp": {
      "type": "stdio",
      "command": "cclsp",
      "args": []
    }
  }
}
```

The hooks work identically — they detect code symbols by naming convention, not by language. Once `cclsp` is connected, `find_definition`, `find_references`, etc. work across all configured languages.

## ❓ FAQ

**Q: Does this work with Python/Go/Rust?**
Out of the box — TypeScript/JavaScript only (built-in plugin). For other languages, install `cclsp` + the language server (see section above). The hooks themselves are language-agnostic.

**Q: What if LSP gives wrong results?**
The hooks don't eliminate Grep — they block Grep for *code symbols*. If LSP returns empty, Claude can still Grep with non-symbol patterns or search non-code files. The Read guard also gives 2 free reads before requiring navigation.

**Q: Won't the Read gate slow down simple tasks?**
After 2 LSP navigation calls, all gates open permanently (surgical mode). This happens within the first 30 seconds of a session. Non-code files (config, tests, docs) are never gated.

**Q: Why block Agent delegation without LSP context?**
Claude Code subagents cannot access MCP tools (architectural limitation). Without pre-resolved context, every delegated agent falls back to exploratory Grep+Read, burning thousands of tokens and bypassing all enforcement.

**Q: Known issues?**
`find_workspace_symbols` fails with "No Project" if called before any file-based LSP tool (cclsp upstream bug). The tracker detects this and tells Claude to call `get_diagnostics` first. Not a timing issue — ordering issue.

**Q: I installed v1 / v2 via `install.sh` and shared it with my team — should I upgrade?**
Yes. v3 ships the kit as a Claude Code plugin and supersedes the shell installer. Have each teammate remove the old hook entries from `~/.claude/settings.json` (or delete `~/.claude/hooks/lsp-*`) and then run `/plugin marketplace add mmizutani/claude-code-lsp-enforcement-kit` + `/plugin install lsp-enforcement-kit@claude-code-lsp-enforcement-kit`. The enforcement contract is unchanged — only the install mechanism switched.

**Q: Does this work with Serena?**
Yes. Since **v2.1**, the kit detects your LSP MCP provider and tailors its block-message suggestions. If you run [Serena](https://github.com/oraios/serena) (the multi-language MCP symbol toolkit by Oraios AI — MIT), the hooks will point you at `mcp__serena__find_symbol`, `find_referencing_symbols`, and `get_symbols_overview` instead of cclsp tools. The enforcement logic (Grep/Glob/Read/Agent gates, session reset) is provider-agnostic — it works the same for both. You can also run cclsp and Serena side-by-side; suggestions then show both.

This is pure interop — the kit ships no Serena code, uses only their public tool names in suggestion strings, and reads only your own config to detect which provider is active.

**Q: What about Python/Go/Rust? cclsp is TypeScript-only.**
Two options:
1. Install a standalone `cclsp` MCP server with multi-language config (see the "Optional" section above), OR
2. Install [Serena](https://github.com/oraios/serena) — it bundles `solidlsp`, a unified wrapper around language servers for Python, Go, Rust, Java, TypeScript, Vue, PHP, Ruby, Swift, Elixir, Clojure, Bash, PowerShell, and more. The kit will detect Serena automatically and adapt its suggestions.

The hook detection logic itself is language-agnostic — it works on naming conventions (PascalCase, camelCase, snake_case), not language-specific ASTs.

## 📄 License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  Made for Claude Code power users who care about token efficiency.
  <br>
  <a href="https://github.com/mmizutani/claude-code-lsp-enforcement-kit/issues">Report an issue</a> &bull;
  <a href="https://github.com/mmizutani/claude-code-lsp-enforcement-kit/releases">Releases</a> &bull;
  <a href="CHANGELOG.md">Changelog</a>
</p>
