---
name: drupal-migration
description: >-
  Handles Drupal content migrations: D7 to D10/D11 upgrades, custom migrations
  from external sources (CSV, JSON, API, SQL), Migrate API configuration,
  source/process/destination plugins, and incremental migration strategies.
  Examples:
  - user: "migrate content from D7 to D10" -> plan and implement migration
  - user: "create a migration from CSV" -> custom source plugin + YAML config
  - user: "migrar contenido de D7" -> plan and implement migration
  - user: "importar datos desde CSV" -> custom source plugin + YAML config
  Never run migrations on production without --limit testing first.
---

## Environment

All commands via `docker exec $WEB_CONTAINER ./vendor/bin/drush`.

## Required modules

```bash
docker exec $WEB_CONTAINER composer require drupal/migrate_plus drupal/migrate_tools drupal/migrate_upgrade
docker exec $WEB_CONTAINER ./vendor/bin/drush en migrate migrate_plus migrate_tools -y
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
| List migrations | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:status` |
| Run migration | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import my_migration` |
| Run with limit | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import my_migration --limit=10` |
| Rollback | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:rollback my_migration` |
| Reset stuck | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:reset my_migration` |
| Run all in group | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import --group=my_group` |
| Update existing | `docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import my_migration --update` |

## D7 to D10/D11 workflow

### Step 1: Generate migration config
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:upgrade --legacy-db-key=d7 --configure-only
```

### Step 2: Review and customize
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush cex -y
# Review migrate_plus.migration.* files in config/sync/
```

### Step 3: Test with limits
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import upgrade_d7_node_article --limit=5
```

### Step 4: Verify and run full
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:import --all
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

## Verification

```bash
# Check migration status after run
docker exec $WEB_CONTAINER ./vendor/bin/drush migrate:status --format=table

# Verify migrated content count
docker exec $WEB_CONTAINER ./vendor/bin/drush sqlq "SELECT COUNT(*) FROM node WHERE type = 'article'"
```
