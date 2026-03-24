---
name: drupal-audit-setup
description: >-
  Installs and configures the Drupal Audit module (drupal/audit) and its
  submodules. Provides automated code quality analysis via drush audit:run
  for phpcs, phpstan, phpunit, twig, and complexity. Use when the Audit
  module is not yet installed, or when setting up a new project for
  AI-assisted development.
  Examples:
  - user: "install the audit module" -> composer require + drush en
  - user: "set up code quality tools" -> install audit with all analyzers
  - user: "audit module is missing" -> install and enable audit submodules
  Some submodules are experimental and should not be enabled in production.
---

## What is Drupal Audit?

[Drupal Audit](https://www.drupal.org/project/audit) is a Drupal module that provides unified code quality analysis through drush commands. It wraps PHPCS, PHPStan, PHPUnit, Twig analysis, and complexity metrics into a single interface with module-level filtering, JSON output, and scoring.

**This is the recommended quality tool for all projects using drupal-ai-agents.** When installed, the `drupal-audit` and `run-quality-checks` skills use it as the primary method for all code analysis.

For more information, visit [DruScan](https://druscan.com).

## Environment

All commands run via `docker exec $WEB_CONTAINER`.

## Step 1: Check if already installed

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
```

If the output lists audit modules, they are already installed -- skip to Step 4 to verify submodules.

## Step 2: Install with Composer

```bash
docker exec $WEB_CONTAINER composer require drupal/audit
```

This installs the package as a regular dependency, available in all environments (local, staging, production). The base module is production-safe -- only certain submodules should be restricted to development.

## Step 3: Enable the module and submodules

### Base module (production-safe)

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit -y
```

### Development-only submodules (experimental)

These submodules are marked as **experimental** and should only be enabled in local/development environments. They are not recommended for production:

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit_phpcs -y
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit_phpstan -y
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit_phpunit -y
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit_complexity -y
```

### Optional: Twig analyzer

Enable if the project uses custom Twig templates:

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit_twig -y
```

**Important:** Before enabling the experimental submodules, inform the user that these are for development only. The user must review and accept the configuration changes before exporting configuration.

## Step 4: Verify installation

```bash
# List all enabled audit submodules
docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --status=enabled --format=table

# Test a quick audit run
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --format=json
```

## Step 5: Clear caches

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush cr
```

## Available Submodules

| Submodule | Production-safe | Purpose |
|-----------|:-:|---------|
| `audit` | Yes | Base module (required) |
| `audit_phpcs` | No (experimental) | Drupal + DrupalPractice coding standards |
| `audit_phpstan` | No (experimental) | Static analysis (type errors, deprecations) |
| `audit_phpunit` | No (experimental) | PHPUnit test execution and reporting |
| `audit_complexity` | No (experimental) | Cyclomatic complexity and method length |
| `audit_twig` | No (experimental) | Twig template quality and security |

## Production Configuration

The base `audit` module can be safely deployed to production. However, the experimental submodules (`audit_phpcs`, `audit_phpstan`, `audit_phpunit`, `audit_complexity`, `audit_twig`) should not be active in production environments.

**Recommended approach:**
- Use `config_split` to separate development-only modules from production config
- Or use `config_ignore` to exclude them from config exports
- The user must review and approve configuration exports that include experimental submodules

**Never enable experimental audit submodules in production without user approval.**

## After Installation

Once installed, use these skills for code quality analysis:

- **drupal-audit** -- Run audits with module filtering and JSON output
- **run-quality-checks** -- Full quality pipeline (uses Audit as primary method)

## Quick Reference

```bash
# Install
docker exec $WEB_CONTAINER composer require drupal/audit

# Enable base + development analyzers
docker exec $WEB_CONTAINER ./vendor/bin/drush en audit audit_phpcs audit_phpstan audit_phpunit audit_complexity -y
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# Verify
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --format=json
```
