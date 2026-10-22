## Web search routing (mandatory)

Any task requiring fresh web information must be delegated. Do NOT call
`web_search`, `web_search_enhanced`, or `fetch_content` directly.

### Route selection

| Task nature | Use |
| :--- | :--- |
| Facts already exist in sources; only need reporting. Single facts, versions, prices, dates, claim verification, news roundups, source lists, display of coverage. | `websearcher` |
| Answer must be **constructed**: comparison/trade-offs, surveys/syntheses, conflicting-account adjudication, aggregating perspectives into a judgment no single source states. | `websearcher_max` |

Breadth alone is never a reason to escalate. A search returning twenty sources
is still `websearcher` if each item is merely reported.

### Spawn syntax

```text
subagent({ subagent_type: "websearcher", prompt: "<the exact question>", description: "<short label>" })
subagent({ subagent_type: "websearcher_max", prompt: "<the exact question>", description: "<short label>" })
```

## Lightweight Verification Policy

Default: do not write or run smoke tests. Do not scaffold test harnesses, start servers, browsers, databases, or external services for routine validation.

Validation order:
1. Run deterministic static/syntax checks first (compile, type-check, lint). These cost no model tokens.
2. If behavior changed, add at most one minimal assertion for the changed core function. No fixtures, no end-to-end setup.
3. Run integration/E2E tests only when the user explicitly asks, or when the change crosses a service boundary.

When tests fail, classify first:
- Environment/dependency/network issue: handle deterministically with retry or install; do not invoke LLM reasoning.
- Genuine logic failure: summarize only the precise error back to the model.

If the user states they trust code generation, skip tests beyond static checks unless a concrete risk requires one targeted assertion. Prefer minimal diffs and no test scaffolding.
