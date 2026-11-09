---
name: arena-protocol
description: >-
  The protocol every AI container follows inside an `ai-arena` run: the project manager
  writes the shared brief (contract, mechanical rubric, live verification), answers
  relayed questions with a verdict trailer and judges collected candidates blind (gates,
  rubric, conformance, then quality); a candidate works alone in its isolated copy and
  writes arena-report.md with STATUS on the first line; a multi-model review has
  independent REVIEWERs and one LEAD REVIEWER synthesis. In a phased arena, PLANNERs write
  competing plans, the PM merges them and a GRAFTER ports the best of the losers into the
  winner. Loaded when a prompt names the arena, arena-brief.md, arena-plan.md,
  arena-report.md, or the roles PROJECT MANAGER / PLANNER / CANDIDATE / JUDGE / REVIEWER /
  GRAFTER.
  Examples:
  - prompt: "You are one CANDIDATE of arena X. Read /var/www/html/arena-brief.md" -> CANDIDATE
  - prompt: "PLAN the arena X ... write brief.md" -> PROJECT MANAGER, brief format
  - prompt: "You are one PLANNER of arena X" -> PLANNER, writes arena-plan.md, no code
  - prompt: "MERGE THE PLANS of arena X" -> PROJECT MANAGER, merging the plans
  - prompt: "You finish arena X" -> GRAFTER
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
CLAUDE.md Plan step), in the foreground of your turn: a plan delegated to a background
subagent is killed when the turn ends and the brief is never written. Resolve every Open
Question from the codebase; a question that only the user can answer stops the plan
(`VERDICT: ASK_USER`). Strip from the contract any "work split", "parallel implementers"
or per-implementer file table the playbook produced: each candidate is ONE implementer
that owns the whole contract, and a split in the brief makes it believe someone else owns
the rest.

**Contract altitude.** The arena compares what candidates build, so the contract fixes the
WHAT and leaves the HOW to them. It states the outcome, data model, public interfaces
(service IDs, routes, method signatures), file tree, behaviours to test, traps found in the
code and live verification. It carries no implementation bodies: no final file contents, no
method code, no ready-made test code. Identical code from every candidate means the brief
dictated it, and the arena then measured who follows instructions, not who builds better.
Rewrite any `code-review` output that crosses this line before it goes in the brief. Then
write:

```markdown
# Arena brief: <slug>

## Task
<one line, the goal as an OUTCOME, in the user's words plus your restatement>

## Implementation Contract
<the code-review PLAN output at the altitude above: approach, placement & file tree, test
plan, live verification, roadmap, judge constraints, rejected alternatives>

## Mechanical rubric (3-6 items, yes/no, checkable from the diff and gate logs)
1. <e.g. "A Kernel test in tests/src/Kernel/ exercises the new service and fails without it">
2. <e.g. "No `\Drupal::` static call in any new class">
3. <e.g. "The render array carries `#cache` tags and contexts named in the contract">
4. <e.g. "Only paths under $DDEV_DOCROOT/modules/custom/<module>/ change">
<always include, when the task touches code an existing surface (REST route, form, hook,
service) already uses: "Every pre-existing endpoint/form keeps its accepted inputs and
response shape; a kernel test pins one of them" — contract regressions through a shared
service were the most common finding of the multi-model reviews>

## Live verification (the evidence the report must paste)
- Surface: <`ssh web drush ...` | Playwright MCP at $DDEV_HTTP_URL/<path> as <role> | `ssh web 'drush php:eval "..."'`>
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
"appropriate"/"as needed". If two developers could read a requirement differently, rewrite
it. How to implement it stays open: that is what the arena measures.

Every command in the brief has to run as written, or each candidate loses time on the same
failure and reports the same deviation:

- PHP and SQL use the forms of "Quoting Through `ssh web`" in the **ddev-environment** rule,
  usually `ssh web drush php:script -` with a heredoc. `ssh web drush php:eval '...'` fails.
