---
name: session-distill
description: >-
  Converts what a session learned the hard way (failed attempts, final fixes, verified
  facts) into durable guidance — a patch to an existing skill/rule, a project skill, or
  a new shared skill — so future runs one-shot the solution instead of re-exploring dead
  ends. User-invoked at the end of meaningful work.
  Examples:
  - user: "convierte lo que hemos aprendido en una skill" -> harvest, classify, write artifact
  - user: "guarda esto para futuras sesiones" -> route learning to the right destination
  - user: "distill this session into a skill" -> full pipeline
  - user: "que la próxima vez no tengamos que descubrir esto otra vez" -> distill
  Never use during work for routine logging (that is the lessons-learned rule) and never
  for formatting/validating a skill file (that is skill-creator — this skill delegates to it).
allowed-tools: Bash Read Grep Glob Write Edit
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Session Distill

Turn session learnings into guidance that makes future runs faster and cheaper. The
value is NOT documenting what worked — it is documenting the dead ends, so the next
agent never walks into them.

## Step 1 — Harvest candidates

Mine four sources: the current conversation, `LESSONS_LEARNED.md`, Beads task notes
(`bd show <id> --json` for tasks touched this session), and the session transcript on
disk, which remembers what the conversation forgot. Claude Code keeps one JSONL per
session under `~/.claude/projects/<workspace-slug>/`; OpenCode exports one with
`opencode export <sessionID>`. Do not read a transcript whole: pull the failure and
correction moments only:

```bash
f="$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -n1)"
# Tool calls that errored, with the command that caused them:
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result" and .is_error==true) | .content | tostring | .[0:300]' "$f"
# User turns that corrected the agent (the words that usually follow a wrong move):
jq -r 'select(.type=="user") | .message.content | if type=="string" then . else (.[]? | select(.type=="text") | .text) end' "$f" | grep -iE "no,|not that|wrong|again|instead|en realidad|no es eso|otra vez|mal" | head -n 20
```

Read each hit through three lenses, as separate questions: judgment (what principle
would have avoided it), tooling (what command, flag or path was wrong and what the
right one is), divergence (what a different approach would have done). A lesson that
survives all three lenses is a candidate. A candidate is:

- A solution that worked AFTER one or more failed attempts (the highest-value kind).
- A non-obvious environment/API fact that was verified in-session (command output,
  file read, passing test).
- A decision between approaches, with the rationale that settled it.

For each candidate, record: **problem → attempts that failed and WHY each failed →
final solution → root cause → the evidence** (the exact command/output or file:line
that confirmed it).

**Epistemic gate (hard rule):** only distill solutions with observed evidence in the
session. "The error went away" without a derived cause is not distillable — the fix may
have been the cache clear next to it. If the solution was merely the last thing tried,
say so and skip it; fossilizing a superstition into permanent guidance poisons every
future session. When in doubt, re-verify now (run the command, revert-and-retry) before
distilling.

## Step 2 — Classify

Tag each candidate on two axes:

- **Failure type** — use the taxonomy in the **lessons-learned** rule (CONFABULATION,
  ASSUMPTION_ERROR, KNOWLEDGE_GAP, STALE_KNOWLEDGE, ENVIRONMENT_QUIRK).
