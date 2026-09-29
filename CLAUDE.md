@AGENTS.md

## Claude Code

`AGENTS.md` (imported above) is the full source of truth for all agents. Claude-specific:

- **A reviewer that only reads the code never confirms behaviour.** Every regression here was
  found by measuring on the machine, so a review of `main.swift` is a list of things to measure.
- `.claude/doc-structure.json` declares where documents go.
