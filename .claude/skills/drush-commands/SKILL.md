---
name: drush-commands
description: >-
  Executes Drupal Drush commands for cache clearing, database updates, module
  management, cron, watchdog logs, and site maintenance. Use when user needs
  any Drush operation. Use proactively after code changes to clear caches or
  run database updates.
  Examples:
  - user: "clear cache" -> run drush cr via ssh web
  - user: "enable my module" -> run drush en module_name via ssh web
  - user: "clear cache" -> run drush cr via ssh web
  - user: "update the database" -> run drush updb via ssh web
  Never use for config export/import workflows (use drupal-config-management).
---

## Environment

All Drush commands run via `ssh web ./vendor/bin/drush`.
NEVER use just `drush` — it will not be found without the full vendor path.

## Common operations

| Task | Command |
|------|---------|
| Clear all caches | `ssh web ./vendor/bin/drush cr` |
| Run database updates | `ssh web ./vendor/bin/drush updb -y` |
| Enable module | `ssh web ./vendor/bin/drush en <module> -y` |
| Uninstall module | `ssh web ./vendor/bin/drush pmu <module> -y` |
| Check Drupal status | `ssh web ./vendor/bin/drush status` |
| Run cron | `ssh web ./vendor/bin/drush cron` |
| One-time login | `ssh web ./vendor/bin/drush uli` |
| List enabled modules | `ssh web ./vendor/bin/drush pm:list --status=enabled` |
| Check pending updates | `ssh web ./vendor/bin/drush updb --no` |
| Watchdog logs | `ssh web ./vendor/bin/drush ws --count=20` |
| Rebuild permissions | `ssh web ./vendor/bin/drush php-eval "node_access_rebuild();"` |
| Locale update | `ssh web ./vendor/bin/drush locale:check && ssh web ./vendor/bin/drush locale:update` |

## After code changes (mandatory order)

1. `ssh web ./vendor/bin/drush updb -y` (apply hook_update_N)
2. `ssh web ./vendor/bin/drush cim -y` (import config changes)
3. `ssh web ./vendor/bin/drush cr` (rebuild caches)

## Custom Drush commands (Drush 12+)

Place in `src/Commands/` using attribute pattern:

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Commands;

use Drush\Attributes as CLI;
use Drush\Commands\DrushCommands;

final class MyModuleCommands extends DrushCommands {

  #[CLI\Command(name: 'mymodule:process')]
  #[CLI\Help(description: 'Process pending items.')]
  public function process(): void {
    $this->io()->success('Done.');
  }

}
```

## Verification

```bash
# Verify Drush is working
ssh web ./vendor/bin/drush status --field=drupal-version
```
