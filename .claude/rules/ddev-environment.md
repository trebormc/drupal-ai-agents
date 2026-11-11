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

## Quoting Through `ssh web`

The SSH client joins its arguments with spaces and the web container runs that one string
through `eval`, from `/var/www/html`. Your shell removes the quotes first, so `command arg
arg` is safe, and any argument with spaces, parentheses, `$`, `;` or `&&` needs a second
layer of quotes. Choose one of these:

```bash
# PHP of any length: stdin, nothing to escape. No <?php tag.
ssh web drush php:script - <<'PHP'
print count(\Drupal::entityTypeManager()->getStorage('node_type')->loadMultiple()) . "\n";
PHP
# PHP one-liner: outer single quotes, then \" for strings and \$ for variables
ssh web 'drush php:eval "echo strlen(\"abc\");"'
# SQL
ssh web 'drush sqlq "SELECT COUNT(*) FROM node"'
ssh web "drush sqlq \"SELECT COUNT(*) FROM node WHERE type = 'article'\""
# Another directory, pipes, several commands: one quoted string
ssh web "cd $DDEV_DOCROOT/themes/custom/mytheme && npm run build"
```

| Not this | Why it fails |
|---|---|
| `ssh web drush php:eval 'echo strlen("abc");'` | `eval: syntax error near unexpected token '('`. Without parentheses it is worse: no error, and `$a = 1; echo $a;` prints nothing |
| `ssh web drush sqlq "SELECT COUNT(*) FROM node"` | Same `eval` syntax error |
| `ssh web bash -c 'cd X && npm run build'` (also `sh -c`, `bash -lc`) | `bash -c` receives only `cd`; `npm run build` runs from `/var/www/html`: `npm error path /var/www/html/package.json` |
| A script in your own `/tmp` for `drush php:script` | Each container has its own `/tmp`: the web container cannot see it. Use stdin |

`ssh web` reads your stdin: inside a `while read` loop it swallows the rest of the input,
so add `</dev/null`.

## Critical Rules

- **Use `ssh web drush <command>`** to run Drush commands (drush is in the web container's PATH)
- **Never hardcode `web/`** — use `$DDEV_DOCROOT` (detect with: `grep "^docroot:" .ddev/config.yaml`)
- **curl is for raw HTTP facts only** (status code, headers, anonymous response, byte-for-byte output diff). Anything about what a page renders or does goes through Playwright (`visual-test`)
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
| `eval: ... syntax error near unexpected token` | Quoting lost in `ssh web` | Use a form from "Quoting Through `ssh web`"; other quote styles of the same one-layer command will not help |
| `shell level (1000) too high` then `fork: Resource temporarily unavailable` | `drush` resolves to its own DDEV wrapper: `vendor/bin/drush` is missing | Do not retry. `ssh web pkill -f global-commands/web/drush`, then `ssh web composer install` |
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
If not installed, use the raw tools now (**quality-checks** skill) and recommend `composer require drupal/audit` in your summary.
