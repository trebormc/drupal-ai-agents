---
description: DDEV environment rules — docker exec, container variables, drush path
---

# DDEV Environment

You run inside an AI container (OpenCode or Claude Code). ALL PHP/Drupal commands must run via `docker exec`.

## Commands

```bash
# CORRECT
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# WRONG
drush cr                                    # Missing docker exec
ddev drush cr                               # Wrong context
docker exec $WEB_CONTAINER drush cr         # Missing ./vendor/bin/ path
```

## Critical Rules

- **Always use `./vendor/bin/drush`** — never just `drush`
- **Never hardcode `web/`** — use `$DDEV_DOCROOT` (detect with: `grep "^docroot:" .ddev/config.yaml`)
- **Use HTTP not HTTPS** for Playwright browser navigation (avoids SSL errors in DDEV)

## Available Variables

| Variable | Purpose |
|----------|---------|
| `$WEB_CONTAINER` | Web container name for docker exec |
| `$DB_CONTAINER` | Database container name |
| `$DDEV_PRIMARY_URL` | Site URL (HTTPS) |
| `$DDEV_SITENAME` | Project name |
| `$DDEV_DOCROOT` | Drupal root path (e.g., `web`) |
| `$BEADS_CONTAINER` | Beads container for bd wrapper |
| `$PLAYWRIGHT_MCP_URL` | MCP endpoint URL |

## Quality Checks — Audit Module Priority

Always check for the Audit module first:
```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
```
If installed, use `drush audit:run phpcs/phpstan/phpunit --filter="module:NAME" --format=json`.
If not installed, recommend `composer require drupal/audit`. Fall back to raw tools only if user declines.
