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
  Never use to write a Playwright test suite (use drupal-playwright-test) or to
  judge what a screenshot shows (use screenshot-analysis). curl is not a
  substitute for this skill: it only answers raw HTTP questions.
---

## Ground Rules

1. **Do not use curl to judge what a page renders or does**: it cannot execute JS or simulate navigation. It is for raw HTTP facts only (see "When to use curl").
2. **Use HTTP, not HTTPS**, for all Playwright navigation in DDEV: the self-signed certificate makes HTTPS fail.
3. **Convert every URL** from `https://` to `http://` before passing it to `browser_navigate`, including `drush uli` output.
4. **Do not create JavaScript files, Node.js scripts, or Playwright test scripts** to drive the browser. Use the Playwright MCP tools directly. If MCP fails, troubleshoot the connection; a generated script is not a workaround.

**Tool names carry a harness prefix.** This skill writes the bare name
(`browser_navigate`). Claude Code exposes it as `mcp__playwright__browser_navigate`,
OpenCode as `playwright_browser_navigate`. Use whichever form your tool list shows.

## MCP Connection

Playwright MCP tools (`browser_navigate`, `browser_take_screenshot`, etc.) are registered as native tools via the MCP server configuration. They should be available directly — no manual HTTP/SSE protocol is needed.

- MCP URL: `http://playwright-mcp:8931/mcp` (or `$PLAYWRIGHT_MCP_URL`)
- Site URL: use `$DDEV_HTTP_URL` (already HTTP). `$DDEV_PRIMARY_URL` is HTTPS — if you use it, convert to HTTP first
- Web Container: accessible via `ssh web` (for commands like `drush uli`)

### If MCP tools are not available

**This is a RECOVERY procedure only. If the browser_* tools are visible, skip this entire section.**

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

Do not work around a failed MCP connection by writing `.js` or `.mjs` files.

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

## Available Browser Tools

Parameter names change between Playwright MCP versions, so they are not listed
here: the tool definition your harness shows is the source of truth.

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Navigate to a URL |
| `browser_navigate_back` | Go back |
| `browser_snapshot` | Accessibility tree as text, with the element references the other tools take |
| `browser_take_screenshot` | Capture a screenshot (optional filename, full page) |
| `browser_click` | Click an element from the snapshot |
| `browser_type` | Type text into one element |
| `browser_fill_form` | Fill several form fields in one call |
| `browser_select_option` | Select dropdown values |
| `browser_hover` | Hover over an element |
| `browser_press_key` | Press a keyboard key |
| `browser_drag` | Drag and drop between two elements |
| `browser_file_upload` | Upload files |
| `browser_handle_dialog` | Accept or dismiss an alert/confirm |
| `browser_wait_for` | Wait for a TEXT to appear or disappear, or for a time. It does not take CSS selectors |
| `browser_evaluate` | Run a JavaScript function in the page |
| `browser_console_messages` | Console output |
| `browser_network_requests` | Network activity |
| `browser_resize` | Resize the viewport |
| `browser_tabs` | List, open, select or close tabs |
| `browser_close` | Close the page |

To wait for an element rather than a text, take a `browser_snapshot` and look
for it; repeat once after a short `browser_wait_for` time if the page is still
loading.

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
ssh web drush uli
# Output: https://project.ddev.site/user/reset/1/123456/abc/login

# 2. Convert HTTPS to HTTP (the HTTPS link fails on the self-signed certificate)
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
2. If 403 → `ssh web drush uli`
3. Convert HTTPS to HTTP in returned URL
4. `browser_navigate` → http login URL
5. `browser_navigate` → target URL again (now authenticated)
6. `browser_take_screenshot`

## Testing Workflows

### Public page verification

1. `browser_navigate` → `http://<project>.ddev.site/path`
2. `browser_snapshot` (text content; confirms the page rendered and what it contains)
3. `browser_take_screenshot`

### Admin page testing

1. `ssh web drush uli`
2. Convert HTTPS → HTTP
3. `browser_navigate` → http login URL
4. `browser_navigate` → `http://<project>.ddev.site/admin/content`
5. `browser_snapshot` (confirm the listing is there)
6. `browser_take_screenshot`

### Form submission testing

1. Authenticate (drush uli + login)
2. `browser_navigate` → `http://<project>.ddev.site/node/add/article`
3. `browser_snapshot` (get element refs)
4. `browser_fill_form` → title "Test Article" and body "Content text", using the references from the snapshot
5. `browser_click` → the submit button from the snapshot
6. `browser_wait_for` → text `has been created`
7. `browser_take_screenshot`

## Common Drupal Selectors

For `browser_evaluate` and for reading a snapshot; the interaction tools take
snapshot references, not these selectors.

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
| MCP tools not available | The container registers the Playwright MCP itself (`$PLAYWRIGHT_MCP_URL`); check the playwright-mcp container is up (`ddev restart` on the host) and that a project-level `.mcp.json`/`opencode.json` does not override the `playwright` server |
| OpenCode lists no `browser_*` tool, or only `execute` | OpenCode 2 hides MCP tools behind `execute` (Code Mode) unless the server sets `"codemode": false`; the shipped config does, and then the tools are `playwright_browser_*`. A project `opencode.json` that redefines `mcp` loses it |
| Playwright not responding | Run the MCP health-check curl from "If MCP tools are not available" above; if it fails, ask the user to run `ddev restart` |
| SSL/certificate errors | Convert HTTPS to HTTP in ALL URLs |
| 403 Forbidden | Authenticate with `drush uli` first |
| Element not found | Use `browser_snapshot` to see the available elements; if the page is still loading, `browser_wait_for` a text you expect, then snapshot again |
| Site not accessible | `ssh web drush status` |
| Screenshots not saving | Use a bare name in the `filename` parameter of `browser_take_screenshot`: a `./` prefix saves to the project root |
| `EACCES: permission denied, open '/var/www/html/screenshots/...'` on every browser tool | `screenshots/` is `root:root` (add-on older than v1.0.60). You cannot fix it from here (`sudo` is denied): ask the user to fix the ownership of `screenshots/` on the host or update the add-on, then retry; it is not an MCP connection problem |
| An "anonymous" page shows admin content | The MCP browser keeps one context, so an earlier `drush uli` session is still active; `/user` shows who you are. Log out first: `browser_navigate` → `$DDEV_HTTP_URL/user/logout`, then `browser_click` the `Log out` button of the confirmation form (Drupal 10.3+; a plain GET no longer logs out). For a status code alone, curl is enough |

## When to use curl (exceptions)

curl is for raw HTTP facts only (same rule as **ddev-environment**):
- Health checks: `curl -s http://playwright-mcp:8931/sse -H "Accept: text/event-stream" | head -1`
- HTTP header inspection (cache headers, redirects)
- Anonymous access checks: `curl -s -o /dev/null -w '%{http_code}\n' "$DDEV_HTTP_URL/<path>"`
- Quick connectivity tests

Page content, forms and behaviour go through the browser tools.
