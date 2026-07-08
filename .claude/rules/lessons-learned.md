---
description: Self-learning protocol — document problems and solutions in LESSONS_LEARNED.md
---

# Lessons Learned — Self-Learning Protocol

## Purpose

Agents document problems and solutions as they work, creating a knowledge base that prevents repeating mistakes.

## When to Document

1. A command fails and you discover the correct syntax/approach
2. Generated code causes errors (missing function, wrong namespace, deprecated API)
3. A Docker/DDEV operation behaves unexpectedly and you find the fix
4. A Drupal API is used incorrectly (wrong hook, missing dependency, cache issue)
5. A workaround was needed for an environment-specific issue

## Format (append to `LESSONS_LEARNED.md` in project root)

```markdown
### [SHORT_TITLE] — [DATE]

- **Problem**: [What went wrong — include exact error message]
- **Root cause**: [Why it happened]
- **Failure type**: [see taxonomy below]
- **Solution**: [How it was fixed — include exact command or code]
- **Category**: [docker | drupal-api | php | drush | composer | phpcs | phpstan | phpunit | twig | playwright | beads | permissions | other]
- **Applies to**: [agent:name | skill:name | rule:name | CLAUDE.md]
- **Suggested improvement**: [What to add to the target so this never happens again]
```

## Failure Taxonomy — classify WHY the reasoning failed, not just what broke

The failure type determines the right fix. Record the reasoning failure, not only the
surface error:

| Type | Meaning | Right fix |
|---|---|---|
| `CONFABULATION` | Invented a plausible API/command/path (e.g. `\Drupal::entityManager()`) | Verify-before-use habit (epistemic-discipline §3); patch the skill if the wrong API appears in guidance |
| `ASSUMPTION_ERROR` | Facts were right, inference was wrong (right service, wrong usage pattern) | Patch the example/pattern in the relevant skill or rule |
| `KNOWLEDGE_GAP` | No skill/rule covers this area | Add a section to the closest skill, or propose a new one |
| `STALE_KNOWLEDGE` | A skill/rule contains outdated info (API changed) | Patch the outdated guidance |
| `ENVIRONMENT_QUIRK` | Correct code, environment behaved unexpectedly | Document in LESSONS_LEARNED.md; promote to ddev-environment rule if recurring |

## Promotion Rule

When **3 or more lessons** share the same failure type + category (or the same lesson
appears in a second project), the fix is no longer a log entry — propose to the user a
patch to the target skill/rule/agent named in "Applies to". Lessons that only accumulate
in the log do not change future sessions; patched guidance does.

## What NOT to Document

- Typos or simple syntax errors caught immediately
- Problems already covered by existing rules
- One-off issues specific to a single file
- Problems where the root cause is unknown

## Session Workflow

**Start**: `test -f LESSONS_LEARNED.md && cat LESSONS_LEARNED.md | head -100`
**During**: Append lessons immediately after solving non-trivial problems
**End**: Mention lessons documented in session summary
