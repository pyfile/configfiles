---
name: init
description: 'Create or improve the repository root AGENTS.md. Use when the user asks to initialize the project, set up guidance for coding agents, mentions the opencode /init workflow, or needs a new or updated AGENTS.md. Explicit-only command, not loaded automatically.'
disable-model-invocation: true
---

# Init — create or update `AGENTS.md`

Create or update `AGENTS.md` for this repository. This is a port of the opencode `/init` command. See `references/initialize.txt` for the original opencode prompt this skill is based on.

The goal is a compact instruction file that helps future OpenCode/Pi sessions avoid mistakes and ramp up quickly. Every line should answer: "Would an agent likely miss this without help?" If not, leave it out.

User-provided focus or constraints (honor these — everything after `/skill:init`):

## Where to write

Determine the repository root:

1. Run `git rev-parse --show-toplevel` in the working directory. If it succeeds, the root is that directory.
2. If not a git repo, walk up from the current directory to the deepest ancestor that looks like a project root (contains a manifest/metadata file such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `Gemfile`, `pubspec.yaml`, or similar).

Write to `<repository-root>/AGENTS.md`. This file is exactly the instruction file Pi discovers and loads automatically (walking up from the working directory through ancestors), so after you write or improve it, it applies to future sessions in this repo with no further configuration.

## How to investigate

Read the highest-value sources first:

- `README*`, root manifests, workspace config, lockfiles
- build, test, lint, formatter, typecheck, and codegen config
- CI workflows and pre-commit / task runner config
- existing instruction files (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`)
- repo-local agent config such as `opencode.json`, `.pi/settings.json` (if present)

If architecture is still unclear after reading config and docs, inspect a small number of representative code files to find the real entrypoints, package boundaries, and execution flow. Prefer reading the files that explain how the system is wired together over random leaf files.

Prefer executable sources of truth over prose. If docs conflict with config or scripts, trust the executable source and only keep what you can verify.

## What to extract

Look for the highest-signal facts for an agent working in this repo:

- exact developer commands, especially non-obvious ones
- how to run a single test, a single package, or a focused verification step
- required command order when it matters, such as `lint -> typecheck -> test`
- monorepo or multi-package boundaries, ownership of major directories, and the real app/library entrypoints
- framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading, dev servers, infra deploy flow
- testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services, flaky or expensive suites
- important constraints from existing instruction files worth preserving

Good `AGENTS.md` content is usually hard-earned context that took reading multiple files to infer.

## Questions

Only ask the user questions if the repo cannot answer something important. Use the `ask_user_question` tool for one short batch at most.

Good questions:

- undocumented team conventions
- branch / PR / release expectations
- missing setup or test prerequisites that are known but not written down

Do not ask about anything the repo already makes clear.

## Writing rules

Include only high-signal, repo-specific guidance such as:

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

When in doubt, omit.

Prefer short sections and bullets. If the repo is simple, keep the file simple. If the repo is large, summarize the few structural facts that actually change how an agent should work.

If `AGENTS.md` already exists at the repository root, improve it in place rather than rewriting blindly. Preserve verified useful guidance, delete fluff or stale claims, and reconcile it with the current codebase.