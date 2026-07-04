---
name: drupal-security-coverage-prep
description: >-
  Audits a contrib module against the drupal.org security review checklist before applying
  for security advisory coverage (the "vetted" role project application). Finds and fixes the
  code patterns human reviewers reject. Use before opting a module into security coverage or
  requesting drupal.org security review.
  Examples:
  - user: "prepare this module for security coverage" -> run the sweep + fix defects
  - user: "I want to opt into security coverage on drupal.org" -> checklist + report
  - user: "security review before I apply for the vetted role" -> full audit
  - user: "review the module's security before publishing it" -> greps + access tests + report
  Never use for writing new secure code from scratch (use the security-rules rule). Never use
  for general code quality (use quality-checks).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# Drupal Security Coverage Prep

Walks an EXISTING module through the drupal.org reviewer checklist. All commands via
`ssh web`; grep the module source directly. Report each finding as defect / verified-safe /
process-gap.

## Step 1 — Process requirements (report, do not fix)

Code work is wasted if these are missing:

- FULL project (not sandbox) with a STABLE release (`1.0.0` / `8.x-1.0`). Coverage NEVER
  applies to dev/alpha/beta/RC.
- No open issues tagged "security" in the project queue.
- New projects wait 10 days before opting in.
- The maintainer applies for the vetted role via the project application queue (that
  application IS the human code review), then opts in on the project page.

## Step 2 — Automated code sweep (severity order)

1. **State-changing GET routes** — for every `*.routing.yml` route whose controller mutates
   state (runs processes, saves config/state, deletes), require `_csrf_token: 'TRUE'`. Drupal
   appends the token automatically to `Url::fromRoute()` links, so usually no controller
   change is needed. Add a functional test asserting BOTH: a tokenless direct request → 403
   even WITH permission, AND the generated link contains `?token=`.
2. **`|raw` in Twig** — replace with autoescaping; for module-generated HTML, filter with
   `Xss::filterAdmin()` and wrap in `\Drupal\Core\Render\Markup` at the builder/assembly layer
   so templates stay escape-by-default. Concatenated attribute strings → inline attributes or
   `Attribute` objects.
3. **SQL** — every `->query()` uses placeholders; no interpolated values (incl.
   `information_schema` queries).
4. **`unserialize()`** — must pass `['allowed_classes' => [...]]` (explicit allowlist or FALSE).
   Comment WHY those classes — reviewers ask.
5. **Process execution** — `Symfony\Component\Process\Process` with ARRAY commands only.
   `shell_exec()/exec()` acceptable only with fixed literal commands + an availability guard;
   any variable interpolation is a defect.
6. **Dangerous functions** — `eval(`, `system(`, `passthru(`, backticks, direct
   `$_GET/$_POST/$_REQUEST` access → all defects.
7. **Permissions** — every route has `_permission`/`_entity_access`; admin-level permissions
   declare `restrict access: true` in `*.permissions.yml`.
8. **Route parameters** — invalid values must yield `NotFoundHttpException` (404), not a
   rendered 200 error page.

```bash
M=$DDEV_DOCROOT/modules/custom/<module>
# 2: raw output in templates
grep -rn "|raw" "$M" --include=*.twig
# 3: interpolated SQL (review every hit manually)
grep -rn "query(" "$M" --include=*.php --include=*.module --include=*.install
# 4: unserialize without allowlist
grep -rn "unserialize(" "$M"
# 5+6: dangerous functions (word boundary avoids false hits like filesystem();
#      backtick = shell execution operator in PHP)
grep -rEn "\b(eval|system|passthru|shell_exec|exec|proc_open|popen)\s*\(" "$M" --include=*.php --include=*.module --include=*.install
grep -rn '`' "$M" --include=*.php --include=*.module
grep -rEn "\\\$_(GET|POST|REQUEST)\b" "$M"
# 7: routes with no real access control, and CSRF coverage
grep -rn "_access: 'TRUE'" "$M"/*.routing.yml
grep -rn "_csrf_token" "$M"/*.routing.yml
```

Grep output is a CANDIDATE list, not a verdict: read each hit and classify it. A
`_access: 'TRUE'` route is a defect unless the controller enforces access itself
(document the argument in the report).

## Step 3 — Access-control functional tests

If absent, generate a `BrowserTestBase` test asserting 403/200/404 per route for: anonymous,
authenticated-without-permission, and each defined permission (use the
**drupal-functional-test** skill for the class scaffolding). Cheap, and the evidence
reviewers like most.

## Step 4 — Report

Table: defect / verified-safe (with the defense argument) / process gap. Explicitly list what
coverage EXCLUDES so the user calibrates: external binaries and libraries, vulnerabilities
requiring admin permissions, sandbox projects.

## Pitfalls learned in the field

- Admin-configurable binary paths (run via Process) are acceptable ONLY because the permission
  gating them declares `restrict access: true` — check that pairing explicitly.
- A GET route that "just recalculates" (re-runs analysis and persists a score) IS
  state-changing; do not exempt it because it looks like a view.
- `Markup::create('')` returns a plain string, and the concrete `Markup` class lives in
  `Drupal\Core\Render`, not `Drupal\Component\Render` (only the interface/trait live there).

## Verification

The functional suite + the sweep greps re-run clean. PHPCS/PHPStan stay at zero after fixes
(the fixes touch templates + routing, both covered by the Drupal standard).
