---
description: PHPUnit test conventions — PHPDoc annotations, test types, TDD workflow
globs:
  - "**/*Test.php"
  - "**/*TestBase.php"
  - "**/tests/**"
---

# Testing Conventions

## PHPUnit Annotation Style (CRITICAL)

**ALWAYS use PHPDoc annotations** — NEVER PHP 8 attributes.
Drupal 10 uses PHPUnit 9.x (no attribute support). PHPDoc works in both Drupal 10 and 11.

| Use THIS (PHPDoc) | NOT this (PHP 8 attribute) |
|---|---|
| `@coversDefaultClass \My\Class` | `#[CoversClass(MyClass::class)]` |
| `@covers ::methodName` | `#[Covers('methodName')]` |
| `@group mymodule` | `#[Group('mymodule')]` |
| `@dataProvider providerName` | `#[DataProvider('providerName')]` |

## Test Type Selection

| Type | Use For | Speed | Database |
|------|---------|-------|----------|
| Unit | Pure PHP logic, no Drupal bootstrap | ~0.01s | No |
| Kernel | Services, entities, queries | ~0.5s | Yes |
| Functional | HTTP requests, forms, pages | ~2-5s | Yes |

**Rule: Use the FASTEST test type that covers the requirement.**

## Common Pitfalls

1. **Test behavior, not implementation** — assert on results, not internal method calls
2. **Don't over-mock** — only mock external dependencies (DB, HTTP, filesystem)
3. **No shared state** — never use static properties between tests
4. **No `sleep()`** — inject time as a dependency
5. **Use `setUp()` fresh** — create new state for each test
