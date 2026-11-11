---
name: tailwind-drupal
description: >-
  Guides TailwindCSS setup, configuration, compilation, and usage in Drupal
  themes. Ensures CSS is recompiled after every HTML/Twig/PHP change that adds
  or modifies Tailwind classes. Use when working with Tailwind in a Drupal theme,
  adding Tailwind classes, or troubleshooting missing styles.
  Examples:
  - user: "add Tailwind to my theme" -> setup and configure TailwindCSS
  - user: "my Tailwind classes don't work" -> diagnose and recompile
  - user: "build the CSS" -> run Tailwind compilation
  Never use for non-Tailwind CSS (vanilla CSS, SCSS, PostCSS without Tailwind).
---

## The rule that matters

Every time you add, modify, or remove Tailwind classes in any file (.twig,
.php, .module, .theme), recompile the CSS and clear Drupal caches. Tailwind
only emits the classes it finds in scanned files, so a class that was not
compiled does not exist in the browser. This is the most common cause of
"Tailwind classes not working".

### Post-change sequence

```bash
# 1. Recompile Tailwind CSS
ssh web npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# 2. Clear Drupal cache (renders may reference old CSS)
ssh web drush cr

# 3. Verify in browser with hard refresh (Ctrl+Shift+R / Cmd+Shift+R)
#    Or use Playwright with cache disabled for testing
```

## Detect the Tailwind major version first

Tailwind 3 and 4 are configured differently, and everything below this section
is written for **v3**. In an existing theme, check before touching anything:

```bash
ssh web "cd $DDEV_DOCROOT/themes/custom/<THEME> && npm ls tailwindcss --depth=0; ls tailwind.config.* 2>/dev/null"
```

- **3.x** (`tailwind.config.js` present, `@tailwind base;` in the input CSS) →
  this skill applies as written.
- **4.x** (no `tailwind.config.js`; the input CSS starts with
  `@import "tailwindcss";`) → there is no `npx tailwindcss init` and no
  `@tailwind` directives. The CLI is the separate `@tailwindcss/cli` package
  (`npx @tailwindcss/cli -i ./src/input.css -o ./css/styles.css`), sources are
  auto-detected and extra paths are added in CSS with
  `@source "../../../modules/custom";`, and theme values live in a CSS `@theme`
  block. Keep the project's existing `package.json` scripts and config style;
  only the post-change sequence, the library definition and the verification
  steps of this skill carry over. Do not downgrade or upgrade the major version
  unless the user asks.

## Installation in a Drupal theme (v3)

```bash
# Pin the major: a bare `npm install -D tailwindcss` installs v4, where
# `npx tailwindcss init` does not exist.
ssh web "cd $DDEV_DOCROOT/themes/custom/<THEME> && npm init -y"
ssh web "cd $DDEV_DOCROOT/themes/custom/<THEME> && npm install -D tailwindcss@^3.4"
ssh web "cd $DDEV_DOCROOT/themes/custom/<THEME> && npx tailwindcss init"
```

## Configuration files

### package.json (in theme root)

```json
{
  "scripts": {
    "dev": "npx tailwindcss -i ./src/input.css -o ./css/styles.css --watch",
    "build": "npx tailwindcss -i ./src/input.css -o ./css/styles.css --minify"
  },
  "devDependencies": {
    "tailwindcss": "^3.4"
  }
}
```

| Script | Use | When |
|--------|-----|------|
| `npm run dev` | Watch mode, auto-recompile on file changes | For the human developer only: it never returns, so an agent that runs it hangs |
| `npm run build` | One-time compile + minify | What agents run, after every class change |

### tailwind.config.js

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  // NOTE: all content paths are relative to the THEME directory (where this file lives)
  content: [
    // Drupal theme templates
    './templates/**/*.html.twig',
    './components/**/*.html.twig',
    // Custom modules that use Tailwind classes. From
    // <docroot>/themes/custom/<THEME>, three levels up is the docroot.
    '../../../modules/custom/**/*.html.twig',
    '../../../modules/custom/**/*.php',
    '../../../modules/custom/**/*.module',
    // Theme PHP files (preprocess functions with class arrays)
    './*.theme',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
```

The `content` array must include every path where Tailwind classes appear: a
file that is not scanned gets its classes purged from the compiled CSS.

### src/input.css

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Custom component classes (use @apply sparingly) */
@layer components {
  .btn-primary {
    @apply inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2;
  }
}
```

### Drupal library definition (mytheme.libraries.yml)

```yaml
tailwind:
  css:
    theme:
      css/styles.css: { minified: true }
```

Attach in your base template (e.g., `html.html.twig` or `page.html.twig`):
```twig
{{ attach_library('mytheme/tailwind') }}
```

## Build commands

```bash
# One-time build with minification (the only form an agent runs)
ssh web npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# Then clear the Drupal cache
ssh web drush cr
```

Never run `npm run dev` from an agent: watch mode does not exit and blocks the
session. If the user wants it, they run it on the host (`ddev exec`).

## Responsive breakpoints

| Prefix | Min-width | Use for |
|--------|-----------|---------|
| (none) | 0px | Mobile first (default) |
| `sm:` | 640px | Small tablets |
| `md:` | 768px | Tablets |
| `lg:` | 1024px | Desktops |
| `xl:` | 1280px | Large screens |
| `2xl:` | 1536px | Extra large |

Always design **mobile-first**: write base styles without prefix, then add
breakpoint prefixes for larger screens.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Classes not rendering | CSS not recompiled | `npm run build` → `drush cr` → hard refresh |
| Classes purged in prod | File path missing from `content` array | Add path to `tailwind.config.js` content |
| Styles cached in browser | Browser using old CSS | Hard refresh (Ctrl+Shift+R) or clear browser cache |
| Classes in PHP not found | `.php`/`.module`/`.theme` files not in content | Add `'../../../modules/custom/**/*.php'` to content |
| Watch mode not detecting | File outside content paths | Add missing glob pattern to content array |
| `@apply` not working | Custom class not in @layer | Wrap in `@layer components { }` |
| `npm run build` fails | Missing node_modules | `ssh web npm install --prefix $DDEV_DOCROOT/themes/custom/<THEME>` then rebuild |
| `npm: command not found` | Command run in wrong container | Prefix the command with `ssh web ` |

## Verification

After any Tailwind class change:

```bash
# 1. Build
ssh web npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# 2. Verify the compiled file exists AND contains the new class (replace CLASS):
ssh web test -f $DDEV_DOCROOT/themes/custom/<THEME>/css/styles.css && echo "FILE OK"
ssh web grep -c "CLASS" $DDEV_DOCROOT/themes/custom/<THEME>/css/styles.css
# Output 0 or "FILE OK" missing → build failed or class not in a scanned path (check content array)

# 3. Clear Drupal cache
ssh web drush cr

# 4. Test in browser (use Playwright or hard refresh)
```
