---
name: drupal-verification-skill
description: >-
  Generates and maintains a PROJECT-LOCAL verification skill (`.claude/skills/verify-<site>/`)
  so any agent can drive THIS Drupal site the way a user does and prove behavior:
  launch/doctor checks, a feature map (routes, roles, content types, journeys) with
  exact Playwright MCP and drush recipes, evidence and cleanup rules. Use once per
  project, then periodically to keep the map honest.
  Examples:
  - user: "create a verification skill for this project" -> interview the repo, generate verify-<site>, prove it once
  - user: "crea el mapa de funcionalidades para verificar la web" -> feature map + recipes
  - user: "how do agents verify changes on this site?" -> point at or generate verify-<site>
  - user: "update the verify skill, the checkout changed" -> maintenance pass, one set of proven corrections
  Never use for one-off browser checks (playwright-testing skill) or to write Playwright
  test files (drupal-playwright-test skill).
allowed-tools: Bash Read Grep Glob Write Edit
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Verification Skill (generator + maintenance)

Agents that can verify their own work do not need the user as the bottleneck. This
skill writes the project's own `verify-<site>` skill: the recipes to launch, health
check, drive, and prove the site, plus a feature map an agent can read cold mid-task.
Everything is grounded in what the repo actually contains — no placeholders survive.

## Mode 1 — Generate (`.claude/skills/verify-<site>/`)

### Step 1: Interview the repo, not the user

Answer from the codebase; ask only what you cannot observe.

```bash
grep "^docroot:\|^name:\|^type:" .ddev/config.yaml            # site name, docroot
ssh web drush status --fields=drupal-version,bootstrap,db-status,uri
ssh web drush pm:list --status=enabled --type=module --format=list | head -80
ssh web drush config:get system.site page.front                # front page route
ssh web drush php:eval "foreach (\Drupal::entityTypeManager()->getStorage('node_type')->loadMultiple() as \$t) echo \$t->id().PHP_EOL;"
ssh web drush role:list --format=list
ls config/sync/views.view.*.yml 2>/dev/null | sed 's/.*views.view.//; s/.yml//'   # user-facing listings
grep -rn "^  path:" $DDEV_DOCROOT/modules/custom/*/*.routing.yml | grep -v "/admin/"   # custom public routes
ls tests/ $DDEV_DOCROOT/modules/custom/*/tests 2>/dev/null; ls playwright.config.* behat.yml 2>/dev/null
```

Record: surface (public site, editor UI, API, drush commands), how it starts (DDEV is
already up; note any `npm run build` for the theme, any required `drush deploy`),
how to authenticate (`ssh web drush uli --uri=$DDEV_HTTP_URL` for admin;
`drush uli --name=<user>` for a role-specific test user — create one with
`drush user:create` + `user:role:add` if the map needs it), seed data (which nodes,
which config), and isolation (one shared site: verification must restore the data it
mutates and never run two mutating drives at once).

If the site does not bootstrap (`drush status` red), fix or report that first — a
skill written against a broken base teaches wrong steps.

### Step 2: Write `SKILL.md` (the recipes)

Frontmatter: `name: verify-<site>`, `description` naming the site, its surface, and
when to reach for it (both languages). Body sections, each grounded in Step 1:

- **Launch** — DDEV up is the precondition; the exact extra commands (theme build,
  `drush cr`, `drush deploy`) and how to tell the site is ready (`drush status`
  `bootstrap: Successful`; Playwright `browser_navigate $DDEV_HTTP_URL` shows the
  front page title).
- **Doctor** — one read-only check to run whenever anything looks off. Ship it as an
  executable script, `scripts/doctor.sh`, not as a recipe: a script costs no tokens to
  follow and fails loudly. It runs `ssh web drush status --fields=bootstrap,db-status`
  and expects `Successful`/`Connected`, counts new errors in `ssh web drush
  watchdog:show --count=5 --severity=Error`, checks the test user with `ssh web drush
  user:information <name>`, and fetches the front page title through the web container
  (`ssh web curl -s $DDEV_HTTP_URL | grep -o '<title>[^<]*'`; this is a health probe,
  not page testing) against the expected value. Exit non-zero on the first mismatch
  with the check that failed. The SKILL.md body shows the invocation:

  ```bash
  bash .claude/skills/verify-<site>/scripts/doctor.sh   # prints one line per check, exit 0 when healthy
  ```
