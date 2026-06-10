---
description: Behavioral guardrails against common LLM coding mistakes — overcomplication, non-surgical changes, hidden assumptions, unverifiable goals
---

# Coding Behavior

Guardrails against the most common LLM coding mistakes. Derived from Andrej Karpathy's observations on LLM coding pitfalls (MIT-licensed karpathy-guidelines), adapted to this ecosystem. For trivial tasks, use judgment — these bias toward caution.

## 1. Surface Assumptions — Never Hide Confusion

- State your assumptions explicitly before implementing.
- If multiple interpretations exist, present them — don't pick one silently.
- If a simpler approach exists than what was asked, say so before building the complex one.
- **Interactive session**: if something is genuinely unclear, stop and ask the user.
- **Autonomous run (Ralph Loop)**: there is no user to ask. Pick the most conservative interpretation, write the assumption into the Beads task notes (`bd update <id> --notes "ASSUMPTION: ..."`), and continue.

## 2. Simplicity First

Minimum code that solves the problem. Nothing speculative:

- No features beyond what was asked.
- No abstractions, interfaces, or "configurability" for single-use code.
- No error handling for impossible scenarios.
- If you wrote 200 lines and it could be 50, rewrite it before presenting.

Test: "Would a senior Drupal developer call this overcomplicated?" If yes, simplify.

## 3. Surgical Changes

Touch only what you must. **Every changed line must trace directly to the user's request.**

- Don't "improve" adjacent code, comments, or formatting you weren't asked to touch.
- Don't refactor things that aren't broken. Match existing style even if you'd do it differently.
- If you notice unrelated dead code or problems, MENTION them in your summary — don't fix them.
- DO remove imports/variables/functions that YOUR change made unused. Don't remove pre-existing dead code.

This is critical for SEARCH/REPLACE blocks (drupal-dev, drupal-theme): small, targeted blocks that change only what the task requires apply cleanly; "while I'm here" edits cause match failures and unreviewable diffs.

## 4. Goal-Driven Execution

Transform vague tasks into verifiable goals BEFORE starting:

| Vague task | Verifiable goal |
|---|---|
| "Add validation" | Write tests for invalid inputs, then make them pass |
| "Fix the bug" | Write a test that reproduces it, then make it pass |
| "Refactor X" | Tests pass before AND after; behavior unchanged |
| "Improve performance" | Measure baseline, change, re-measure (see performance-audit skill) |

For multi-step tasks, state a brief plan where each step has its own check:

```
1. [Step] -> verify: [exact command or observable result]
2. [Step] -> verify: [exact command or observable result]
```

The verification commands live in each agent's Verification Workflow and in the quality-checks skill — a goal without a check is not done.

---

**These guardrails are working if:** diffs contain only lines that trace to the request, code is not rewritten because the first version was overcomplicated, and assumptions/questions surface BEFORE implementation instead of after mistakes. If you catch yourself violating one mid-task, note it per the lessons-learned rule.
