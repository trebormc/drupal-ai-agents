---
name: playwright-testing
description: >-
  Browser-based testing of Drupal sites using Playwright MCP in DDEV.
  Covers navigation, screenshots, authentication with drush uli, SSL/HTTPS
  workarounds, form interaction, and troubleshooting. Use when testing Drupal
  pages in a browser, taking screenshots, or interacting with the UI.
  Examples:
  - user: "test the homepage" -> navigate and screenshot via Playwright
  - user: "check the admin page" -> authenticate with drush uli then navigate
  - user: "take a screenshot" -> browser_take_screenshot via Playwright MCP
  - user: "verify the login page works" -> authenticate and navigate
  - user: "screenshot the content listing" -> browser_take_screenshot
  Never use curl for testing Drupal functionality. Use Playwright MCP instead.
---

## Critical Rules

1. **NEVER use curl** for testing Drupal pages — it cannot execute JS or simulate user navigation
2. **ALWAYS use HTTP** (not HTTPS) for all Playwright navigation in DDEV — self-signed SSL certificates cause failures
3. **Convert ALL URLs** from `https://` to `http://` before passing to `browser_navigate`, including drush uli output
4. **NEVER create JavaScript files, Node.js scripts, or Playwright test scripts** to interact with the browser. Always use the Playwright MCP tools directly. If MCP fails, troubleshoot the connection — do NOT generate script files as a workaround

## MCP Connection

Playwright MCP tools (`browser_navigate`, `browser_take_screenshot`, etc.) are registered as native tools via the MCP server configuration. They should be available directly — no manual HTTP/SSE protocol is needed.

- MCP URL: `http://playwright-mcp:8931/mcp` (or `$PLAYWRIGHT_MCP_URL`)
- Site URL: `$DDEV_PRIMARY_URL` (returns HTTPS — **always convert to HTTP**)
- Web Container: accessible via `ssh web` (for commands like `drush uli`)

### If MCP tools are not available

If the browser tools are not showing up as available tools:

```bash
# 1. Check if Playwright MCP is responding (works without Docker socket)
curl -s --max-time 3 http://playwright-mcp:8931/sse \
  -H "Accept: text/event-stream" | head -1
# Success: "event: endpoint"
# Failure: connection refused → container not running

# 2. Verify environment variable
echo $PLAYWRIGHT_MCP_URL
# Should return: http://playwright-mcp:8931/mcp

# 3. Restart DDEV to recover the container
# (tell the user to run: ddev restart)
```

**NEVER** work around a failed MCP connection by writing `.js` or `.mjs` files.

## Environment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  AI Container (OpenCode or Claude Code)                      │
│  - Runs agents, reads files, executes bash                   │
│  - Connects to Web via: ssh web           │
│  - Uses Playwright via: MCP tools (native)                   │
└──────────────┬──────────────────────┬───────────────────────┘
               │ SSH                  │ MCP protocol
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

## Available Browser Tools (Playwright MCP v0.0.56+)

| Tool | Purpose | Key parameters |
|------|---------|----------------|
| `browser_navigate` | Navigate to URL | `url` |
| `browser_take_screenshot` | Capture screenshot | `filename`, `fullPage` |
| `browser_snapshot` | Accessibility tree (text) | (none) |
| `browser_click` | Click element | `element`, `ref` |
| `browser_fill_form` | Fill form field | `ref`, `value` |
| `browser_select_option` | Select dropdown | `ref`, `values` |
| `browser_hover` | Hover over element | `element`, `ref` |
| `browser_evaluate` | Execute JavaScript | `expression` |
| `browser_press_key` | Press keyboard key | `key` |
| `browser_type` | Type text | `text`, `ref` |
| `browser_wait_for` | Wait for element | `selector`, `timeout` |
| `browser_tabs` | List open tabs | (none) |
| `browser_close` | Close browser | (none) |
| `browser_resize` | Resize viewport | `width`, `height` |
| `browser_console_messages` | Get console output | (none) |
| `browser_network_requests` | Get network activity | (none) |
| `browser_navigate_back` | Go back | (none) |
| `browser_file_upload` | Upload files | `paths` |
| `browser_handle_dialog` | Handle alerts | `accept` |
| `browser_drag` | Drag and drop | `startRef`, `endRef` |

### Tool Discovery

If tool names have changed (new Playwright MCP version), list available tools dynamically:

