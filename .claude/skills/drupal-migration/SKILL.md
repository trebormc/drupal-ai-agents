---
name: drupal-migration
description: >-
  Handles Drupal content migrations: D7 to D10/D11 upgrades, custom migrations
  from external sources (CSV, JSON, API, SQL), Migrate API configuration,
  source/process/destination plugins, and incremental migration strategies.
  Examples:
  - user: "migrate content from D7 to D10" -> plan and implement migration
  - user: "create a migration from CSV" -> custom source plugin + YAML config
  - user: "upgrade from Drupal 7" -> plan and implement migration
  - user: "import data from external API" -> custom source plugin + YAML config
  Never run migrations on production without --limit testing first.
---

## Environment

All commands via `ssh web drush`.

## Required modules

```bash
ssh web composer require drupal/migrate_plus drupal/migrate_tools drupal/migrate_upgrade
ssh web drush en migrate migrate_plus migrate_tools -y
```

## Migration YAML structure

Place in `config/install/` or `migrations/` directory:

```yaml
id: my_migration
label: 'Migrate content from source'
migration_group: my_group
source:
  plugin: csv
  path: private://import/data.csv
  ids: [id]
  header_offset: 0
process:
  type:
    plugin: default_value
    default_value: article
  title: title
  body/value: body
  body/format:
    plugin: default_value
    default_value: basic_html
  field_date:
    plugin: format_date
    source: date
    from_format: 'm/d/Y'
    to_format: 'Y-m-d'
destination:
  plugin: 'entity:node'
migration_dependencies:
  required: []
  optional: []
```

## Common migration commands

| Task | Command |
|------|---------|
| List migrations | `ssh web drush migrate:status` |
| Run migration | `ssh web drush migrate:import my_migration` |
| Run with limit | `ssh web drush migrate:import my_migration --limit=10` |
| Rollback (undo imported rows) | `ssh web drush migrate:rollback my_migration` |
| Reset stuck "Importing" status | `ssh web drush migrate:reset-status my_migration` |
| Run all in group | `ssh web drush migrate:import --group=my_group` |
| Update existing | `ssh web drush migrate:import my_migration --update` |

## D7 to D10/D11 workflow

### Step 1: Generate migration config
```bash
ssh web drush migrate:upgrade --legacy-db-key=d7 --configure-only
```

### Step 2: Review and customize
```bash
ssh web drush cex -y
# Review migrate_plus.migration.* files in config/sync/
```

### Step 3: Test with limits
```bash
ssh web drush migrate:import upgrade_d7_node_article --limit=5
```

### Step 4: Verify and run full
```bash
ssh web drush migrate:import --all
```

## Custom source plugin template

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Plugin\migrate\source;

use Drupal\migrate\Plugin\migrate\source\SqlBase;
use Drupal\migrate\Row;

/**
 * @MigrateSource(id = "my_custom_source")
 */
final class MyCustomSource extends SqlBase {

  public function query(): \Drupal\Core\Database\Query\SelectInterface {
    return $this->select('source_table', 's')
      ->fields('s', ['id', 'title', 'body', 'created']);
  }

  public function fields(): array {
    return [
      'id' => $this->t('Unique ID'),
      'title' => $this->t('Title'),
    ];
  }

  public function getIds(): array {
    return ['id' => ['type' => 'integer']];
  }

  public function prepareRow(Row $row): bool {
    return parent::prepareRow($row);
  }

}
```

## Process plugin reference

| Plugin | Use case |
|--------|----------|
| `get` | Direct field mapping (default) |
| `default_value` | Set static value |
| `migration_lookup` | Reference migrated entity |
| `format_date` | Date format conversion |
| `entity_generate` | Create referenced entity if missing |
| `callback` | PHP callback transformation |
| `static_map` | Value mapping table |
| `skip_on_empty` | Skip row if source empty |

## Related Skills

- **drupal-testing** — Create PHPUnit tests for migration source plugins and process logic
- **drupal-debugging** — Debug migration errors, inspect entities, check watchdog logs

## Verification (after EVERY import)

```bash
# 1. Check status: Imported count must be > 0 and Status must be "Idle"
ssh web drush migrate:status --format=table

# 2. Verify migrated content count matches expectations
ssh web drush sqlq "SELECT COUNT(*) FROM node WHERE type = 'article'"

# 3. Check for migration errors
ssh web drush migrate:messages my_migration
ssh web drush ws --count=10 --severity=Error
```

## If a migration fails

| Symptom | Fix |
|---------|-----|
| Status stuck at "Importing" | `ssh web drush migrate:reset-status my_migration`, then re-import |
| Wrong/partial data imported | `ssh web drush migrate:rollback my_migration`, fix the migration config, re-import with `--limit=5` first |
| Source DB connection error | Verify the `d7` database key exists in settings.php and the source DB is reachable |
| Row-level errors | Read them with `ssh web drush migrate:messages my_migration` and fix the process pipeline for those fields |
