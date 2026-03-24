---
name: playwright-browser-testing
description: >-
  Guides browser-based testing of Drupal sites using Playwright MCP in DDEV.
  Covers navigation, screenshots, authentication with drush uli, SSL/HTTPS
  workarounds, form interaction, and troubleshooting. Use when testing Drupal
  pages in a browser, taking screenshots, or interacting with the UI.
  Examples:
  - user: "test the homepage" -> navigate and screenshot via Playwright
  - user: "check the admin page" -> authenticate with drush uli then navigate
  - user: "take a screenshot" -> browser_screenshot via Playwright MCP
  - user: "prueba la pagina de admin" -> authenticate and navigate
  - user: "haz una captura de pantalla" -> browser_screenshot
  Never use curl for testing Drupal functionality. Use Playwright MCP instead.
---

## CRITICAL RULES

1. **NEVER use curl** for testing Drupal pages — it cannot execute JS or simulate user navigation
2. **ALWAYS use HTTP** (not HTTPS) for all Playwright navigation in DDEV — self-signed SSL certificates cause failures
3. **Convert ALL URLs** from `https://` to `http://` before passing to `browser_navigate`, including drush uli output
4. **NEVER create JavaScript files, Node.js scripts, or Playwright test scripts** to interact with the browser. Always use the Playwright MCP tools (`browser_navigate`, `browser_screenshot`, etc.) directly. If the MCP connection fails, troubleshoot it (check container status, check logs, restart DDEV) — do NOT generate script files as a workaround

### If MCP connection fails

```bash
# 1. Check if Playwright MCP container is running
docker ps | grep playwright-mcp

# 2. Check container logs for errors
docker logs ddev-${DDEV_SITENAME}-playwright-mcp

# 3. Restart DDEV to recover the container
ddev restart

# 4. Verify MCP is responding
curl -s $PLAYWRIGHT_MCP_URL
```

**NEVER** work around a failed MCP connection by writing `.js` or `.mjs` files. Report the connection issue and troubleshoot it.

## Environment Architecture (3 DDEV Containers)

**All three components run as DDEV Docker containers — nothing runs on the host machine.**

```
┌─────────────────────────────────────────────────────────────┐
│  OpenCode Container (YOU ARE HERE)                          │
│  - Runs agents, reads files, executes bash                  │
│  - Connects to Web via: docker exec $WEB_CONTAINER          │
│  - Connects to Playwright via: HTTP MCP protocol            │
└──────────────┬──────────────────────┬───────────────────────┘
               │ docker exec          │ HTTP (MCP protocol)
               ▼                      ▼
┌──────────────────────────┐  ┌───────────────────────────────┐
│  Web Container           │  │  Playwright MCP Container     │
│  (ddev-{project}-web)    │  │  (ddev-{project}-playwright-  │
│  - PHP, Drupal, Drush    │  │   mcp)                        │
│  - npm, Composer         │  │  - Chromium browser            │
└──────────────────────────┘  │  - MCP tools on port 8931     │
                              │  - Navigates to Web Container  │
                              └───────────────────────────────┘
```

- MCP URL: `http://playwright-mcp:8931/mcp` (or `$PLAYWRIGHT_MCP_URL`)
- Site URL: `$DDEV_PRIMARY_URL` (returns HTTPS — always convert to HTTP)
- Web Container: `$WEB_CONTAINER` (for `docker exec` commands like `drush uli`)

## Available browser tools

| Tool | Purpose | Example |
|------|---------|---------|
| `browser_navigate` | Navigate to URL | `browser_navigate → http://project.ddev.site/admin` |
| `browser_screenshot` | Capture screenshot | `browser_screenshot → "page.png"` |
| `browser_click` | Click element | `browser_click → "#edit-submit"` |
| `browser_fill` | Fill form field | `browser_fill → "#edit-title-0-value", "Title"` |
| `browser_select` | Select dropdown | `browser_select → "#edit-type", "article"` |
| `browser_hover` | Hover over element | `browser_hover → ".menu-item"` |
| `browser_evaluate` | Execute JavaScript | `browser_evaluate → "document.title"` |
| `browser_get_text` | Get element text | `browser_get_text → "h1"` |
| `browser_get_attribute` | Get attribute value | `browser_get_attribute → "img", "src"` |
| `browser_wait_for_selector` | Wait for element | `browser_wait_for_selector → ".view-content"` |

## Screenshot storage

