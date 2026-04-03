---
name: drupal-playwright-test
description: >-
  Generates E2E tests with Playwright for Drupal 10/11. Use this skill for visual
  regression (screenshot comparison), cross-browser tests, accessibility tests,
  or E2E flows in projects that do not use Behat. Playwright is the official
  replacement for Nightwatch in Drupal core (November 2025).
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

E2E framework by Microsoft. Supports Chromium, Firefox and WebKit natively.
Drupal core adopted it as the replacement for Nightwatch in November 2025.

Advantages: native auto-waiting, parallel execution, visual regression with
`toHaveScreenshot()`, multi-browser, test recorder, TypeScript.

## When to Use

- Visual regression (compare screenshots between deploys)
- Cross-browser tests (Chrome + Firefox + Safari)
- Accessibility tests (axe-core)
- E2E flows in projects without Behat
- Smoke tests of the deployed site

## When NOT to Use

- The project already uses Behat -> use Behat for consistency
- Logic tests -> Kernel test
- Simple forms -> Functional test
- Specific AJAX -> FunctionalJavascript

## Setup with DDEV

```bash
mkdir -p test/playwright
docker exec $WEB_CONTAINER npx create-playwright@latest --lang=TypeScript --quiet test/playwright --no-browsers
ddev add-on get Lullabot/ddev-playwright
ddev install-playwright
docker exec $WEB_CONTAINER sh -c "cd test/playwright && npm i @lullabot/playwright-drupal"
```

## Configuration -- playwright.config.ts

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    baseURL: process.env.DDEV_PRIMARY_URL || 'https://myproject.ddev.site',
    ignoreHTTPSErrors: true,
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

## Pattern: Authentication Fixture

```typescript
// fixtures/auth.ts
import { test as base, expect } from '@playwright/test';

export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    await page.goto('/user/login');
    await page.getByLabel('Username').fill('editor');
    await page.getByLabel('Password').fill('editor_pass');
    await page.getByRole('button', { name: 'Log in' }).click();
    await expect(page.getByText('Log out')).toBeVisible();
    await use(page);
  },
  adminPage: async ({ page }, use) => {
    await page.goto('/user/login');
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Password').fill('admin_pass');
    await page.getByRole('button', { name: 'Log in' }).click();
    await expect(page.getByText('Log out')).toBeVisible();
    await use(page);
  },
});

export { expect };
```

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

Update baselines: `npx playwright test --update-snapshots`

## Pattern: Accessibility with axe-core

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage a11y', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

Install: `npm install --save-dev @axe-core/playwright`

## Pattern: AJAX (Native Auto-Waiting)

```typescript
test('dependent select', async ({ adminPage: page }) => {
  await page.goto('/node/add/article');
  await page.getByLabel('Country').selectOption('ES');

  // Playwright waits automatically -- no need for waitForAjax
  const citySelect = page.getByLabel('City');
  await expect(citySelect).toBeVisible();
  await expect(citySelect).toContainText('Madrid');
});
```

## Test Recorder

Generate code from real interactions:

```bash
npx playwright codegen https://mysite.ddev.site
```

## Anti-Patterns

1. Do not use `page.waitForTimeout()` except in extreme cases. Playwright has auto-waiting.
2. Do not use fragile CSS selectors. Prefer `getByRole()`, `getByLabel()`, `getByText()`.
3. Do not run multi-browser locally. Reserve for CI.
4. Do not test business logic with Playwright. It is for user flows.
5. Do not forget to commit baseline screenshots to the repo.

## Execution Command

```bash
# All tests
npx playwright test

# Specific test
npx playwright test tests/homepage.spec.ts

# Single browser only
npx playwright test --project=chromium

# Interactive UI mode
npx playwright test --ui

# Step-by-step debug
npx playwright test --debug

# Update visual baselines
npx playwright test --update-snapshots

# Record tests
npx playwright codegen https://mysite.ddev.site

# View HTML report
npx playwright show-report
```