- PHPUnit commands carry `SIMPLETEST_DB` and the project's real `vendor/` path.
- No `git` commands: git fails in the container. The host compares the files.
- A test gate is `0 failures`, never a literal such as `OK (9 tests`: PHPUnit prints
  `OK, but there were issues!` on any deprecation, which pushes a candidate to hide it with
  `#[IgnoreDeprecations]`.
- Expected UI text is written in the site's default language.

### Approaches mode

When the prompt says APPROACHES MODE, the arena compares designs, not models: every label
runs the same model and follows an assigned approach in `arena/<slug>/approach-<label>.md`
(first line: a short title; then what to build differently, where, what to avoid). Two
variants:

- **User-defined**: the files exist. Read them, keep the contract approach-neutral
  (rubric and live verification satisfiable by every approach), never rewrite them; if
  one cannot work in this codebase, `VERDICT: ASK_USER` with why.
- **PM-proposed**: write one file per label with genuinely different, defensible
  approaches (different placement, mechanism or trade-off; not cosmetic variants), then
  reply `VERDICT: ASK_USER` listing them one line per label so the user confirms or edits
  them before spawn. When resumed with changes, rewrite the files accordingly.

Answers to a label must stay within its approach.

### Merging the plans

In a phased arena you do not plan: each candidate already did, and the plans are under
`arena/<slug>/plans/<label>.md`, blind. Check the facts of each one against the code, pick
one base, and improve it with what the others saw better. The brief you write has the
format above and the same altitude: its contract binds every candidate, so it fixes the
design they compete to build, not the code. Keep the verification and rubric at their
strongest across the plans. Name in your reply what each label contributed. A plan stopped at
the deadline is unfinished: it cannot be the base, and only its checked facts count. A plan's
open question that only the user can answer is `VERDICT: ASK_USER`.

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

## PLANNER (candidate container, phased arena)

You compete on the investigation and the design, not on the code. The task is in
`/var/www/html/arena-brief.md`. Use the running site to check what the code only suggests.
Change nothing in the repository; scratch work stays out of it, and read-only `drush` is
fine. Never write to the database either: no config or entity saves, no `php:eval` that
saves. To learn how a save behaves, read the code or a kernel test; the host reports any
config a planner leaves behind. No `bd` and no git writes. Follow the context budget below. Use `code-review` PLAN mode only when the task is
significant by the four questions of CLAUDE.md: the planners' time counts in the result.

Write `/var/www/html/arena-plan.md` in this order: outcome; the facts you verified, each
with the command or file that proves it; design and why it beats the alternatives you
rejected; data model and public interfaces; file tree; traps found in this codebase; tests;
live verification with exact commands and expected output; 3-6 yes/no rubric items; open
questions. No implementation bodies. A claim you did not check is labeled ASSUMED.

## Context budget (PLANNER and CANDIDATE)

Your session's context fills, then the harness compacts it: what you read is lost and read
again, and a compaction that does not fit ends the run with nothing reported. Keep your own
context for decisions.

- Reading belongs to subagents. An investigation that reads more than two or three files of
  core or contrib code, a schema, or a data sample goes to `code-explorer` (or the harness's
  explore subagent) with the exact question; keep only its answer and the `file:line` it cites.
- In your own session, `grep -n` first and then read only the range you need. Cap command
  output (`| head -n 40`, SQL `LIMIT 20`). Never print a whole config file, table, log, or
  `drush php` dump.
- Write a fact down once (the plan, the report, a scratch note under `/tmp`) instead of
  carrying it by re-reading.
- Run independent work in parallel: launch the subagents in one message, in the background
  (OpenCode: `background: true` on the `subagent` tool; Claude Code: several `Agent` calls
  in one message run at once), and collect every result before you go on. This holds while implementing,
  not only while planning: separate investigations, long test suites, the `code-review`
  pass, the browser check, and writing a test while you write the code it covers.
