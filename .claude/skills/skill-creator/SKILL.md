---
name: skill-creator
description: >-
  Creates, reviews, and validates OpenCode skills following the Anthropic Agent
  Skills specification (agentskills.io). Use when creating a new skill, auditing
  an existing skill, or when user says "create skill", "new skill", "review skill",
  "audit skills".
  Examples:
  - user: "create a skill for deploying" -> scaffold SKILL.md with proper spec
  - user: "review my skills" -> audit all SKILL.md files for compliance
  - user: "create a skill for linting" -> scaffold SKILL.md following spec
  Never create skills outside the .claude/skills/ directory structure.
---

## What I do

Create and validate OpenCode skills following the Anthropic Agent Skills spec.
Skills that violate these rules fail silently: not discovered, not matched, or
waste tokens.

## Golden-template rule: copy, don't compose

NEVER write a new skill from a blank file. Find the existing skill closest in shape to
what you need (a command-reference skill, a workflow skill, an audit skill), copy its
SKILL.md as the starting point, and modify the minimum: name, description, and the
body sections that differ. The frontmatter idioms, section order, and command style
come along for free — which is exactly what freehand composition gets wrong. If you
find yourself rewriting most of the template, you picked the wrong exemplar; pick
another one.

## Path resolution for references/

Skills load from different locations per tool (`~/.claude/skills/`,
`~/.config/opencode/skills/`, project `.claude/skills/`). Inside a SKILL.md, paths
like `references/foo.md` are ALWAYS relative to the directory containing that
SKILL.md — never to the project CWD. When authoring, write reference links relative;
when following them as an agent, resolve them against the SKILL.md location before
reading.

## Directory structure

```
.claude/skills/{skill-name}/
├── SKILL.md              # lean entry point — always loaded when the skill triggers
└── references/           # OPTIONAL: depth loaded on demand
    └── {subtask}.md
```

One directory per skill. Directory name must match `name` in frontmatter.
The entry file is always `SKILL.md` (uppercase). The Agent Skills spec caps SKILL.md at
**500 lines**; in this repo prefer ~200 (everything in SKILL.md hits the context whether
the task needs it or not). When a section is only relevant to a subset of tasks or has
grown into step-by-step depth, move it to `references/{subtask}.md` and add a routing
table in SKILL.md (`| task | read |`) pointing to it — keep inline only orientation,
path-selection, and gotchas the agent must see before choosing a path. Keep each
reference under ~200 lines.

## SKILL.md format

```markdown
---
name: {skill-name}
description: >-
  {capability summary}. {use cases}. {proactive triggers}.
  Examples:
  - user: "{english phrase}" -> {action}
  - user: "{spanish phrase}" -> {action}
  Never use this for {anti-pattern}.
---

## Environment
All commands run via `ssh web`.

## Instructions
{Step-by-step actionable content}

## Verification
{How to verify correctness}
```

## Frontmatter rules

### name (REQUIRED)
- 1-64 chars, lowercase alphanumeric + single hyphens
- Must match directory name exactly
- Valid: `module-scaffold`, `quality-checks` | Invalid: `drupal_module`, `MySkill`

### description (REQUIRED, 1-1024 chars)
This is the ONLY text the LLM sees during skill selection. Structure:
1. **Capability**: What it does (1 sentence)
2. **Use cases**: When to invoke (1-2 sentences)
3. **Examples**: 2-4 with `user: "X" -> Y` format
4. **Anti-pattern**: "Never use for X"
5. Must include Spanish AND English triggers

## Progressive disclosure

```
Startup: Only name + description loaded (XML summary)
User message -> LLM matches description -> skill tool called -> full body loaded
```

If description doesn't match user intent, body NEVER loads.

## Validation checklist

- [ ] Directory name = `name` field
- [ ] Name: lowercase, hyphens only, 1-64 chars
- [ ] Description: 1-1024 chars
- [ ] Description has: capability, use cases, 2+ examples, anti-pattern
- [ ] Description has Spanish triggers
- [ ] YAML frontmatter valid
- [ ] Body has actionable instructions (not prose)
- [ ] Commands use `ssh web`
- [ ] No duplication with other skills or rules/
- [ ] No conflicts with CLAUDE.md policies
- [ ] File named exactly `SKILL.md`
- [ ] Body under ~200 lines (hard spec limit: 500) — split into `references/` beyond that

## Audit mode

When reviewing existing skills:

```bash
find .claude/skills -name "SKILL.md" | while read f; do
  dir=$(basename $(dirname "$f"))
  name=$(grep "^name:" "$f" | head -1 | awk '{print $2}')
  lines=$(wc -l < "$f")
  echo "$dir | name=$name | lines=$lines"
done
```

Report as:

| Skill | Status | Issues |
|-------|--------|--------|
| skill-name | PASS/WARN/FAIL | Details |

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Underscores in name | Use hyphens |
| Vague description | Add examples with `->` |
| No anti-pattern | Add "Never use for X" |
| Bare commands | Prefix `ssh web` |
| Body 200+ lines | Move subtask depth into `references/{subtask}.md` with a routing table |
| English-only triggers | Add Spanish phrases |
| Duplicates other skill | Merge or add anti-pattern boundary |
