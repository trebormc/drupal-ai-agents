---
description: DDEV environment rules — SSH access, container variables, drush path
---

# DDEV Environment

You run inside an AI container (OpenCode or Claude Code). ALL PHP/Drupal commands must run via SSH to the web container.

## Commands

```bash
# CORRECT
ssh web ./vendor/bin/drush cr

# WRONG
drush cr                                    # Missing ssh web
ddev drush cr                               # Wrong context
ssh web drush cr         # Missing ./vendor/bin/ path
```

## Critical Rules

- **Always use `./vendor/bin/drush`** — never just `drush`
- **Never hardcode `web/`** — use `$DDEV_DOCROOT` (detect with: `grep "^docroot:" .ddev/config.yaml`)
- **Use HTTP not HTTPS** for Playwright browser navigation (avoids SSL errors in DDEV)

## Available Variables

| Variable | Purpose |
|----------|---------|
| `$DDEV_PRIMARY_URL` | Full HTTPS URL |
| `$DDEV_PRIMARY_URL` | Site URL (HTTPS) |
| `$DDEV_SITENAME` | Project name |
| `$DDEV_DOCROOT` | Drupal root path (e.g., `web`) |
| `$PLAYWRIGHT_MCP_URL` | MCP endpoint URL |

## Quality Checks — Audit Module Priority

Always check for the Audit module first:
```bash
ssh web ./vendor/bin/drush pm:list --filter=audit --format=list
```
If installed, use `drush audit:run phpcs/phpstan/phpunit --filter="module:NAME" --format=json`.
If not installed, recommend `composer require drupal/audit`. Fall back to raw tools only if user declines.
