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
docker exec $WEB_CONTAINER ./vendor/bin/drush status --field=drupal-version

# Check for uncommitted changes (STOP if dirty)
git status --porcelain

# Check available updates
docker exec $WEB_CONTAINER composer outdated --direct --format=json

# Check for pending database updates (should be clean)
docker exec $WEB_CONTAINER ./vendor/bin/drush updatedb:status
```

**STOP if**: Git working directory is dirty, DDEV not responding, or pending DB updates exist.

## Phase 2: Backup

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush sql:dump --result-file=/tmp/pre-update-backup.sql --gzip
git rev-parse HEAD  # Note for rollback
```

## Phase 3: Composer Updates

```bash
# Update everything
docker exec $WEB_CONTAINER composer update --with-all-dependencies

# Core only
docker exec $WEB_CONTAINER composer update "drupal/core-*" --with-all-dependencies

# Specific package
docker exec $WEB_CONTAINER composer update drupal/package_name --with-all-dependencies

# Security only
docker exec $WEB_CONTAINER composer audit
docker exec $WEB_CONTAINER composer update --with-all-dependencies $(docker exec $WEB_CONTAINER composer audit --format=json | jq -r '.advisories | keys | .[]')
```

## Phase 4: Database Updates

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush updatedb -y
docker exec $WEB_CONTAINER ./vendor/bin/drush cache:rebuild
```

## Phase 5: Configuration Sync

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush config:status
docker exec $WEB_CONTAINER ./vendor/bin/drush config:export -y
```

## Phase 6: Verification

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush core:status
docker exec $WEB_CONTAINER ./vendor/bin/drush watchdog:show --severity=error --count=10
docker exec $WEB_CONTAINER ./vendor/bin/drush core:requirements
docker exec $WEB_CONTAINER ./vendor/bin/phpunit -c $DDEV_DOCROOT/core $DDEV_DOCROOT/modules/custom --testdox 2>/dev/null || echo "No tests"
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
docker exec $WEB_CONTAINER composer install

# Restore database (if needed)
docker exec $WEB_CONTAINER gunzip -c /tmp/pre-update-backup.sql.gz | docker exec -i $WEB_CONTAINER ./vendor/bin/drush sql:cli

# Clear caches
docker exec $WEB_CONTAINER ./vendor/bin/drush cache:rebuild
```

## Error Handling

### Composer Conflicts
```bash
docker exec $WEB_CONTAINER composer why-not drupal/package_name:^X.Y
```

### Database Update Failures
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush sql:cli < /tmp/pre-update-backup.sql.gz
git checkout composer.lock
docker exec $WEB_CONTAINER composer install
```

## Command Reference

| Task | Command |
|------|---------|
| Check outdated | `docker exec $WEB_CONTAINER composer outdated --direct` |
| Security audit | `docker exec $WEB_CONTAINER composer audit` |
| Update all | `docker exec $WEB_CONTAINER composer update --with-all-dependencies` |
| Update core | `docker exec $WEB_CONTAINER composer update "drupal/core-*" --with-all-dependencies` |
| Backup DB | `docker exec $WEB_CONTAINER ./vendor/bin/drush sql:dump --result-file=/tmp/backup.sql --gzip` |
| Check requirements | `docker exec $WEB_CONTAINER ./vendor/bin/drush core:requirements` |
