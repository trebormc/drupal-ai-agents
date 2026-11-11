---
name: drupal-update
description: >-
  Safe Drupal update workflow: Composer updates, database updates, config sync.
  Handles core, contrib, and security-only updates. Pre-flight checks, backups,
  rollback procedures. Use when updating Drupal packages, applying security
  patches, or running composer update safely.
  Examples:
  - user: "update Drupal core" -> pre-flight, backup, core-only composer update, updb, verify
  - user: "apply the security updates" -> composer audit, update only the advised packages
  - user: "update the webform module" -> single-package update with rollback point
  Never use for a major-version upgrade (10 to 11: use drupal-multi-version-compat
  to prepare the code) or for adding a new package (plain composer require).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Update Workflow

Run the phases in this order: each one is the safety net for the next.

## Phase 1: Pre-flight Checks

```bash
# Verify DDEV and Drupal version
ssh web drush status --field=drupal-version

# Check for uncommitted changes (STOP if dirty)
git status --porcelain

# Check available updates
ssh web composer outdated --direct --format=json

# Check for pending database updates (should be clean)
ssh web drush updatedb:status
```

**STOP if**: Git working directory is dirty, DDEV not responding, or pending DB updates exist.

## Phase 2: Backup

```bash
ssh web drush sql:dump --result-file=/tmp/pre-update-backup.sql --gzip
git rev-parse HEAD  # Note for rollback

# VERIFY the backup before continuing (file exists and is non-empty):
ssh web test -s /tmp/pre-update-backup.sql.gz && echo "BACKUP OK" || echo "STOP: backup failed"
```

If the output is not "BACKUP OK", stop and tell the user the backup failed: without it there is no rollback.

## Phase 3: Composer Updates

Pick ONE variant:

```bash
# Update everything — routine maintenance window, full regression test planned
ssh web composer update --with-all-dependencies

# Core only — when you only want the Drupal core release (safest scope)
ssh web composer update "drupal/core-*" --with-all-dependencies

# Specific package — targeted fix or single contrib update
ssh web composer update drupal/package_name --with-all-dependencies

# Security only — when the goal is just to patch advisories.
# The guard matters: with an empty package list, `composer update` updates everything.
ssh web composer audit
PKGS=$(ssh web composer audit --format=json | jq -r '.advisories | keys | .[]')
if [ -n "$PKGS" ]; then
  ssh web composer update --with-all-dependencies $PKGS
else
  echo "No advisories: nothing to update"
fi
```

## Phase 4: Database Updates

```bash
ssh web drush updatedb -y
ssh web drush cache:rebuild
```

## Phase 5: Configuration Sync

```bash
ssh web drush config:status
ssh web drush config:export -y
```

## Phase 6: Verification

```bash
ssh web drush core:status
ssh web drush watchdog:show --severity=error --count=10
ssh web drush core:requirements

# Run custom module tests if any exist (Form ROOT shown; if no project phpunit.xml,
# use the canonical Form CORE pattern from the drupal-testing skill):
# Do not append `|| echo`: a failing suite must show as a failure, not as "no tests".
if ssh web "find $DDEV_DOCROOT/modules/custom -path '*/tests/src/*' -name '*Test.php' | grep -q ."; then
  ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom --testdox
else
  echo "No custom module tests found"
fi
```

## Phase 7: Present Summary

**Follow the git-workflow rule** (by default, do not commit automatically). Present changes for user review with:
- List of updated packages (from → to)
- Database updates executed
- Config changes exported
- Suggested commit message

## Rollback Procedure

Unless the **git-workflow** rule enables git operations, `git checkout` must be run BY THE USER. Give the user step 1 (or run it yourself only if operations are enabled), then run steps 2-4 yourself:

```bash
# 1. ASK THE USER to run on the host:
#    git checkout composer.json composer.lock config/sync/

# 2. Restore composer packages
ssh web composer install

# 3. Restore database (if needed)
ssh web 'gunzip -c /tmp/pre-update-backup.sql.gz | drush sql:cli'

# 4. Clear caches
ssh web drush cache:rebuild
```

## Error Handling

### Composer Conflicts

```bash
# Find what blocks the update:
ssh web composer why-not drupal/package_name:^X.Y
```

Then either update the blocking package FIRST (`ssh web composer update <blocker> --with-all-dependencies`) or report the conflict to the user. Do not use `--ignore-platform-reqs` or `--force` as a workaround: they install a combination Composer has just told you is broken.

### Database Update Failures

Run the Rollback Procedure above (restore DB from the verified backup, then have the user reset composer files).

## Command Reference

| Task | Command |
|------|---------|
| Check outdated | `ssh web composer outdated --direct` |
| Security audit | `ssh web composer audit` |
| Update all | `ssh web composer update --with-all-dependencies` |
| Update core | `ssh web composer update "drupal/core-*" --with-all-dependencies` |
| Backup DB | `ssh web drush sql:dump --result-file=/tmp/backup.sql --gzip` |
| Check requirements | `ssh web drush core:requirements` |
