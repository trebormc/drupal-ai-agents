---
name: drush-commands
description: >-
  Executes Drupal Drush commands for cache clearing, database updates, module
  management, cron, one-time login, permission rebuilds, locale updates, and
  writing custom Drush commands. Use proactively after code changes to clear
  caches or run database updates.
  Examples:
  - user: "clear cache" -> run drush cr via ssh web
  - user: "enable my module" -> run drush en module_name via ssh web
  - user: "update the database" -> run drush updb via ssh web
  - user: "add a drush command to my module" -> class in src/Drush/Commands/
  Never use for config export/import workflows (use config-management) or for
  diagnosing an error from the logs (use drupal-debugging).
---

## Environment

All Drush commands run via `ssh web drush`: Drupal and Drush live in the web
container, and `drush` does not exist in this one.

Quote the whole remote command when it contains PHP, `&&`, `|` or `;`:
`ssh web` joins its arguments and the remote shell parses them again, so
unquoted code is split or evaluated before Drush sees it.

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
| Rebuild permissions | `ssh web 'drush php:eval "node_access_rebuild();"'` |
| Locale update | `ssh web drush locale:check && ssh web drush locale:update` |

## After code changes

1. `ssh web drush updb -y` — only if you added an update or post-update hook
2. `ssh web drush cr` (rebuild caches)

Do not run `cim` here: it overwrites active config that has not been exported
yet, including the change you are in the middle of.

## After pulling or merging someone else's code

1. `ssh web drush updb -y` (apply update hooks)
2. `ssh web drush cim -y` (import config changes)
3. `ssh web drush cr` (rebuild caches)

Same order as "Deploy order after a merge" in the config-management rule.

## Multiline / newline-separated config values

`drush cget <config> <key> --format=string` renders real newlines as literal `\n`
text. Feeding that back through `drush cset` stores the literal backslash-n and
**corrupts every existing line**. To append to or edit a multiline value, use
PHP from stdin, then verify with `var_export`:

```bash
# Append a line to a newline-separated value:
ssh web drush php:script - <<'PHP'
$c = \Drupal::configFactory()->getEditable('mymodule.settings');
$c->set('patterns', $c->get('patterns') . "\nnew-pattern")->save();
PHP
# Verify the stored value has REAL newlines, not literal \n:
ssh web drush php:script - <<'PHP'
var_export(\Drupal::config('mymodule.settings')->get('patterns'));
PHP
```

## Custom Drush commands (Drush 12+)

Place the class in `src/Drush/Commands/` (namespace
`Drupal\<module>\Drush\Commands`): Drush discovers it there with no
`drush.services.yml`, which Drush 13 no longer reads. Use the attribute pattern:

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Drush\Commands;

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
