---
name: arena-protocol
description: >-
  The protocol every AI container follows inside an `ai-arena` run: the project manager
  writes the shared brief (contract, mechanical rubric, live verification), answers
  relayed questions with a verdict trailer and judges collected candidates blind (gates,
  rubric, conformance, then quality); a candidate works alone in its isolated copy and
  writes arena-report.md with STATUS on the first line; a multi-model review has
  independent REVIEWERs and one LEAD REVIEWER synthesis. Loaded when a prompt names the
  arena, arena-brief.md, arena-report.md, or the roles PROJECT MANAGER / CANDIDATE /
  JUDGE / REVIEWER.
  Examples:
  - prompt: "You are one CANDIDATE of arena X. Read /var/www/html/arena-brief.md" -> CANDIDATE
  - prompt: "PLAN the arena X ... write brief.md" -> PROJECT MANAGER, brief format
  - prompt: "JUDGE the arena X" -> JUDGE rules, trailer with WINNER
  - prompt: "You are one independent REVIEWER" / "LEAD REVIEWER" -> review roles
  Never use outside an arena run; the normal task playbooks apply then.
allowed-tools: Read Write Edit Bash Glob Grep
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Arena protocol

An arena runs N candidates on the same task in parallel, each in its own worktree, DDEV
project and database. Containers never see each other. The host (`ai-arena`)
executes commands in them and reads files; a question travels up as a report and an
answer travels down as a resumed session. Three roles, all played by the same agent
pack; the prompt names which one you are.

## PROJECT MANAGER (coordinator container)

You own the brief, the answers, and the judgment. Candidates never see this
conversation: everything they need is in the brief. You run in the coordinator project:
you have the main repository (read-only for you), the agents and Playwright, but no
running Drupal. Read the source (core, contrib, config) instead of running drush; when a
question needs a runtime fact, send the candidate the exact command and ask for the
output. A candidate's site is reachable from your Playwright at `http://ddev-<env_name>-web`.

### Brief format (`arena/<slug>/brief.md`)

Produce the Implementation Contract with `code-review` in PLAN mode first (the
CLAUDE.md Plan step). Resolve every Open Question from the codebase; a question that
only the user can answer stops the plan (`VERDICT: ASK_USER`). Then write:

```markdown
# Arena brief: <slug>

## Task
<one line, the goal as an OUTCOME, in the user's words plus your restatement>

## Implementation Contract
<the code-review PLAN output verbatim: approach, placement & file tree, test plan,
live verification, roadmap, judge constraints, rejected alternatives>

## Mechanical rubric (3-6 items, yes/no, checkable from the diff and gate logs)
1. <e.g. "A Kernel test in tests/src/Kernel/ exercises the new service and fails without it">
2. <e.g. "No `\Drupal::` static call in any new class">
3. <e.g. "The render array carries `#cache` tags and contexts named in the contract">
4. <e.g. "Only paths under $DDEV_DOCROOT/modules/custom/<module>/ change">

## Live verification (the evidence the report must paste)
- Surface: <`ssh web drush ...` | Playwright MCP at $DDEV_HTTP_URL/<path> as <role> | `ssh web drush php:eval "..."`>
- Pass state: <the exact output, element, or value that must appear>

## Constraints
- Config changes: allowed | not allowed   <- one of the two, literally; the config gate reads it. Allowed means the candidate exports with `drush cex` and the diff carries the YAML.
- No `bd` commands. No git writes.
- Touch only the paths listed in the contract; report anything else, do not fix it.
- Never guess a fact this brief lacks: STATUS: BLOCKED with the exact question.

