---
name: drupal-test-suite-audit
description: >-
  Audits and refactors an EXISTING Drupal test suite: removes zero-value tests, unifies
  duplicated scaffolding, converts fragile DB-simulation unit tests to kernel tests, and
  closes the dependency-injection coverage gap with kernel smoke tests. Complements the
  drupal-testing family (which writes NEW tests). Use to review, simplify, or improve the
  QUALITY of a suite that already exists.
  Examples:
  - user: "review the tests in this module" -> run the quantitative survey, then refactor
  - user: "we have too many unit tests, simplify them" -> delete tautological, unify helpers
  - user: "audit the test suite" -> full 6-step audit
  - user: "our plugins' create() is never tested" -> generate kernel smoke tests
  Never use to write tests for NEW code (use drupal-testing / drupal-kernel-test /
  drupal-unit-test). Never delete a test without the override guard in Step 2.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# Drupal Test-Suite Audit

Refactors an existing suite for value and maintainability. Measure BEFORE touching
anything; verify (unit+kernel+functional, PHPCS, PHPStan) after EVERY batch. All commands
via `ssh web`.

## Step 1 — Quantitative survey (no edits yet)

```bash
# Copy-paste tests: same test-method name across many files
grep -rh "public function test" $DDEV_DOCROOT/modules/custom --include=*Test.php | sort | uniq -c | sort -rn
# Anonymous-class doubles per file
grep -rln "new class" $DDEV_DOCROOT/modules/custom --include=*Test.php
```

Classify each `new class`: those that simulate DB/entity queries
(`fetchAll|fetchField|->select(|StatementInterface`) → convert to kernel; those that stub
binary execution → legitimate, keep. Count duplicated private helpers
(`invokeProtectedMethod`, `setProtectedProperty`) and confirm the bodies are byte-identical
before planning a shared trait.

## Step 2 — Delete tautological tests (with the guard)

Candidates: per-plugin tests re-asserting BASE-class behavior already covered by a
base-class test (label/description/output-dir fallbacks, default `checkRequirements()`,
passthrough methods), and attribute-string assertions against copies of themselves.

**GUARD (mandatory):** before deleting a "default behavior" test, grep whether the class
under test OVERRIDES that method. If it does, the test exercises the override's default
branch — keep it.

## Step 3 — Unify scaffolding

Move byte-identical reflection helpers into ONE trait in the base module's test namespace
(`Drupal\Tests\<module>\Unit\...Trait`); submodule tests can use it because core's bootstrap
registers every module's test namespace. Replace only exact-match bodies; leave variants
alone (a same-named method legally overrides the trait, so partial adoption is safe).

## Step 4 — Kernel smoke tests: the DI-wiring gap

Unit tests that `new` a plugin and inject deps via reflection NEVER execute `create()` — a
typo'd service ID passes the whole unit suite and explodes in production. Generate an
abstract `...KernelTestBase` with 4 generic tests:

1. plugin is discoverable + instantiable THROUGH the container;
2. checks/definition contract is well-formed;
3. config form builds against real config;
4. full main-operation cycle returns the documented structure, JSON-serializable.

Plus a ~20-line subclass per plugin declaring `$modules` and the plugin ID. Mark test 4
skipped for plugins that shell out to external binaries.

Base-class field notes: assert only the REAL contract — read the consumer before requiring
keys (a documented `weight` key turned out unused by the renderer). Support legacy result
contracts if a normalizer accepts them. PHPStan rejects tautological assertions
(`assertIsArray()` on a `: array` method); `assertContainsOnly()` is deprecated in PHPUnit
11.5 and absent in 9 — use `assertCount(count($x), array_filter($x, 'is_array'))`
(version-safe).

## Step 5 — Shared configurable doubles for binary wrappers

Replace per-test anonymous subclasses with ONE final double per analyzer: constructor copies
state from a configured instance + a stub map (`method => value | Closure`). Learned the hard
way:

- Reflect on the PARENT CLASS (`new \ReflectionClass(TheClass::class)`), not the instance —
  else you copy another double's extra properties → dynamic properties (deprecated since
  PHP 8.2, removed in PHP 9).
- Skip uninitialized typed properties (`$property->isInitialized($parent)`).
- Bind closures to the double (`\Closure::bind($fn, $this, static::class)`) so stub bodies
  using `$this` keep working; therefore stubs must be plain `function`, not `static fn`.
- Convert mechanically only sites whose constructor matches the canonical clone pattern
  (normalize whitespace before comparing); leave arg-capturing anonymous classes — a few
  exceptions are fine.

## Step 6 — Verify and document

After EVERY batch (never accumulate unverified batches):

```bash
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/<module>/tests/src/Unit
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/<module>/tests/src/Kernel
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/<module>/tests/src/Functional
ssh web ./vendor/bin/phpcs --standard=Drupal,DrupalPractice $DDEV_DOCROOT/modules/custom/<module>
ssh web ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom/<module>
```

(If there is no project-root `phpunit.xml`, use Form CORE from the **drupal-testing** skill.)
Compare the test COUNT before/after each deletion batch: it must drop by exactly the number
of deleted tests — any other delta means something else broke. Write the resulting
conventions (what not to re-add, where the shared pieces live) into the repo's
technical-debt/conventions doc so the cleanup does not regress.

## Decision rules (state these up front)

- DB/entity-query simulation with anonymous classes → convert to kernel.
- Binary-execution stubs → keep as unit doubles (kernel would run the real tools).
- Never narrow a native param type to satisfy PHPStan where tests inject structural mocks —
  use docblocks or targeted ignores (see **phpstan-phpcs-conflict-resolution**).
- New tests enter through the PUBLIC API; reflection on protected methods is legacy to reduce
  opportunistically, not a pattern to extend.
