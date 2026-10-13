---
name: init
description: 'Create or improve an AGENTS.md for the project, running entirely through the codemode tool. Use when the user asks to initialize the project, set up guidance for coding agents, mentions the opencode /init workflow, or needs a new or updated AGENTS.md — including when nested child and parent AGENTS.md files coexist and a scope must be chosen. Explicit-only command, not loaded automatically.'
disable-model-invocation: true
---

# Init — create or update `AGENTS.md` (codemode-driven)

Port of the opencode `/init` command; see `references/initialize.txt` for the original prompt this skill is based on. The goal is a compact instruction file that helps future Pi sessions avoid mistakes and ramp up quickly. Every line should answer: "Would an agent likely miss this without help?" If not, leave it out.

User-provided focus or constraints: honor these (everything after `/skill:init`).

## Codemode-only execution

This skill runs entirely through the `codemode` tool:

- **All investigation tool calls** (`read`, `bash`, `find`, `grep`, …) happen inside codemode scripts. Do not call them directly while running this skill.
- **Scripts return only compact reports** (structured text), never raw file dumps, so the model's context stays small.
- **The only direct tool call is the final `write`** of the composed `AGENTS.md` — authoring the content is model judgment, and embedding hand-written markdown inside a script string is fragile. Everything else (scope detection, questions, investigation, fact-gathering) is script work.
- Requires `codemode` to be enabled in the session. If the `codemode` tool is unavailable, stop and ask the user to enable it (`defaultTools: ["+codemode"]` in settings, or `pi --tools +codemode`).
- Works with the default `codemode.mode: "on"` (the direct tools are still declared — ignore them and use scripts). With `codemode.mode: "only"` the direct tools are hidden, which enforces the same rule automatically.

## Workflow — one script, one compose, one write

1. **Investigate — ONE codemode script.** Adapt `references/codemode-investigate.md` to the repo. In order: find the repository root; detect the AGENTS.md chain; ask the scope/target questions inside the script (only when an ancestor `AGENTS.md` exists); investigate only the chosen scope; return the compact report (fields listed below).
2. **Compose — model judgment.** Decide the `AGENTS.md` content from the report, following "Writing rules". If the target exists, improve it in place using the existing content the report includes.
3. **Write — direct `write` call.** Persist the composed content to the resolved target path from the report.

If the script fails or a fact is missing, fix the script and rerun instead of falling back to direct reading. Small follow-up scripts are allowed, but prefer getting it right in the one script.

## Step 1 — Investigate (codemode script)

Follow `references/codemode-investigate.md`, adapting it to the repo. It must:

1. **Find the repository root:**
   - `git rev-parse --show-toplevel` via `bash`. If it succeeds, use that.
   - Otherwise walk up from the working directory to the nearest ancestor that looks like a project root (contains a manifest such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `Gemfile`, `pubspec.yaml`); fall back to the working directory.

2. **Detect the AGENTS.md chain:** does the current directory contain `AGENTS.md`? Also walk up through the ancestors (bounded by the repository root) and collect every level that does, nearest first.

3. **Ask scope/target — only when an ancestor `AGENTS.md` exists.** Ask inside the same script via `tools.ask_user_question(...)`, ONE batch of two questions, per the cases below. Compute the levels from detection; put the detected level (e.g. `ancestor #2`) and, when short, the path in the option labels so levels are distinguishable. Honor the answers exactly.
   - **Case A** — current dir and ancestor(s) both have `AGENTS.md`: (1) which subtree to recursively analyze (current subtree / ancestor subtree, one option per detected level / both levels merged); (2) which `AGENTS.md` to supplement (current / ancestor, one option per level).
   - **Case B** — current dir has none, an ancestor has one: (1) which subtree to analyze (current / ancestor, one per level / both); (2) where to write (create a new `AGENTS.md` in the current dir / supplement an ancestor, one per level).
   - If no `AGENTS.md` exists at the current dir or any ancestor: do not ask; target defaults to "Where to write" below.
   - If the user presses Esc or types a custom answer, mark the answer as unresolved in the report and honor the custom answer when composing (choose the write path by what the user typed).
   - Parse the returned string: the chosen labels appear verbatim; use the level markers to find the chosen path. If parsing fails, fall back to current-dir scope and include the raw answer text in the report.