```bash
# Quick check: send tools/list via SSE
curl -s -N http://playwright-mcp:8931/sse -H "Accept: text/event-stream" > /tmp/sse.txt &
PID=$!; sleep 1
EP=$(grep "data:" /tmp/sse.txt | head -1 | sed 's/data: //')
curl -s -X POST "http://playwright-mcp:8931${EP}" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"check","version":"1.0"}}}'
sleep 1
curl -s -X POST "http://playwright-mcp:8931${EP}" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
sleep 2
grep -o '"name":"[^"]*"' /tmp/sse.txt | sort -u
kill $PID 2>/dev/null
```

## Screenshot Storage — How It Works

Screenshots auto-save to `<project-root>/screenshots/` via a Docker volume mount between the Playwright MCP container (`/tmp/playwright-output/`) and your project directory (`./screenshots/`).

**To control the filename**, pass the `filename` parameter to `browser_take_screenshot`:
- `filename: "homepage.png"` → saves to `/var/www/html/screenshots/homepage.png`
- `filename: "admin-content.png"` → saves to `/var/www/html/screenshots/admin-content.png`
- Always use relative paths (just the filename) — the output directory is pre-configured
- The directory exists automatically via the Docker volume mount — do NOT run `mkdir`

**Minimal screenshot workflow (3 tool calls):**
1. `browser_navigate` → `http://<project>.ddev.site/path`
2. `browser_take_screenshot` → `filename: "descriptive-name.png"`
3. Done. File is at `/var/www/html/screenshots/descriptive-name.png`

**Find recent screenshots:** `ls -lth /var/www/html/screenshots/ | head -10`

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
ssh web ./vendor/bin/drush uli
# Output: https://project.ddev.site/user/reset/1/123456/abc/login

# 2. CRITICAL: Convert HTTPS to HTTP
# From: https://project.ddev.site/user/reset/1/123456/abc/login
# To:   http://project.ddev.site/user/reset/1/123456/abc/login

# 3. Navigate to HTTP login URL (establishes session)
# browser_navigate → <http-version-of-drush-uli-url>

# 4. Now access protected pages (use HTTP)
# browser_navigate → http://<project>.ddev.site/admin/content
# browser_take_screenshot
```

**Important notes:**
- `drush uli` without parameters logs in as user 1 (admin)
- Login link is one-time use
- Session persists for subsequent navigations
- Generate a new link if session expires

### 403 Forbidden recovery flow

1. `browser_navigate` → target URL
2. If 403 → `ssh web ./vendor/bin/drush uli`
3. Convert HTTPS to HTTP in returned URL
4. `browser_navigate` → http login URL
5. `browser_navigate` → target URL again (now authenticated)
6. `browser_take_screenshot`

## Testing Workflows

### Public page verification

1. `browser_navigate` → `http://<project>.ddev.site/path`
2. `browser_wait_for` → `"main"`
3. `browser_take_screenshot`
4. `browser_snapshot` (for text content)

### Admin page testing

1. `ssh web ./vendor/bin/drush uli`
2. Convert HTTPS → HTTP
3. `browser_navigate` → http login URL
4. `browser_navigate` → `http://<project>.ddev.site/admin/content`
5. `browser_wait_for` → `".view-content"`
6. `browser_take_screenshot`

### Form submission testing

1. Authenticate (drush uli + login)
2. `browser_navigate` → `http://<project>.ddev.site/node/add/article`
3. `browser_snapshot` (get element refs)
4. `browser_fill_form` → ref for title, value "Test Article"
5. `browser_fill_form` → ref for body, value "Content text"
6. `browser_click` → ref for submit button
7. `browser_wait_for` → `".messages--status"`
8. `browser_take_screenshot`

## Common Drupal Selectors

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
| MCP tools not available | Check MCP registration in `.claude/settings.local.json` or `opencode.json` |
| Playwright not responding | `curl -s http://playwright-mcp:8931/sse -H "Accept: text/event-stream" \| head -1` → ask user to `ddev restart` |
| SSL/certificate errors | Convert HTTPS to HTTP in ALL URLs |
| 403 Forbidden | Authenticate with `drush uli` first |
| Element not found | Use `browser_snapshot` to see available elements, then `browser_wait_for` |
| Site not accessible | `ssh web ./vendor/bin/drush status` |
| Screenshots not saving | Use `filename` parameter in `browser_take_screenshot` — directory is auto-created by Docker volume mount |

## When to use curl (exceptions)

curl is ONLY acceptable for:
- Health checks: `curl -s http://playwright-mcp:8931/sse -H "Accept: text/event-stream" | head -1`
- HTTP header inspection (cache headers, redirects)
- Quick connectivity tests

NEVER use curl for page content, forms, or functionality testing.
