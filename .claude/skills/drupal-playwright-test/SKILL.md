---
name: drupal-playwright-test
description: >-
  Generates E2E test files with Playwright for Drupal 10/11. Creates persistent
  TypeScript test files in the repository for visual regression, cross-browser,
  accessibility, and E2E flows. This skill writes test code, it does not execute it.
  Trigger: "playwright test", "visual regression", "screenshot test",
  "cross-browser test", "accessibility e2e test", or E2E flows when the project
  does not use Behat.
  Never use for service/entity logic (use drupal-kernel-test).
  Never use for simple form testing (use drupal-functional-test).
  Never use for interactive MCP browser testing (use playwright-testing skill).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Playwright Test

## What It Is

This skill generates persistent Playwright test files (.spec.ts) that live in the
repository. These are TypeScript files meant to run in CI or on the host machine.

**Not to be confused with the `playwright-testing` skill**, which uses Playwright MCP
tools interactively for ad-hoc browser verification without creating files.

| Skill | Purpose | Creates files | Execution |
|-------|---------|---------------|-----------|
| `drupal-playwright-test` | Persistent E2E tests in the repo | Yes (.spec.ts) | User runs on host |
| `playwright-testing` | Interactive ad-hoc verification | No | MCP tools directly |

## When to Use

- Visual regression (compare screenshots between deploys)
- Cross-browser tests (Chromium + Firefox + WebKit)
- Accessibility tests (axe-core)
- E2E flows in projects without Behat
- Smoke tests of the deployed site

## When NOT to Use

- The project already uses Behat for E2E (use Behat for consistency)
- Logic tests (use Kernel test)
- Simple forms without JS (use Functional test)
- Specific AJAX components (use FunctionalJavascript)
- Quick browser check or screenshot (use `playwright-testing` skill)

## Prerequisites

Before generating tests, verify the project has Playwright configured:

```bash
ssh web test -f test/playwright/playwright.config.ts && echo "OK" || echo "NOT FOUND"
```

If not found, inform the user that Playwright needs to be set up on the host first.
Do NOT attempt to install Playwright or DDEV add-ons from within the container.

## Directory Structure

```
test/playwright/
├── playwright.config.ts
├── tests/
│   ├── homepage.spec.ts
│   ├── article.spec.ts
│   └── accessibility.spec.ts
├── fixtures/
│   └── auth.ts
└── package.json
```

## Configuration Reference -- playwright.config.ts

When the user needs a config file, generate it with these DDEV-specific settings:

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    baseURL: process.env.DDEV_PRIMARY_URL?.replace('https://', 'http://')
             || 'http://myproject.ddev.site',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
```

**Important**: Always use HTTP, never HTTPS. DDEV uses self-signed certificates
that cause failures even with `ignoreHTTPSErrors`.

## Pattern: Authentication with drush uli

Use `globalSetup` to authenticate via one-time login link (the standard pattern
in this ecosystem). Never hardcode credentials.

```typescript
// fixtures/auth.ts
import { test as base, expect, type Page } from '@playwright/test';
import { execSync } from 'child_process';

async function drupalLogin(page: Page, role?: string): Promise<void> {
  const cmd = role
    ? `drush uli --name=${role} --uri=http://$(drush status --field=uri | sed 's|https://|http://|')`
    : `drush uli --uri=http://$(drush status --field=uri | sed 's|https://|http://|')`;
  const loginUrl = execSync(cmd, { encoding: 'utf-8' }).trim()
    .replace('https://', 'http://');
  await page.goto(loginUrl);
  await expect(page.getByText('Member for')).toBeVisible();
}

export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    await drupalLogin(page);
    await use(page);
  },
});

export { expect };
```

**Note**: `drush uli` generates a one-time login link. No passwords in test code.

## Pattern: E2E Flow

```typescript
import { test, expect } from '../fixtures/auth';

test.describe('Article creation', () => {
  test('editor creates and publishes article', async ({ authenticatedPage: page }) => {
    await page.goto('/node/add/article');
    await expect(page.locator('h1')).toContainText('Create Article');

    await page.getByLabel('Title').fill('E2E Article');
    await page.locator('#edit-body-0-value').fill('Body content.');
    await page.getByLabel('Published').check();
    await page.getByRole('button', { name: 'Save' }).click();

    await expect(page.locator('.messages--status')).toContainText('has been created');
    await expect(page.locator('h1')).toContainText('E2E Article');
  });

  test('anonymous cannot create articles', async ({ page }) => {
    await page.goto('/node/add/article');
    await expect(page).toHaveURL(/user\/login/);
  });
});
```

## Pattern: Visual Regression

```typescript
import { test, expect } from '@playwright/test';

test.describe('Visual regression', () => {
  test('homepage', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('homepage.png', {
      maxDiffPixelRatio: 0.01,
      fullPage: true,
    });
  });

  test('article page', async ({ page }) => {
    await page.goto('/node/1');
    await page.waitForLoadState('networkidle');
    const content = page.locator('.node--type-article');
    await expect(content).toHaveScreenshot('article.png');
  });

  test('mobile header', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('header')).toHaveScreenshot('header-mobile.png');
  });
});
```

Baseline update command (for user reference): `npx playwright test --update-snapshots`

## Pattern: Accessibility with axe-core

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage accessibility', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

Requires `@axe-core/playwright` as a dev dependency in `test/playwright/`.

## Pattern: AJAX (Native Auto-Waiting)

```typescript
import { test, expect } from '../fixtures/auth';

test('dependent select updates options', async ({ authenticatedPage: page }) => {
  await page.goto('/node/add/article');
  await page.getByLabel('Country').selectOption('ES');

  // Playwright waits automatically -- no waitForAjax needed
  const citySelect = page.getByLabel('City');
  await expect(citySelect).toBeVisible();
  await expect(citySelect).toContainText('Madrid');
});
```

## Anti-Patterns

1. **No `page.waitForTimeout()`**. Playwright has auto-waiting built in.
2. **No fragile CSS selectors**. Prefer `getByRole()`, `getByLabel()`, `getByText()`.
3. **No hardcoded credentials**. Use `drush uli` via the auth fixture.
4. **No business logic testing**. Playwright is for user flows, not service logic.
5. **No HTTPS URLs**. Always HTTP in DDEV environments.
6. **No forgotten baselines**. Commit screenshot baselines to the repo.

## Running Tests (User Reference)

These commands run on the host machine, not from within the AI container:

```bash
# All tests
cd test/playwright && npx playwright test

# Single file
cd test/playwright && npx playwright test tests/homepage.spec.ts

# Single browser
cd test/playwright && npx playwright test --project=chromium

# Update visual baselines
cd test/playwright && npx playwright test --update-snapshots
```
