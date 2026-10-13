# Codemode investigate template (for the init skill)

Run this as the body of **one** `codemode` call. Adapt it to the repo — adjust candidate file lists, read caps, and extraction rules. Keep the mandates from `SKILL.md`: ask the scope/target questions inside the script, investigate only the chosen scope, and return a compact report that includes the existing target content.

> Requirements: `codemode` enabled in the session. Works with the default `codemode.mode: "on"` (ignore the declared direct tools); `codemode.mode: "only"` hides the direct tools, which is ideal here.

```js
// @options: {"max_output_tokens": 20000, "timeout_ms": 300000}

// ---------- helpers ----------
const bash = async (command) => {
  const r = await tools.bash({ command });
  return { ok: r.exit_code === 0, out: (r.output ?? "").trim() };
};
const read = async (p) => { try { return await tools.read({ path: p }); } catch { return null; } };
const q = (s) => "'" + s.replace(/'/g, "'\\''") + "'";     // bash single-quote a path
const cap = (s, n) => (s == null ? "" : s.length > n ? s.slice(0, n) + "\n… [truncated]" : s);

let reportLines = [];
const add = (line) => reportLines.push(String(line));

async function main() {
  // ---------- 1. repository root ----------
  const cwd = (await bash("pwd")).out;
  let root = "";
  {
    const r = await bash("git rev-parse --show-toplevel 2>/dev/null");
    if (r.ok) root = r.out;
  }
  if (!root) {
    const manifests = ["package.json","pyproject.toml","go.mod","Cargo.toml","composer.json","Gemfile","pubspec.yaml","pnpm-workspace.yaml","setup.py","CMakeLists.txt"];
    // nearest ancestor from cwd upward that holds a manifest; cwd counts
    const r = await bash(`
      d="$(pwd)"; found="";
      while :; do
        for m in ${manifests.join(" ")}; do
          if [ -f "$d/$m" ]; then found="$d"; break; fi
        done
        [ -n "$found" ] && break
        [ "$d" = "/" ] && break
        d="$(dirname "$d")"
      done
      printf '%s' "$found"
    `);
    root = r.out || cwd;
  }

  // ---------- 2. AGENTS.md chain (nearest first, bounded by root) ----------
  const chain = [];
  {
    const r = await bash(`
      R=$(printf %q ${q(root)})
      d="$(pwd)"
      while :; do
        if [ -f "$d/AGENTS.md" ]; then printf '%s\\n' "$d"; fi
        [ "$d" = "$R" ] && break
        d="$(dirname "$d")"
      done
    `);
    chain.push(...r.out.split("\n").filter(Boolean));
  }
  const ancestors = chain.filter((p) => p !== cwd);

  // ---------- 3. scope/target questions (only when an ancestor has AGENTS.md) ----------
  let answerText = "(none)";
  let targetPath = (root || cwd) + "/AGENTS.md";
  let scopeDirs = [root || cwd];
  let parseNote = "no question";
  const levelLabel = (p, i) => "ancestor #" + i + " (" + ((p.split("/").filter(Boolean).pop() || p).slice(0, 24)) + ")";

  if (ancestors.length > 0) {
    const hasCwdAgent = chain.includes(cwd);
    const scopeOpts = [
      { label: "current dir subtree", description: "Analyze " + cwd + " only." },
      ...ancestors.map((p, i) => ({ label: levelLabel(p, i + 1) + " subtree", description: "Analyze " + p + "." })),
      { label: "both levels (merge findings)", description: "Analyze " + cwd + " and: " + ancestors.join(", ") },
    ];
    const targetOpts = hasCwdAgent
      ? [
          { label: "AGENTS.md in current dir", description: "Supplement " + cwd + "/AGENTS.md." },
          ...ancestors.map((p, i) => ({ label: levelLabel(p, i + 1) + "/AGENTS.md", description: "Supplement " + p + "/AGENTS.md." })),
        ]
      : [
          { label: "create new AGENTS.md here", description: "Create " + cwd + "/AGENTS.md." },
          ...ancestors.map((p, i) => ({ label: "supplement " + levelLabel(p, i + 1) + " AGENTS.md", description: "Supplement " + p + "/AGENTS.md." })),
        ];
    add("SCOPE_GUESS_BEFORE_QUESTION=" + JSON.stringify(scopeDirs));
    try {
      answerText = await tools.ask_user_question({
        questions: [
          { header: "Analyze scope", question: "Which directory subtree should I recursively analyze?", options: scopeOpts },
          { header: "Write target", question: hasCwdAgent ? "Which AGENTS.md should I supplement?" : "Where should I write the result?", options: targetOpts },
        ],
      });
    } catch {
      answerText = "(abandoned by user — UNRESOLVED)";
    }

    // Parse the verbatim answer string. The chosen labels appear in it; ancestor labels
    // carry a level marker `ancestor #N` so we can map back to the absolute path.
    const ancNums = [...answerText.matchAll(/ancestor #(\d+)/g)].map((m) => Number(m[1]));
    const both = /\bboth\b/i.test(answerText);
    if (both) {
      scopeDirs = [cwd, ...ancestors];
      parseNote = "both levels";
    } else if (ancNums.length > 0) {
      scopeDirs = [ancestors[ancNums[0] - 1]].filter(Boolean);
      if (scopeDirs.length === 0) scopeDirs = [cwd];
      parseNote = "ancestor #" + ancNums[0];
    } else if (/current dir subtree/.test(answerText)) {
      scopeDirs = [cwd];
      parseNote = "current dir";
    } else {
      scopeDirs = [cwd];
      parseNote = "unresolved";
    }

    const createNew = /create new AGENTS\.md here/.test(answerText);
    const customPath = answerText.match(/(?:^|[\s"'])(\/[^\s"']*AGENTS\.md)/);
    if (createNew) {
      targetPath = cwd + "/AGENTS.md";
    } else if (ancNums.length > 1) {
      // the second `ancestor #N` marker came from the target question
      targetPath = (ancestors[ancNums[1] - 1] || cwd) + "/AGENTS.md";
    } else if (customPath) {
      targetPath = customPath[1];
    } else if (/supplement|AGENTS\.md/.test(answerText) && ancNums.length === 1) {
      targetPath = (ancestors[ancNums[0] - 1] || cwd) + "/AGENTS.md";
    } else {
      targetPath = cwd + "/AGENTS.md";
      parseNote = parseNote === "ok" ? "unresolved" : parseNote;
    }
    if (parseNote === "current dir" || parseNote === "unresolved") {
      add("ANSWER_PARSE_FLAG=check the raw QUESTION_ANSWER below before composing");
    }
  }

  add("REPO_ROOT=" + root);
  add("CWD=" + cwd);
  add("AGENTS_CHAIN=" + JSON.stringify(chain));
  add("QUESTION_ANSWER=" + answerText);
  add("ANSWER_PARSE=" + parseNote);
  add("SCOPE_DIRS=" + JSON.stringify(scopeDirs));
  add("TARGET=" + targetPath);

  // ---------- 4. investigate only the chosen scope(s) ----------
  const FACTS = [];
  let sawAnyPackage = false, sawTest = false, sawCi = false, sawLint = false;

  const extract = async (path, label) => {
    const txt = await read(path);
    if (txt == null) return;
    const base = path.split("/").pop();
    if (base === "package.json") {
      sawAnyPackage = true;
      try {
        const j = JSON.parse(txt);
        const parts = [];
        if (j.scripts) { parts.push("scripts=" + JSON.stringify(j.scripts)); sawTest ||= Object.keys(j.scripts).some((s) => s === "test" || s.startsWith("test:")); sawLint ||= Object.keys(j.scripts).some((s) => /^lint|^format/.test(s)); }
        if (j.packageManager) parts.push("packageManager=" + j.packageManager);
        if (j.workspaces) parts.push("workspaces=" + JSON.stringify(j.workspaces));
        if (j.engines) parts.push("engines=" + JSON.stringify(j.engines));
        if (parts.length) FACTS.push({ t: label, f: parts.join("; ") });
        else FACTS.push({ t: label, f: "(no scripts/packageManager evident)" });
      } catch { FACTS.push({ t: label, f: "unparsable: " + cap(txt, 200) }); }
    } else if (base === "Makefile") {
      const m = txt.match(/^[A-Za-z0-9_.\/-]+ *:/gm);
      FACTS.push({ t: label, f: m ? "targets: " + m.map((x) => x.replace(/\s*:$/, "").trim()).join("  ") : "(no targets matched)" });
    } else if (base === "justfile" || base === "Taskfile.yml" || base === "Taskfile.yaml") {
      const m = txt.split("\n").map((l) => l.replace(/:.*$/, "").trim()).filter((l) => /^[A-Za-z0-9_-]+$/.test(l)).slice(0, 25);
      FACTS.push({ t: label, f: "targets: " + m.join("  ") });
    } else if (/\.ya?ml$/.test(base) && /workflow/.test(path)) {
      sawCi = true;
      const lines = txt.split("\n").map((l) => l.trim()).filter((l) => /^(run:|working-directory:|name:|on:|if:)/.test(l)).slice(0, 60);
      FACTS.push({ t: label, f: "\n" + lines.join("\n") });
    } else if (/lock$|lock\.json$|\.lock/.test(base)) {
      FACTS.push({ t: label, f: "present; contents skipped" });
    } else if (base === "AGENTS.md" || base === "CLAUDE.md" || base === ".cursorrules" || path.includes("/.cursor/rules/")) {
      FACTS.push({ t: label, f: "\n" + cap(txt, 2000) });
    } else if (base === "opencode.json" || /\.pi\/settings\.json$/.test(path)) {
      FACTS.push({ t: label, f: cap(txt, 800) });
    } else if (/README/i.test(base)) {
      FACTS.push({ t: label, f: cap(txt.replace(/\s+/g, " "), 600) });
    } else {
      FACTS.push({ t: label, f: cap(txt.replace(/\s+/g, " "), 500) });
    }
  };

  const seen = new Set();
  const candidates = [];
  const CANDIDATE_NAMES = [
    "README.md", "README", "README.txt", "package.json", "pnpm-workspace.yaml",
    "tsconfig.json", "jsconfig.json", "vite.config.ts", "next.config.js", "astro.config.mjs", "webpack.config.js",
    "pyproject.toml", "requirements.txt", "setup.py", "go.mod", "Cargo.toml", "composer.json", "Gemfile", "pubspec.yaml",
    "Makefile", "justfile", "Taskfile.yml", "Dockerfile", "docker-compose.yml",
    ".cursorrules", "CLAUDE.md", "opencode.json", ".pi/settings.json", "AGENTS.md",
  ];
  for (const dir of scopeDirs) {
    for (const n of CANDIDATE_NAMES) candidates.push({ path: dir + "/" + n, label: n });
    const ls = await bash("ls -a " + q(dir));
    if (ls.ok) {
      for (const name of ls.out.split("\n").filter(Boolean)) {
        if (/^README/i.test(name) && !/[.](md|txt|rst)$/.test(name)) {} // README w/o extension handled below
        else if (name.startsWith(".") && /README/i.test(name)) candidates.push({ path: dir + "/" + name, label: name });
      }
    }
    const wf = await bash(`find ${q(dir)} -maxdepth 5 -type f \\( -path '*/workflows/*.yml' -o -path '*/workflows/*.yaml' -o -path '*/.cursor/rules/*.md' \\) 2>/dev/null | grep -v /node_modules/ | head -20`);
    if (wf.ok && wf.out) {
      for (const p of wf.out.split("\n").filter(Boolean)) candidates.push({ path: p, label: p.replace(dir + "/", "") });
    }
  }
  // dedupe exact paths
  for (const c of candidates) if (!seen.has(c.path)) { seen.add(c.path); }
  const uniq = [...seen].map((p) => candidates.find((c) => c.path === p));

  await Promise.allSettled(uniq.slice(0, 40).map((c) => extract(c.path, c.label)));

  // ---------- 5. existing target content (for in-place improvement) + chain contents ----------
  const existing = targetPath ? cap(await read(targetPath), 6000) : "(none)";
  add("TARGET_EXISTING=" + (existing == null || existing === "" ? "(none)" : existing));
  for (const a of chain) {
    if (a === targetPath) continue;
    const c = cap(await read(a + "/AGENTS.md"), 3000);
    add("AGENTS_CONTENT[" + a + "]=" + (c == null || c === "" ? "(none)" : c));
  }

  // ---------- 6. open questions the repo cannot answer ----------
  const OPEN = [];
  if (sawAnyPackage && !sawTest) OPEN.push("no `test` script found in package.json — how should an agent run tests?");
  if (sawAnyPackage && !sawLint) OPEN.push("no lint script found — is there a linter?");
  if (!sawCi) OPEN.push("no CI workflow found — where are the checks run?");
  add("OPEN_QUESTIONS=" + JSON.stringify(OPEN));

  // ---------- report ----------
  add("FACTS:");
  for (const f of FACTS) add("- [" + f.t + "] " + f.f);
  text(reportLines.join("\n"));
}

// IMPORTANT: the script body is itself an async function. Use TOP-LEVEL await
// (with try/catch) to drive main — an unawaited `main().catch(...)` is a discarded
// promise: the sandbox ends the script when the synchronous part finishes, so
// everything after main's first `await` would silently never run.
try {
  await main();
} catch (e) {
  text("SCRIPT ERROR: " + String(e && e.message ? e.message : e));
  text(reportLines.join("\n"));
}
```

## Notes on adapting

- **Drive `main` with top-level `await`.** The script body is an async function, so `await main()` works; an unawaited `main().catch(...)` becomes a discarded promise (the sandbox ends the script when the synchronous part returns) and every line after `main`'s first `await` is silently dropped. The template already does this correctly.
- The **`extract`** function is the place to make the report high-signal. Narrow it to the facts that actually change how an agent works, not a dump of every file.
- Cap totals keep the report small: `uniq.slice(0, 40)`, `cap(..., 6000)` for the target, `cap(..., 3000)` for chain files, 1–2 lines per fact.
- If the chosen scope is deep or huge, raise `max_output_tokens` (e.g. `{"max_output_tokens": 40000}`) rather than dropping facts the model needs.
- The bash snippets were validated: git-root fallback, manifest walk-up, AGENTS.md chain walk (nearest-first), and workflow discovery all run correctly in the sandbox.