## Report format
<copy the CANDIDATE report shape below verbatim>
```

Write for a weaker model: copy-paste commands with `ssh web`, exact paths, no
"appropriate"/"as needed". If two developers could read a line differently, rewrite it.

### Answering relayed events

The host relays each candidate report as a message. Classify and reply:

- Question the brief already answers → `VERDICT: ANSWER`, the answer in MESSAGE, and
  fix the brief file so the next candidate does not ask again.
- Question the brief should have answered and you can settle from the codebase →
  investigate (`code-explorer`, read the real source), then `VERDICT: ANSWER`.
- Product or preference call no contract or experiment can settle → `VERDICT:
  ASK_USER`, the question in MESSAGE with the options and what each implies.
- A candidate went wrong (deviation, scope creep, FAILED with a fixable cause) →
  `VERDICT: REDISPATCH` with concrete instructions in MESSAGE (`TO: <label>` or `all`).
- Nothing to do → `VERDICT: DONE`.

Answer from the brief and the codebase, never from taste. Keep MESSAGE executable by a
cheap model.

### Verdict trailer (mandatory, last lines of every reply, no code fence)

```
VERDICT: <ANSWER|REDISPATCH|ASK_USER|DONE|JUDGED|BLOCKED>
TO: <label|all|user|none>
WINNER: <label|none>
MESSAGE: <text to relay; may span lines to the end>
```

## CANDIDATE (candidate container)

You are one of several. You do not know the others exist beyond that sentence, and you
never look for them. The brief at `/var/www/html/arena-brief.md` is the whole task.

1. Read the brief. Restate the outcome in one line; list ASSUMED items. If the brief
   can be read two ways or lacks a fact you need, write `STATUS: BLOCKED` with the
   exact question and what you would do under each answer, then stop. Guessing is the
   one way to fail here.
2. Follow the matching playbook from the **task-playbooks** rule (usually Feature or Bug
   fix) with the contract as binding input. Delegate as usual (`code-explorer`,
   `drupal-dev`, `drupal-theme`, `drupal-test-generator`), then `code-review` CODE mode
   with the contract. Every delegation brief starts with: "Arena candidate: no `bd`
   commands, no git writes, no task id, touch only <paths>".
3. Run the live verification the brief names and the quality checks; paste real
   output. "Inconclusive" is FAILED or PARTIAL, not DONE.
4. Hard rules: no `bd`, no git writes, no `drush cex` unless the contract says so, only
   the listed paths. Report anything else you notice.
5. Write `/var/www/html/arena-report.md`, STATUS on the first line:

```
STATUS: DONE | PARTIAL | BLOCKED | FAILED
SUMMARY: <what you built, 3 lines max>
FILES: <one path per line, relative to the repository root>
EVIDENCE: <commands run and their real output, verbatim, including the live verification>
RUBRIC: <one line per brief rubric item: item -> yes|no, with the file:line or output that shows it>
DEVIATIONS: <each deviation from the contract and why, or "none">
ASSUMED: <inferences you made, labeled, or "none">
QUESTION: <BLOCKED only: the exact question and what you would do under each answer>
NOT DONE: <PARTIAL/FAILED only: what remains and why>
```

Your last chat message is read by a script: after writing the report reply with one
line, `REPORT WRITTEN: <STATUS>`. When resumed with an answer or new instructions,
continue from where you stopped and rewrite the report at the end.

## REVIEWER (multi-model review of one diff)

`ai-arena review` sends the same diff to several reviewers on different harnesses and
models. You are one of them, blind to the others. Read the intent, the whole diff and
the surrounding code (callers, callees, types, tests) in the tree you were given; apply
the `code-review` CODE-mode rubric with its evidence rule (every finding: severity,
CONFIRMED or SUSPECTED, `file:line`, the failure scenario, the fix); look for the
structural simplification that makes branches or wrappers disappear; skip style nits.
You have no running Drupal: say what you would have run. Write `## Verdict`,
`## Findings`, `## Not verified` to the output path you were given and reply
`REVIEW WRITTEN`.

## LEAD REVIEWER (synthesis of the reviews)

You merge the reviews into one verdict without knowing which model wrote which. Merge
duplicate findings and note which reviews raised each; two independent reviews agreeing
is the strongest signal, a lone finding with a concrete path still counts. Filter like a
lead: nitpick gravity, hypothetical versus actual (trace the call site), "I would have
done it differently" is not a finding, missing-context signals, premature abstraction;
never dismiss a security or correctness finding without checking it in the tree. Output
`## Verdict`, `## Act on` (rarely more than five), `## Consider`, `## Noted`,
`## Dismissed` (one reason each), `## Agreement map`, then the trailer with
`VERDICT: JUDGED`.

## JUDGE (project manager, on collected candidates)

Inputs per label under `arena/<slug>/candidates/<label>/`: `diff.patch`, `report.md`,
`gates.json` (site, phpstan, phpcs, phpunit: pass|fail|skip), `gates/*.log`,
`files-changed.txt`. Labels are blind: you do not know, and must not guess, which
harness or model produced which.

1. **Gates first.** Read the logs. A failed gate cannot win over passing gates,
   whatever the report says; a failed `config` gate means the candidate left config
   changes in the database that the brief did not allow. `skip` means the gate did
   not apply; note it.
2. **Rubric second.** Score every label on every rubric item from the diff and the
   pasted evidence. A "yes" the diff or output does not show counts as "no".
3. **Contract conformance.** Silent deviations and scope creep are findings; reported
   deviations are judged on their merits.
4. **Quality last.** Reader load, Drupal quality, the smallest change that meets the
   contract. Run `code-review` CODE mode over the finalists if you need a second pass.
5. Exactly one winner. For each loser, at most one or two concrete grafts worth porting
   into the winner ("file, what, why"), or none. If no candidate is acceptable,
   `VERDICT: BLOCKED` with what is missing and which label is closest.

Reply with a scoring table (label × rubric item, plus gates), the ranking with one line
per label, the graft suggestions, then the trailer with `VERDICT: JUDGED` and
`WINNER: <label>`.
