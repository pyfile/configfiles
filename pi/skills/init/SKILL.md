---
name: init
description: 'Create or improve an AGENTS.md for the project. Use when the user asks to initialize the project, set up guidance for coding agents, mentions the opencode /init workflow, or needs a new or updated AGENTS.md — including when nested child and parent AGENTS.md files coexist and a scope must be chosen. Explicit-only command, not loaded automatically.'
disable-model-invocation: true
---

# Init — create or update `AGENTS.md`

Create or update `AGENTS.md` for this repository. This is a port of the opencode `/init` command. See `references/initialize.txt` for the original opencode prompt this skill is based on.

The goal is a compact instruction file that helps future OpenCode/Pi sessions avoid mistakes and ramp up quickly. Every line should answer: "Would an agent likely miss this without help?" If not, leave it out.

User-provided focus or constraints (honor these — everything after `/skill:init`):

## Choose scope and target before anything else

Before investigating or writing, locate existing `AGENTS.md` files:

1. Does the current working directory contain `AGENTS.md`?
2. Walk up through the ancestors (bounded by the repository root — see "Where to write" for how to find it) and collect every level that contains `AGENTS.md`, with its path.

Rules:

- If no `AGENTS.md` exists at the current directory or any ancestor, do not ask; use the default target from "Where to write".
- If an ancestor `AGENTS.md` exists, ask ONE `ask_user_question` batch (two questions, per the cases below) **before** running the investigation, so the analysis reads the right directory. Put the actual detected paths in the option labels so levels are distinguishable. The two answers are normally the same directory, but combinations like "analyze the current subtree but write into the parent file" are allowed if the user picks that.

### Case A — current dir and ancestor(s) both have `AGENTS.md`

In one batch:

1. **Which directory subtree should I recursively analyze** (READMEs, configs, manifests, representative source)?
   - current directory subtree
   - ancestor subtree — one option per detected level, nearest first (paths in labels)
   - both levels (merge findings)

2. **Which `AGENTS.md` should I supplement?**
   - `AGENTS.md` in the current directory
   - ancestor `AGENTS.md` — one option per detected level

### Case B — current dir has no `AGENTS.md`, but an ancestor has one

In one batch:

1. **Which directory subtree should I recursively analyze?**
   - current directory subtree
   - ancestor subtree — one option per detected level
   - both levels (merge findings)

2. **Where should I write the result?**
   - create a new `AGENTS.md` in the current directory
   - supplement the ancestor `AGENTS.md` — one option per detected level

Honor the answers exactly: analyze only inside the chosen scope directory, and write only to the chosen target. If the user types a custom answer instead, follow that.

## Where to write

- If a target was chosen above, write there: the chosen existing file (improved in place), or the new `<cwd>/AGENTS.md` when the user chose to create one.
- Otherwise (no `AGENTS.md` at the current directory or any ancestor), determine the repository root:
  1. Run `git rev-parse --show-toplevel` in the working directory. If it succeeds, the root is that directory.
  2. If not a git repo, walk up from the current directory to the deepest ancestor that looks like a project root (contains a manifest/metadata file such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `Gemfile`, `pubspec.yaml`, or similar).

  Write to `<repository-root>/AGENTS.md`.

This file is exactly the instruction file Pi discovers and loads automatically (walking up from the working directory through ancestors), so after you write or improve it, it applies to future sessions in this repo with no further configuration.

## How to investigate

Investigate inside the scope directory chosen above (or the repository root when no scope was chosen). Read the highest-value sources first within that scope:

- `README*`, root manifests, workspace config, lockfiles
- build, test, lint, formatter, typecheck, and codegen config
- CI workflows and pre-commit / task runner config
- existing instruction files (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`)
- repo-local agent config such as `opencode.json`, `.pi/settings.json` (if present)

If architecture is still unclear after reading config and docs, inspect a small number of representative code files to find the real entrypoints, package boundaries, and execution flow. Prefer reading the files that explain how the system is wired together over random leaf files.

Prefer executable sources of truth over prose. If docs conflict with config or scripts, trust the executable source and only keep what you can verify.

## What to extract

Look for the highest-signal facts for an agent working in this scope:

- exact developer commands, especially non-obvious ones
- how to run a single test, a single package, or a focused verification step
- required command order when it matters, such as `lint -> typecheck -> test`
- monorepo or multi-package boundaries, ownership of major directories, and the real app/library entrypoints
- framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading, dev servers, infra deploy flow
- testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services, flaky or expensive suites
- important constraints from existing instruction files worth preserving

Good `AGENTS.md` content is usually hard-earned context that took reading multiple files to infer.

## Questions

The scope/target batch above comes first. After investigating, only ask the user more questions if the repo cannot answer something important (one short batch at most):

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

Prefer short sections and bullets. If the scope is simple, keep the file simple. If the scope is large, summarize the few structural facts that actually change how an agent should work.

If the chosen target file already exists, improve it in place rather than rewriting blindly. Preserve verified useful guidance, delete fluff or stale claims, and reconcile it with the current codebase.

Nested files: if the result coexists with an ancestor `AGENTS.md` (created new in the current dir, or kept alongside the parent's), keep the lower file a focused delta — only facts specific to this subtree — and do not duplicate what the ancestor file already covers. Pi loads the whole ancestor chain automatically, so the files are merged from the working directory upward.