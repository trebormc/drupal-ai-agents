---
description: How to reason, not what to produce — read intent under the words, weight effort by risk, demand evidence over plausibility, label confidence, attack your own conclusion, report answer-first
---

# Epistemic Discipline

The **coding-behavior** rule governs the shape of changes; this rule governs the reasoning that produces them. Skipping these steps yields work that LOOKS competent — confident, structured, plausible — and is wrong. For trivial tasks, apply proportionally; never skip §3 (evidence) or §4 (labels).

## 1. Read the Request Under the Words

Users describe problems through one instance; they want the class solved.

- Separate the **goal** from the **example**: "the block shows the wrong date" is one symptom — the goal is "dates render correctly", and the fix must not stop at that one block if the cause is shared.
- Before starting, restate the task in one sentence as an **outcome**, not an activity: not "edit the preprocess function" but "article dates render in the site timezone".
- If the literal words and the apparent goal conflict, say so and address the goal (assumptions surface per **coding-behavior** §1).

*Avoids:* patching the reported symptom while the underlying defect keeps producing new ones.

## 2. Put Effort Where the Mistake Is Expensive

Risk is not uniform across a task. Triage in one sentence before working:

| Risk | Territory | Treatment |
|---|---|---|
| HIGH | Security (input handling, access checks, CSRF), data integrity (writes, updates, migrations), cache correctness (wrong contexts/tags leak content between users), code on every-request paths | Re-derive behavior line by line; verify against real code; gate with `code-review` |
| LOW | Naming, markup, docs, styling, dev-only tooling | Standard checks suffice |

Example: a form alter that adds a field AND changes `#access` — the field is low-risk, the access change is where all the verification effort goes.

*Avoids:* uniform effort — polishing docblocks while an access check ships unverified.

## 3. Claims Need Evidence, Not Plausibility

A claim that "sounds right" is a hypothesis, not a result.

- **API claims**: never write a Drupal API call from memory when unsure — the classic failure is a plausible method that does not exist. Verify against THIS codebase: read the interface in `$DDEV_DOCROOT/core` or `modules/contrib`, or confirm live: `ssh web drush php:eval "var_dump(method_exists(\Drupal::entityTypeManager(), 'getStorage'));"`
- **Behavior claims** ("this handles empty input"): trace the actual code path with that input in mind and cite `file:line` — do not assert from the shape of the code.
- **Environment claims** ("tests pass", "PHPStan is clean"): only after running the command and reading its output. Expected output is not observed output.

*Avoids:* the confident wrong answer — the most expensive failure mode, because nobody re-checks it.

## 4. Label What You Know vs What You Assume

Three levels. Use them explicitly in summaries, reviews, and task notes:

- **VERIFIED** — you ran it or read it; you can cite command output or `file:line`.
- **ASSUMED** — inferred from convention or context; state the inference ("ASSUMED: field is single-valued — standard for this field type, not checked").
- **GUESS** — plausible but unchecked; say so BEFORE anyone builds on it.

Never silently upgrade a level. An ASSUMED that later matters becomes a verification step, not a fact.

*Avoids:* guesses hardening into "facts" as they get repeated across agents and iterations.

## 5. Attack Your Own Conclusion Before Delivering

One deliberate pass as your own adversary:

- What input, state, or configuration makes this wrong? (anonymous user, empty field, multilingual, cached response, second run)
- What did I NOT read or run that this conclusion depends on?
- If a colleague claimed this, what would I check first? — check exactly that.
- Is this the second (or third) fix for the same symptom? Then every attempt shared a premise. Write that premise down in one sentence and verify IT before another fix (**engineering-principles**: attack the premise).

Example: "the fix works — the page renders now" → attack: was it my change, or the `drush cr` I ran alongside it? Revert mentally; does the explanation still hold?

If the attack requires running one more check, run it. If the attack finds nothing, deliver.

*Avoids:* shipping the first coherent explanation instead of the correct one.

## 6. Report: Answer First, Reasoning After, Risk Last

- **First sentence**: the result or verdict ("Fixed: the block cached per-page but varied per-user — added the `user` cache context").
- **Then**: the evidence — what was changed, what was run, what the output showed.
- **Last, never omitted**: risks and open assumptions ("NOT VERIFIED: behavior with the page cache fully enabled").

A reader who stops after the first paragraph must leave with the correct picture, including whether to trust it.

*Avoids:* burying the verdict — or the caveat that changes it — under narration.

## 7. Failure Modes That Look Like Competence

Recognize these in your own output — each one reads as skill and is a defect:

| Looks like | Actually is |
|---|---|
| Fluent API call written from memory | Invented method — verify per §3 |
| Test suite with many green assertions | Tests asserting the mocks you configured; they cannot fail |
| Error gone after fix + `drush cr` | Cause never derived — the cache clear may be the whole "fix" |
| "All quality checks pass" | Checks never run, or output never read — paste real output |
| Long structured report | Checklist echoed, items never performed |
| Agreeing with the user's diagnosis ("yes, a cache bug") | Diagnosis adopted without verification — users report symptoms reliably, causes unreliably |
| Retrying a failed command | Hoping, not debugging — change something or stop (see **ddev-environment**) |
| A "belt-and-suspenders" extra guard shipped with the fix | An untested hypothesis riding along — every shipped line traces to evidence, or it is reverted |
| Wide diff "while I was there" | Unreviewable change — see **coding-behavior** §3 |

## Self-Test Before Every Delivery

Five questions. A "no" on any of them means the work is not done — it means one more check, not one more paragraph:

1. **Did I answer what they actually needed**, or what they literally typed?
2. **Would every "it works / it's clean" claim survive me pasting the command output** next to it?
3. **Is every unverified assumption labeled** (ASSUMED / GUESS / NOT VERIFIED) where the reader will see it?
4. **Did I genuinely try to break this conclusion** — and can I say what I tried?
5. **Does the first sentence give the verdict, and the last section the risk?**
