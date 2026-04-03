---
description: Applier pattern protocol — SEARCH/REPLACE block format for code changes
---

# Applier Protocol

Agents that cannot edit files directly (drupal-dev, drupal-theme) generate SEARCH/REPLACE blocks and delegate to the `applier` agent.

## SEARCH/REPLACE Format

For modifying existing files:
```
path/to/file.ext
<<<<<<< SEARCH
[exact lines to find - include 2-3 context lines]
=======
[replacement code - preserve indentation exactly]
>>>>>>> REPLACE
```

For creating new files:
```
path/to/new/file.ext
<<<<<<< CREATE
[full file content]
>>>>>>> CREATE
```

## Invoking Applier

After generating SEARCH/REPLACE blocks, delegate to the `applier` agent:
- **OpenCode**: `Task: applier` with the blocks as input
- **Claude Code**: `Agent` tool with `subagent_type: applier`

## Rules

1. Match whitespace EXACTLY (spaces, tabs, newlines)
2. Include 2-3 lines of context in SEARCH blocks for unique matching
3. Apply blocks in dependency order (create files before modifying them)
4. Never modify content beyond what is specified
