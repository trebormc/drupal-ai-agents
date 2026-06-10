---
description: DDEV environment rules — SSH access, container variables, drush path
---

# DDEV Environment

You run inside an AI container (OpenCode or Claude Code). ALL PHP/Drupal commands must run via SSH to the web container.

## Commands

```bash
# CORRECT
ssh web drush cr
ssh web composer require drupal/token
ssh web ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom

# WRONG
drush cr            # Missing ssh web — drush does not exist in this container
ddev drush cr       # ddev CLI does not exist inside containers
ssh web phpstan     # Missing ./vendor/bin/ path
```

**Where commands run:**

| Command type | Where | Example |
|---|---|---|
| Read/edit project files | Your container (direct) | `cat composer.json`, Read/Edit tools |
| drush, composer, phpunit, phpstan, phpcs, npm | `ssh web ...` | `ssh web drush cr` |
| Task tracking | `bd` wrapper (direct) | `bd ready --json` |
| Browser testing | Playwright MCP tools | `browser_navigate` |

## Critical Rules

- **Use `ssh web drush <command>`** to run Drush commands (drush is in the web container's PATH)
- **Never hardcode `web/`** — use `$DDEV_DOCROOT` (detect with: `grep "^docroot:" .ddev/config.yaml`)
- **Use HTTP not HTTPS** for Playwright browser navigation (avoids SSL errors in DDEV). Use `$DDEV_HTTP_URL`; if a command returns an HTTPS URL (e.g., `drush uli`), replace `https://` with `http://` before navigating

## Available Variables

| Variable | Purpose |
|----------|---------|
| `$DDEV_PRIMARY_URL` | Site URL (HTTPS) |
| `$DDEV_HTTP_URL` | Site URL (HTTP) — ALWAYS use this one for browser/Playwright navigation |
| `$DDEV_SITENAME` | Project name |
| `$DDEV_DOCROOT` | Drupal root path relative to project root (e.g., `web`, `docroot`) |
| `$PLAYWRIGHT_MCP_URL` | Playwright MCP endpoint URL |

If `$DDEV_DOCROOT` is empty, detect it: `grep "^docroot:" .ddev/config.yaml | awk '{print $2}'`

## When a Command Fails — No Blind Retries

NEVER re-run the same command unchanged expecting a different result. When a command fails:

1. **Read the error message** and classify it before acting:

| Error says | Meaning | Action |
|---|---|---|
| `command not found` / `No such file` (drush, composer, phpunit, npm, php) | Ran in the wrong container | Re-run with `ssh web ` prefix |
| `vendor/bin/...: No such file` (via ssh web) | Tool not installed | `ssh web composer require --dev <package>` or use the Audit module path |
| `Connection refused` / SSH errors | A container is down | Ask the user to run `ddev restart` on the host — do not retry |
| Permission denied on a file | Wrong path or ownership | Check the path exists before anything else: `ls <path>` |
| Same error twice in a row | Your approach is wrong | STOP retrying. Change the approach or report the error to the user with the exact message |

2. **Maximum 2 attempts** per command variant. If the second corrected attempt also fails, report the exact error to the user instead of trying a third variation.

## Quality Checks — Audit Module Priority

Always check for the Audit module first:
```bash
ssh web drush pm:list --filter=audit --format=list
```
If installed, use `drush audit:run phpcs/phpstan/phpunit --filter="module:NAME" --format=json`.
If not installed, recommend `composer require drupal/audit`. Fall back to raw tools only if user declines.