- Parallel work shares one worktree, one database and one site, so: never two writers on
  the same file; commands that change the site (`drush deploy`, `updb`, `cim`, `cr`, entity
  or config saves) run only in your own session, never in a parallel subagent; and never
  end your turn with a background subagent still running, because its work is lost.

## CANDIDATE (candidate container)

You are one of several. You do not know the others exist beyond that sentence, and you
never look for them. The brief at `/var/www/html/arena-brief.md` is the whole task.

1. Read the brief. Restate the outcome in one line; list ASSUMED items. If the brief
   can be read two ways or lacks a fact you need, write `STATUS: BLOCKED` with the
   exact question and what you would do under each answer, then stop. Guessing is the
   one way to fail here.
   If `/var/www/html/arena-approach.md` exists, it is your ASSIGNED APPROACH and binds
   like the contract: follow it even where you would choose differently, name it in
   SUMMARY, and if it cannot work here report `STATUS: BLOCKED` with why rather than
   switching approach silently.
2. Follow the matching playbook from the **task-playbooks** rule (usually Feature or Bug
   fix) with the contract as binding input. Delegate as usual (`code-explorer`,
   `drupal-dev`, `drupal-theme`, `drupal-test-generator`) and follow the context budget
   above: in an arena the run ends if your context does not fit. Every delegation brief starts with: "Arena candidate: no `bd`
   commands, no git writes, no task id, touch only <paths>".
3. Run the live verification the brief names and the quality checks; paste real
   output. "Inconclusive" is FAILED or PARTIAL, not DONE. Never change a test or its
   attributes to reach a gate's exact text: report the difference in DEVIATIONS.
   Then review your own diff: `code-review` CODE mode with the contract. Fix every finding
   you confirm and run the tests and the live verification again. Other models review your
   code after you, with your site running; what you catch here is the cheapest fix. List
   each finding under SELF-REVIEW, fixed or not and why: a DONE report without it fails the
   `report` gate.
4. Hard rules: no `bd`, no git writes, no `drush cex` unless the contract says so, only
   the listed paths. Report anything else you notice.
5. Make the FILES section match your working tree exactly: every changed or new path,
   nothing that does not exist, no scratch file left in the repository (keep those under
   `/tmp`). The host's `report` gate checks both directions and `promote` refuses undeclared
   files. Try `git status --short`, but `git` can fail in the container because the worktree
   points at a host path: do not repair it, list the paths from your own edits and say so
   in DEVIATIONS. RUBRIC
   answers come from YOUR diff and YOUR pasted output; "the other agent did it" or
   "unverified by me" is a `no` (there is no other implementer in your copy; a split in
   the brief is at most how you delegate internally).
6. Write `/var/www/html/arena-report.md`, STATUS on the first line:

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
SELF-REVIEW: <each finding of your own review: fixed (how) or not fixed (why), or "no findings">
```

Your last chat message is read by a script: after writing the report reply with one
line, `REPORT WRITTEN: <STATUS>`. When resumed with an answer or new instructions,
continue from where you stopped and rewrite the report at the end.

## GRAFTER (the winner's real environment, phased arena)

The list in `/var/www/html/arena-grafts/grafts.md` names what to port and from which label;
`<label>.patch` beside it is that label's whole diff. Port the idea into this code, one item
at a time, with its test. Skip an item that conflicts or no longer pays, and say why. Port
nothing else. Then rerun the contract's tests and live verification, and write the report.
No git writes: the user reviews the result here and commits it.

## REVIEWER (multi-model review of one diff)

`ai-arena review` sends the same diff to several reviewers on different harnesses and
models. You are one of them, blind to the others. Read the intent, the whole diff and
the surrounding code (callers, callees, types, tests) in the tree you were given; apply
the `code-review` CODE-mode rubric with its evidence rule (every finding: severity,
CONFIRMED or SUSPECTED, `file:line`, the failure scenario, the fix); look for the
structural simplification that makes branches or wrappers disappear; skip style nits.
The prompt says whether you have a running site. Without one, say what you would have run.
With one (you work inside the reviewed environment), use it: run the tests the change
touches and the brief's live verification, query with `ssh web drush`, open the pages, and
turn each finding into CONFIRMED or refuted by running it. Never change code, config or
modules there (no `cim`, `cex`, `en`, `pmu`, `updb`); probe content carries the prefix
`arena-review-` and is deleted when you finish; another reviewer may share the site. When
the intent names the arena brief (a review of one candidate, or the arena's final code), conformance with that
contract is part of the review: scope, rubric, required tests. When it names a previous
verdict, check first that each of its Act-on items is really fixed, then review in depth what
changed since that diff. The tree is read-only for you:
scratch files, test databases and probes go under `/tmp`, or they reach the branch. Write `## Verdict`,
`## Findings`, `## Not verified` to the output path you were given and reply
`REVIEW WRITTEN`.

