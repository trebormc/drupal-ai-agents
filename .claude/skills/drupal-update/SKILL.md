---
name: drupal-update
description: >-
  Safe Drupal update workflow: Composer updates, database updates, config sync.
  Handles core, contrib, and security-only updates. Pre-flight checks, backups,
  rollback procedures. Use when updating Drupal packages, applying security
  patches, or running composer update safely.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Update Workflow

Execute updates following this EXACT sequence.

## Phase 1: Pre-flight Checks

```bash
# Verify DDEV and Drupal version
ssh web ./vendor/bin/drush status --field=drupal-version

# Check for uncommitted changes (STOP if dirty)
git status --porcelain

# Check available updates
ssh web composer outdated --direct --format=json

# Check for pending database updates (should be clean)
ssh web ./vendor/bin/drush updatedb:status
```

**STOP if**: Git working directory is dirty, DDEV not responding, or pending DB updates exist.

## Phase 2: Backup

```bash
ssh web ./vendor/bin/drush sql:dump --result-file=/tmp/pre-update-backup.sql --gzip
git rev-parse HEAD  # Note for rollback
```

## Phase 3: Composer Updates

```bash
# Update everything
ssh web composer update --with-all-dependencies

# Core only
ssh web composer update "drupal/core-*" --with-all-dependencies

# Specific package
ssh web composer update drupal/package_name --with-all-dependencies

# Security only
ssh web composer audit
ssh web composer update --with-all-dependencies $(ssh web composer audit --format=json | jq -r '.advisories | keys | .[]')
```

## Phase 4: Database Updates

```bash
ssh web ./vendor/bin/drush updatedb -y
ssh web ./vendor/bin/drush cache:rebuild
```

## Phase 5: Configuration Sync

```bash
ssh web ./vendor/bin/drush config:status
ssh web ./vendor/bin/drush config:export -y
```

## Phase 6: Verification

```bash
ssh web ./vendor/bin/drush core:status
ssh web ./vendor/bin/drush watchdog:show --severity=error --count=10
ssh web ./vendor/bin/drush core:requirements
ssh web ./vendor/bin/phpunit -c $DDEV_DOCROOT/core $DDEV_DOCROOT/modules/custom --testdox 2>/dev/null || echo "No tests"
```

## Phase 7: Present Summary

**DO NOT commit automatically.** Present changes for user review with:
- List of updated packages (from → to)
- Database updates executed
- Config changes exported
- Suggested commit message

## Rollback Procedure

```bash
# Reset Git changes
git checkout composer.json composer.lock config/sync/

# Restore composer packages
ssh web composer install

# Restore database (if needed)
ssh web gunzip -c /tmp/pre-update-backup.sql.gz | ssh web ./vendor/bin/drush sql:cli

# Clear caches
ssh web ./vendor/bin/drush cache:rebuild
```

## Error Handling

### Composer Conflicts
```bash
ssh web composer why-not drupal/package_name:^X.Y
```

### Database Update Failures
```bash
ssh web ./vendor/bin/drush sql:cli < /tmp/pre-update-backup.sql.gz
git checkout composer.lock
ssh web composer install
```

## Command Reference

| Task | Command |
|------|---------|
| Check outdated | `ssh web composer outdated --direct` |
| Security audit | `ssh web composer audit` |
| Update all | `ssh web composer update --with-all-dependencies` |
| Update core | `ssh web composer update "drupal/core-*" --with-all-dependencies` |
| Backup DB | `ssh web ./vendor/bin/drush sql:dump --result-file=/tmp/backup.sql --gzip` |
| Check requirements | `ssh web ./vendor/bin/drush core:requirements` |