4. **Investigate only inside the chosen scope** (or the repository root when scope was not asked). Highest-value sources first:
   - `README*`, root manifests, workspace config, lockfiles (note the package manager + lockfile presence; never dump lockfile contents)
   - build, test, lint, formatter, typecheck, and codegen config
   - CI workflows and pre-commit / task runner config
   - existing instruction files (`AGENTS.md` chain, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`)
   - repo-local agent config such as `opencode.json` and `.pi/settings.json`
   - if architecture is still unclear, a small number of representative code files (entrypoints, package boundaries) — never random leaf files
   - Prefer executable sources of truth over prose: trust config and scripts on conflict.
   - Batch reads with `Promise.allSettled`/`Promise.all`; tolerate individual failures (partial results are fine); keep total targeted reads around ≤ 15 unless the repo needs more.

5. **Extract facts** per "What to extract", plus:
   - the existing content of the chosen target (for in-place improvement), and the other `AGENTS.md` files in the chain (for the nested-delta rule) — truncated with a note when huge,
   - any open questions the repo cannot answer (for the "Questions" step).

6. **Return the compact report** in the format below (template in the reference). Cap each fact at 1–2 lines; no raw file bodies.

### Report format (return one `text(...)` block)

```text
REPO_ROOT=…
CWD=…
AGENTS_CHAIN=[…]            # absolute paths, nearest first
QUESTION_ANSWER=…           # verbatim; "(none)" when no question was asked; UNRESOLVED flag if not parsed
ANSWER_PARSE=ok|unresolved
SCOPE_DIRS=[…]              # directories actually analyzed
TARGET=…                    # absolute path the skill should write to
TARGET_EXISTING=…           # current content (truncated) or "(none)"
AGENTS_CONTENT[<path>]=…    # other chain AGENTS.md contents (for the nested-delta rule)
FACTS:
- [README] …
- [package.json] scripts=…; packageManager=…
- [Makefile] targets: …
- …
OPEN_QUESTIONS=[…]          # repo facts the repo itself cannot answer
```

## Questions (undocumented conventions)

Only ask when the repo cannot answer something important — one short batch at most, via `tools.ask_user_question` (ask it inside a follow-up codemode script, grouped with anything else you need):

- undocumented team conventions
- branch / PR / release expectations
- missing setup or test prerequisites that are known but not written down

Do not ask about anything the repo already makes clear.

## Where to write

- If the target was chosen in Step 1: write there — the chosen existing file (improve in place), or `<cwd>/AGENTS.md` when the user chose to create one. A custom answer is honored as typed.
- Otherwise (no `AGENTS.md` at the current directory or any ancestor): `<repository-root>/AGENTS.md` from Step 1.1 (git root, or the nearest manifest-bearing ancestor).
- After it is written, Pi discovers it automatically in future sessions in this repo (walking up from the working directory), so no further configuration is needed.

## What to extract

Look for the highest-signal facts for an agent working in this scope:

- exact developer commands, especially non-obvious ones
- how to run a single test, a single package, or a focused verification step
- required command order when it matters, such as `lint -> typecheck -> test`
- monorepo or multi-package boundaries, ownership of major directories, and the real app/library entrypoints
- framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading, dev servers, infra deploy flow
- testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services, flaky or expensive suites
- important constraints from existing instruction files worth preserving

Good `AGENTS.md` content is usually hard-earned context that took reading multiple files to infer — the report should make those facts explicit.

## Writing rules

Include only high-signal, repo-specific guidance:

- exact commands and shortcuts the agent would otherwise guess wrong
- architecture notes that are not obvious from filenames
- conventions that differ from language or framework defaults
- setup requirements, environment quirks, and operational gotchas
- references to existing instruction sources that matter

Exclude:

- generic software advice
- long tutorials or exhaustive file trees
- obvious language conventions
- speculative claims or anything you could not verify
- content better stored in another file referenced via config `instructions`

When in doubt, omit. Prefer short sections and bullets. If the scope is simple, keep the file simple. If the scope is large, summarize the few structural facts that actually change how an agent should work.

If the chosen target file already exists, improve it in place rather than rewriting blindly: preserve verified useful guidance, delete fluff or stale claims, and reconcile with the current codebase (the report includes the current content).

Nested files: if the result coexists with an ancestor `AGENTS.md` (created new in the current dir, or kept alongside the parent's), keep the lower file a focused delta — only facts specific to this subtree — and do not duplicate what the ancestor file already covers. Pi loads the whole ancestor chain automatically, so the files are merged from the working directory upward.