## LEAD REVIEWER (synthesis of the reviews)

You merge the reviews into one verdict without knowing which model wrote which. Merge
duplicate findings and note which reviews raised each; two independent reviews agreeing
is the strongest signal, a lone finding with a concrete path still counts. Filter like a
lead: nitpick gravity, hypothetical versus actual (trace the call site), "I would have
done it differently" is not a finding, missing-context signals, premature abstraction;
never dismiss a security or correctness finding without checking it in the tree, which is
read-only for you too (probes and scratch databases go under `/tmp`). Output
`## Verdict`, `## Act on` (rarely more than five), `## Consider`, `## Noted`,
`## Dismissed` (one reason each), `## Agreement map`, then the trailer with
`VERDICT: JUDGED`.

## JUDGE (project manager, on collected candidates)

Inputs per label under `arena/<slug>/candidates/<label>/`: `diff.patch`, `report.md`,
`gates.json` (site, config, phpstan, phpcs, phpunit, report: pass|fail|skip; `report`
fails when the report's FILES and the changed files differ, in either direction), `gates/*.log`,
`files-changed.txt`, the SELF-REVIEW section of the report (what the author found and fixed),
and the reviews run with that label's site: `review-self.md` by a fresh session of the
author's model, `review-x1.md`... by different models. A label the prompt names as stopped at the deadline is unfinished. Labels are blind: you do not know, and must not guess, which
harness or model produced which.

1. **Gates first.** Read the logs. A failed gate cannot win over passing gates,
   whatever the report says; a failed `config` gate means the candidate left config
   changes in the database that the brief did not allow. `skip` means the gate did
   not apply; note it.
2. **Rubric second.** Score every label on every rubric item from the diff and the
   pasted evidence. A "yes" the diff or output does not show counts as "no".
3. **Contract conformance.** Silent deviations and scope creep are findings; reported
   deviations are judged on their merits.
4. **Reviews.** Treat each finding as a lead: confirm it in the diff, the code or the pasted
   output, or refute it in one line. Confirmed findings count in the ranking like your own.
   Found by both self and another: strongest. Found only by another model: the author's
   blind spot. A finding the SELF-REVIEW says was fixed must be fixed in the diff.
5. **Quality last.** Reader load, Drupal quality, the smallest change that meets the
   contract. Run `code-review` CODE mode over the finalists if you need a second pass.
   In APPROACHES MODE the labels were assigned their approaches: compare the approaches
   as implemented (conformance, size and reader load, test footprint, config churn, risk)
   and say which approach wins and why; never penalise a label for its assigned approach,
   only for abandoning it silently.
6. Exactly one winner; a label stopped at the deadline cannot be it. For each loser, cut ones
   included, at most one or two concrete grafts worth porting into the winner ("file, what,
   why"), or none. In a phased arena a grafter applies that list, so write it to
   `arena/<slug>/grafts.md`, adding each confirmed review finding on the winner as a
   fix. If no candidate is acceptable,
   `VERDICT: BLOCKED` with what is missing and which label is closest.

Reply with a scoring table (label × rubric item, plus gates), the ranking with one line
per label, the graft suggestions, then the trailer with `VERDICT: JUDGED` and
`WINNER: <label>`.
