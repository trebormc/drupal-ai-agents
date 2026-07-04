---
name: phpstan-phpcs-conflict-resolution
description: >-
  Resolves genuine conflicts between Drupal coder (PHPCS) and PHPStan level 8, and
  encodes the non-obvious mechanics of PHPStan suppressions in Drupal codebases. Use
  when the two tools give contradictory instructions on the same line, when a
  `@phpstan-ignore` "does not work", or on hook-docblock / missingType conflicts.
  Examples:
  - user: "phpstan and phpcs keep fighting over this hook" -> apply the hook-docblock recipe
  - user: "my @phpstan-ignore does not work" -> single-line the statement + ignore-next-line
  - user: "fix the conflict between phpcs and phpstan" -> pick the real contract, suppress the other narrowly
  - user: "missingType error on my .module hooks" -> ignore missingType.iterableValue for hook files
  Never use for running the full quality pipeline (use quality-checks). Never use for
  first-time tool setup (use the quality-tools-setup rule).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# PHPStan ↔ PHPCS Conflict Resolution

When both tools flag the same line they can demand OPPOSITE changes. Fixing one then
re-triggers the other — an infinite alternation. This skill encodes the resolutions
that survive BOTH tools at zero, plus the suppression mechanics that make
`@phpstan-ignore` behave. All commands via `ssh web`.

## Golden rule

Determine which tool's complaint reflects a REAL contract (read the code that calls or
implements the line). Satisfy that one; suppress the OTHER as narrowly as possible with
a comment stating why. Alternate-fixing without this analysis is the failure mode this
skill exists to prevent.

## Recipe 1 — Hook docblocks: "no @param" vs "type the array"

Coder warns *"Hook implementations should not duplicate @param/@return"*; PHPStan level 8
raises `missingType.iterableValue` on the same hooks. `{@inheritdoc}` does NOT satisfy
PHPStan (procedural hooks inherit nothing). Core's approach wins: remove the docs, ignore
the rule for hook files in `phpstan.neon`:

```neon
ignoreErrors:
  -
    identifier: missingType.iterableValue
    paths: ['*.module', '*.install', '*.theme']
```

phpstan-drupal DOES analyze `.module/.install/.theme` (it extends fileExtensions), so run
a targeted analyse to confirm the ignore matches — do not assume they are excluded.

## Recipe 2 — Native type hints vs mockability

Narrowing `object $x` to a concrete class (e.g. `\Drupal\Core\Extension\Extension`)
silences PHPStan `method.notFound` but throws `TypeError` in unit tests that inject
anonymous-class mocks. Keep the native `object`; suppress per call line with a targeted
`// @phpstan-ignore method.notFound`. Never let a static-analysis pass change a runtime
signature that tests depend on. Run the unit suite after every PHPStan batch.

## Recipe 3 — By-reference docblock variance

Two methods sharing a by-ref accumulator MUST declare the identical array type, or the
wider one re-widens the variable between iterations and the stricter one errors at the
call site. Overriding `ConfigFormBase::validateForm()` with `@param array<string, mixed> $form`
conflicts with the parent's plain `array` by-ref contract — `array<mixed>` satisfies both
`missingType` and variance.

## Recipe 4 — Suppression mechanics (why "@phpstan-ignore doesn't work")

- `// @phpstan-ignore <id>` appended at the END of a line matches errors on THAT line; on
  its OWN line it matches the NEXT line only. For MULTILINE chained statements the error may
  attach to a line the comment cannot reach: collapse the statement to one line, then use
  `// @phpstan-ignore-next-line` placed AFTER any `/** @var */` docblock.
- One line can carry MULTIPLE errors of the same identifier (unknown-class `@var` AND
  method-on-unknown-class); a single ignore suppresses only one of them.
- With `reportUnmatchedIgnoredErrors: false`, misplaced ignores fail SILENTLY. Re-run and
  diff the error list after adding each one.
- Assertion identifiers differ by call type (`method.impossibleType` vs
  `staticMethod.impossibleType`). Get the exact identifier from `--error-format=json`,
  never guess.
- Docblocks on ANONYMOUS-class methods parse unreliably for nested generics — simplify to
  `array<string, mixed>` / `array<int, T>` instead of fighting the parser.

## Field notes

- `sed`-style line numbers drift off-by-one; place line-sensitive comments only after
  confirming the number with a line-numbered Read of the file.
- `Xss::filterAdmin()` + `Markup::create()` returns `MarkupInterface|string` (an empty
  string passes through) — type returns accordingly. The concrete `Markup` class lives in
  `Drupal\Core\Render`, not `Drupal\Component\Render` (only the interface/trait live there).

## Verification

Both tools at ZERO in the same run, AND the unit suite green — all three, every time
(each recipe was discovered when fixing one tool broke another):

```bash
ssh web ./vendor/bin/phpcs --standard=Drupal,DrupalPractice <TARGET>
ssh web ./vendor/bin/phpstan analyse <TARGET>        # add --error-format=json to read identifiers
ssh web ./vendor/bin/phpunit <TARGET>/tests/src/Unit
```
