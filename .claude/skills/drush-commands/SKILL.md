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

All Drush commands run via `ssh web drush`.
NEVER use just `drush` — it will not be found without the full vendor path.

## Common operations

| Task | Command |
|------|---------|
| Clear all caches | `ssh web drush cr` |
| Run database updates | `ssh web drush updb -y` |
| Enable module | `ssh web drush en <module> -y` |
| Uninstall module | `ssh web drush pmu <module> -y` |
| Check Drupal status | `ssh web drush status` |
| Run cron | `ssh web drush cron` |
| One-time login | `ssh web drush uli` |
| List enabled modules | `ssh web drush pm:list --status=enabled` |
| Check pending updates | `ssh web drush updb --no` |
| Watchdog logs | `ssh web drush ws --count=20` |
| Rebuild permissions | `ssh web drush php-eval "node_access_rebuild();"` |
| Locale update | `ssh web drush locale:check && ssh web drush locale:update` |

## After code changes (mandatory order)

1. `ssh web drush updb -y` (apply hook_update_N)
2. `ssh web drush cim -y` (import config changes)
3. `ssh web drush cr` (rebuild caches)

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
ssh web drush status --field=drupal-version
```
