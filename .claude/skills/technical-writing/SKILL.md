---
name: technical-writing
description: >-
  Writes and reviews developer documentation for Drupal work — module README, hook_help,
  change records and release notes, drupal.org issue summaries, ADRs, PR/MR
  descriptions — using a layered standard: one Diátaxis mode per document (tutorial,
  how-to, reference, explanation), sentences addressed to the reader, one instruction
  per sentence, no sentence open to two readings, and no AI tells. Use when asked to
  write or review docs, READMEs, issue summaries, or long-form commit/MR bodies.
  Examples:
  - user: "write the README for this module" -> pick the mode(s), write, run the checklist
  - user: "redacta el resumen del issue para drupal.org" -> issue summary template, plain
  - user: "review this documentation" -> checklist findings with rewrites
  - user: "explain this decision in an ADR" -> explanation mode, decision + alternatives
  Never use for commit subject lines (commit-message skill) or user-facing UI strings
  (translations rule).
allowed-tools: Read Grep Glob Write Edit
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Technical Writing

The goal is text a tired developer understands on the first read. Four layers, one
question each: what kind of document is this, how do sentences address the reader, how
much does each sentence carry, can any sentence be read two ways. Three rules sit above
them:

- Cut every word that does no work. "In order to" is "to". "It is important to note
  that" is nothing.
- Use the short everyday word: "use" not "utilize", "help" not "facilitate", "do"
  not "perform".
- When a rule makes a sentence worse, fix the sentence another way. The rules serve
  the reader.

The codebase is the word list: write the real hook, service id, route name, drush
command, and file path, never a description of it. Counts and trees must be true at
the commit that lands them; include the command that regenerates them.

## 1. Pick the mode (Diátaxis) — one document, one mode

| Content serves... | Mode | Drupal examples |
|---|---|---|
| Doing + learning | **Tutorial** | "Build your first plugin with this module", onboarding walkthrough |
| Doing + work | **How-to** | "How to migrate from 1.x to 2.x", "How to add a custom formatter", most README "Usage" sections |
| Understanding + work | **Reference** | hook_help API listing, config schema, drush command options, event names, `.services.yml` ids |
| Understanding + learning | **Explanation** | ADR, "why this module does not cache per user", change record rationale |

Tutorial: you are the teacher; every step produces a visible result; say what the
learner should see (`drush cr` output, the page, the log line). How-to: assume
competence, action only, name it by the task ("How to configure the cron interval").
Reference: describe, only describe, dry and complete, mirror the code's structure.
Explanation: one bounded topic, the real why, alternatives and trade-offs; opinion
allowed here and nowhere else. Do not mix modes in one file; split and link.

A module README is usually a short explanation (what and why, 3 lines) + a how-to
(install, configure, use) + a reference (settings, hooks, events, drush commands),
in that order, each under its own heading.

## 2. Write to the reader (Google developer style)

- Address the reader as "you", present tense. "Will" only for things that happen later.
- Say who does what: "the cron hook deletes", not "is deleted".
- Instructions are commands with the condition first: "To disable caching, set
  `max-age` to 0."
- Common case first, exceptions after. No "simply", "easy", "just" in a procedure.
- Headings carry the point ("Configure the API key", not "Configuration"). Sentence
  case. Task headings are verb phrases; concept headings are noun phrases.
- Numbered lists for sequences, bullets for everything else; introduce a list with a
  full sentence; keep items parallel.
- Code in code font, UI elements in bold, links that say where they go (never "here").

## 3. One thing per sentence (STE)

- One instruction per sentence; split instructions over ~20 words and other sentences
  over ~25.
- Keep articles: "Remove the backup file" reads one way, "Remove backup file" two.
- One word per action, kept everywhere: "enable", not "enable" here and "activate"
  there. One name per thing across the doc set.
- Warnings before the step they guard.
- Prefer plain verbs to `-ing` forms.

## 4. No sentence with two readings (Global English)

- "Only" and "not" next to the word they change.
- Break noun strings: "the script that checks the config schema", not "the config
  schema check script".
- Every "it", "this", "they" points at one obvious noun; repeat the noun when in doubt.
- Periods, not semicolons; a new sentence instead of an em dash.
- No slashes ("a, b, or both"), no "(s)" plurals, no idioms, no Latin abbreviations.

## 5. Drupal document templates

**Change record / release note** (explanation + reference): what changed, who is
affected (site builders, module developers), before/after code, the deprecation and
removal versions, the issue link.

**drupal.org issue summary**: `Problem/Motivation` (observed behavior, steps, versions),
`Proposed resolution`, `Remaining tasks`, `User interface changes`, `API changes`,
`Data model changes`. Facts and commands, no narrative of your debugging session.

**PR / MR description** (how-to layers apply, not Diátaxis): `Why` (intent, one or two
short paragraphs), `Scope` (real symbols and paths, both sides of a rename),
`Tradeoffs` (only rejected alternatives a reviewer would ask about), `Blast radius`
(who or what it touches, why it is safe — see **drupal-blast-radius**),
`Verification` (each real run path and its outcome, one primary number for perf in
`before → after` form). No SHA lists, no tool-output dumps, no "Summary"/"Test plan"
boilerplate. Under 40 lines.

**ADR** (explanation): context, decision, alternatives considered with one line on
why each lost, consequences, status.

## 6. AI tells to remove (apply to every doc)

Superficial `-ing` phrases ("ensuring...", "highlighting..."), vague attributions
("best practices suggest"), vocabulary such as "leverage", "robust", "seamless",
"delve", "crucial", "landscape"; "not just X, but Y"; forced groups of three; "from X
to Y" false ranges; synonym cycling for one thing; em dashes as connectors; colons as
mid-sentence connectors; bold-label lists that restate the line ("**Caching:**
caching is..."); title-case headings; decorative emoji; hedging stacks; generic
closers ("the future looks bright"); metaphor nouns ("substrate", "north star",
"scaffolding" as metaphor). Say what the code does, not how it feels: "`.toSQL()`
returns the exact query string", not "SQL you can read".

## 7. Review checklist

1. One Diátaxis mode per file, links where modes meet?
2. Every instruction a command with its condition in front?
3. Any sentence carrying two instructions or two thoughts? Split it.
4. Any word cuttable without losing meaning? Cut it.
5. "Only" placed right; every "it" unambiguous; every clause has its verb?
6. One name per thing across the docs?
7. Would a Drupal developer say these words out loud? Real symbols, no invented jargon?
8. Symbols, paths, counts true at this commit, with the regenerating command?
9. Section 6 tells gone?

Report findings as `location — issue — rewrite`, rewrites ready to paste.