- Screenshots save to: `<project-root>/screenshots/`
- Container path: `/var/www/html/screenshots/`
- Use simple filenames: `browser_screenshot → "my-page.png"`
- Find recent: `ls -lth /var/www/html/screenshots/ | head -10`

## Authentication (drush uli)

### When authentication is needed

| URL Pattern | Needs auth? |
|-------------|-------------|
| `/` (homepage) | No |
| `/node/123` (published) | No |
| `/admin/*` | **YES** |
| `/node/add/*` | **YES** |
| `/user/*/edit` | **YES** |
| Any path returning 403 | **YES** |

### Authentication workflow

```bash
# 1. Generate one-time admin login link
docker exec $WEB_CONTAINER ./vendor/bin/drush uli
# Output: https://project.ddev.site/user/reset/1/123456/abc/login

# 2. CRITICAL: Convert HTTPS to HTTP
# From: https://project.ddev.site/user/reset/1/123456/abc/login
# To:   http://project.ddev.site/user/reset/1/123456/abc/login

# 3. Navigate to HTTP login URL (establishes session)
browser_navigate → <http-version-of-drush-uli-url>

# 4. Now access protected pages (use HTTP version of $DDEV_PRIMARY_URL)
browser_navigate → <http-version-of-ddev-primary-url>/admin/content
browser_screenshot → "admin-content.png"
```

**Important notes:**
- `drush uli` without parameters logs in as user 1 (admin)
- Login link is one-time use
- Session persists for subsequent navigations
- Generate a new link if session expires

### 403 Forbidden recovery flow

```
1. browser_navigate → target URL
2. If 403 → docker exec $WEB_CONTAINER ./vendor/bin/drush uli
3. Convert HTTPS to HTTP in returned URL
4. browser_navigate → <http-login-url>
5. browser_navigate → target URL again (now works)
6. browser_screenshot → "page.png"
```

## Testing workflows

### Public page verification
```
1. browser_navigate → http://<project>.ddev.site/path
2. browser_wait_for_selector → "main"
3. browser_screenshot → "page-name.png"
4. browser_get_text → "h1"
```

### Admin page testing
```
1. docker exec $WEB_CONTAINER ./vendor/bin/drush uli
2. Convert HTTPS → HTTP
3. browser_navigate → <http-login-url>
4. browser_navigate → http://<project>.ddev.site/admin/content
5. browser_wait_for_selector → ".view-content"
6. browser_screenshot → "admin-content.png"
```

### Form submission testing
```
1. Authenticate (drush uli + login)
2. browser_navigate → http://<project>.ddev.site/node/add/article
3. browser_fill → "#edit-title-0-value", "Test Article"
4. browser_fill → "#edit-body-0-value", "Content text"
5. browser_click → "#edit-submit"
6. browser_wait_for_selector → ".messages--status"
7. browser_screenshot → "form-submitted.png"
```

## Common Drupal selectors

| Element | Selector |
|---------|----------|
| Page title | `h1.page-title`, `h1` |
| Status messages | `.messages--status` |
| Error messages | `.messages--error` |
| Content area | `.region-content`, `main` |
| Navigation | `.menu--main`, `nav` |
| Admin toolbar | `#toolbar-bar` |
| Node form | `.node-form` |
| Views content | `.view-content` |
| Submit button | `[type="submit"]`, `.form-submit` |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Playwright MCP not responding | `docker ps \| grep playwright-mcp` → check logs → `ddev start` |
| SSL/certificate errors | Convert HTTPS to HTTP in ALL URLs |
| 403 Forbidden | Authenticate with `drush uli` first |
| Element not found | `browser_wait_for_selector` with longer timeout, verify selector exists |
| Site not accessible | `docker exec $WEB_CONTAINER ./vendor/bin/drush status` → check `echo $DDEV_PRIMARY_URL` |
| Screenshots not saving | Check `/var/www/html/screenshots/` exists |

### Verify Playwright MCP is running

```bash
curl -s $PLAYWRIGHT_MCP_URL
docker ps | grep playwright-mcp
docker logs ddev-${DDEV_SITENAME}-playwright-mcp
```

## When to use curl (exceptions)

curl is ONLY acceptable for:
- Health checks: `curl http://playwright-mcp:8931/mcp`
- HTTP header inspection (cache headers, redirects)
- Quick connectivity tests

NEVER use curl for page content, forms, or functionality testing.
