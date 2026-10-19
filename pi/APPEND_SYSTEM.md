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