- **Drive** — how to interact: Playwright MCP tools (`browser_navigate`,
  `browser_snapshot`, `browser_click`, `browser_type`, `browser_take_screenshot`) with
  HTTP not HTTPS, stable handles (ARIA roles and accessible names, `data-drupal-selector`,
  route paths) over CSS positions; drush for state (`drush php:eval`, `config:get`,
  `sql:query`) — see the **playwright-testing** and **drush-commands** skills; never
  create Playwright script files, never curl pages.
- **Evidence** — what proves a claim: the action AND the resulting state (snapshot
  after the click, not only the final screenshot); side effects read back through
  drush (the node exists, the config value changed, the queue item was created, the
  watchdog has no new error); screenshots saved under `screenshots/` (mounted from
  the Playwright container) with the feature id in the file name. Exercise the real
  user path, not an internal setter or a test-only route.
- **Cleanup** — restore what the drive mutated (delete the created node by id, reset
  the config value, `drush cr`); never delete evidence; never run destructive drush
  commands (`sql:drop`, `site:install`, `config:import` on shared data) from a
  verification run.

### Step 3: Seed the feature map (`features/README.md` + one file per feature)

Follow `references/feature-map-example.md`. Start with the top 3-5 user-facing
features found in Step 1 (front page listing, a content type's create/edit/view path,
search, a form, login/roles, a custom route). Each feature file has an H1, one
paragraph of user-visible behavior, and exactly these H2s in order:

1. `Sub-features` — short ids, one line each.
2. `How to get to it (user POV)` — every entry point (menu, URL, keyboard, drush).
3. `Driving it with Playwright MCP and drush` — starts with `Preconditions:`, then
   labeled bullets pairing a user action with the exact tool call and the observable
   result.
4. `Gotchas` — traps that waste or invalidate a run (render cache, BigPipe placeholders,
   `#states` hiding not removing, Spanish UI strings being translations, role-gated
   entry points).

Keep implementation details out of the map: user paths, stable handles, required state,
commands, observable proof.

### Step 4: Prove the generated skill once

Run its own instructions end to end: launch, `scripts/doctor.sh`, drive ONE mapped feature, capture
evidence, clean up, confirm the evidence file still exists. Fix what fails. A skill
that was never executed is a draft, not a deliverable. Report the run output.

### Step 5: Hand over

The skill lives in the PROJECT (`.claude/skills/verify-<site>/`), is committed by the
user like any project file, and is loaded by both tools from there. Tell the user to
run the maintenance mode below when the site changes; suggest a cadence only if asked.

## Mode 2 — Maintain (keep the map honest)

Outcome is one of **clean** (no edits), **changed** (one set of proven corrections),
**blocked** (say exactly what blocked).

1. **Index hygiene**: `features/README.md` lists exactly the sibling files.
2. **Source wave**: for each feature file, delegate a read-only check to
   `code-explorer` — "does this feature still work as the file describes? cite
   route/template/form drift" — never drive the app from there.
3. **Reconcile**: spot-check cited drift; sweep recent churn (`git log --since=<last
   pass> --name-only -- $DDEV_DOCROOT/modules/custom $DDEV_DOCROOT/themes config/`)
   for user-facing surfaces missing from the map; require a concrete source path
   before adding one.
4. **Live pass**, required even when source looks clean: doctor, then drive every
   feature once, doctor again after any failed drive. A feature that cannot be reached
   is `verified-unreachable` only with the concrete prerequisite named; if the map
   omitted that prerequisite, that is drift.
5. **Triage**: wrong user-POV description → fix the map; working behavior the recipe
   cannot drive → fix the recipe; behavior actually broken → product bug, report it
   to the user (a Beads task), never paper over it in docs.
6. Edit only the verification skill's own directory. Never edit product code in a
   maintenance run.

## Rules

- Playwright navigation over `$DDEV_HTTP_URL` (HTTP); auth via `drush uli` with
  `https://` replaced by `http://`.
- Evidence survives cleanup; cleanup removes only what the run created.
- The map is the maintained source: a proof that drives one convenient entry point is
  incomplete when the map lists others.