- **Scope** — PROJECT (paths, versions, quirks of THIS codebase: "this theme's build
  needs X") vs UNIVERSAL (true in any Drupal/DDEV project: "lazy builder args must be
  scalars").

## Step 3 — Route to the right destination

Check for an existing home FIRST — grep the skills/rules for the topic before writing
anything new:

```bash
# Covers both tools' synced copies plus the project's own skills/rules:
grep -rli "KEYWORD" ~/.claude/skills/ ~/.claude/rules/ \
  ~/.config/opencode/skills/ ~/.config/opencode/rules/ \
  .claude/skills/ .claude/rules/ 2>/dev/null
```

Then apply this table in order — **the default outcome is a small patch; a new skill is
the exception**:

| Situation | Destination |
|---|---|
| Existing rule/skill already covers it correctly | Nothing to write. If the session proves it WRONG or stale → patch that file (STALE_KNOWLEDGE) |
| UNIVERSAL + an existing skill/rule covers the area | **Patch it**: one troubleshooting-table row, one "What not to do" bullet, one corrected example. Smallest change that prevents the repeat |
| UNIVERSAL + no home + substantial recurring theme | **New shared skill** — follow **skill-creator** for structure/frontmatter/validation |
| PROJECT + procedural (how to run/test/deploy THIS project) | **Project skill** in the project's `.claude/skills/<name>/SKILL.md` |
| PROJECT + isolated fact or quirk | `LESSONS_LEARNED.md` entry (lessons-learned rule format) — do not create artifacts for one-offs |
| Behavioral (how agents should reason/work) | Propose a change to a rule — present the diff to the user, do not decide alone |
| A skill existed but did not trigger when it should have | Do not add content: tune that skill's `description` (triggers, examples in both languages) via **skill-creator**; a body that never loads is worthless |
| Enforceable mechanically (a shape PHPStan/PHPCS/a test/a script can catch) | Encode it in structure (**lessons-learned** rule table), not in prose; the artifact is the rule/sniff/test plus one pointer line |

**Where files go:** project-scoped artifacts are written directly into the project.
UNIVERSAL artifacts belong to the shared agents repo (`drupal-ai-agents`) — if this
session is not running inside that repo, write the proposed file/patch to
`proposed-skills/` in the project root and tell the user to review and move it into
`drupal-ai-agents` (it syncs to all projects via agents-sync). Never silently edit the
synced copies under `~/.claude/` or `~/.config/opencode/` — they are regenerated on
every container start.

## Step 4 — Write the artifact

Structure every distilled item, whatever the destination, as:

1. **Trigger** — the symptom/task a future agent will actually face (error message,
   request phrasing), so it matches when needed.
2. **Do this** — the verified solution, copy-paste ready (`ssh web ...`), with the
   verification command that proves it worked.
3. **Not this** — each failed attempt as an explicit anti-pattern WITH the reason it
   fails. This is where the token savings live: `"Do not try increasing the timeout —
   the root cause is the missing schema, not slowness"`.
4. **Root cause** — one sentence, so the guidance survives surface variations of the
   same problem.

For new skills, delegate structure and frontmatter validation to **skill-creator**
(name rules, description with English+Spanish triggers, ~200-line body, `references/`
if it grows).

## Step 5 — Quality gate before delivering

- **One-shot test**: would an agent with ONLY this artifact — no session history —
  reach the solution directly? If it still needs a discovery step, the load-bearing
  detail is missing; add it.
- **No duplication**: the grep in Step 3 came up empty, or you patched instead of
  duplicated.
- **Right altitude**: no session narrative ("first we tried..."), no project paths in
  UNIVERSAL artifacts, no generalities in PROJECT ones.
- **Structural check**: for every item routed to prose, say in one line why a lint,
  test, or script could not enforce it instead. If you cannot, re-route it.
- **Scope to what the session used**: findings point at skills, rules, or agents that
  were actually invoked or that visibly failed to trigger — not speculative homes.
- Report to the user, per candidate: destination chosen, VERIFIED evidence it rests
  on, and anything discarded for failing the epistemic gate (say why).

## What not to do

- Do not distill unverified fixes — superstition written down looks like knowledge.
- Do not default to creating skills — skill sprawl degrades matching for every future
  session; patch existing guidance first.
- Do not omit the failed attempts — a skill that only shows the happy path saves
  almost nothing.
- Do not write session-specific narrative into durable guidance.
- Do not edit the synced config copies — target the project or propose for the shared
  repo.

## See also

- **lessons-learned** rule — in-session capture format and failure taxonomy (this
  skill is its promotion step)
- **skill-creator** skill — format mechanics for any new skill this produces
- **epistemic-discipline** rule — the verification standard candidates must meet
