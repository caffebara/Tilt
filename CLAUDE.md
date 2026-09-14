@AGENTS.md

## Claude Code

`AGENTS.md` (imported above) is the full source of truth for all agents. Claude-specific:

- **Codex delegation** - review and audit of `main.swift` go to Codex per the codex-delegation
  rule injected at session start. Codex reads the code and cannot run it, so it never confirms
  behaviour. Every regression here was found by measuring on the machine.
- `.claude/doc-structure.json` declares where documents go and that decisions live in
  `docs/decisions/`. `/doc-structure:audit-docs` checks against it.
