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
  - user: "set up Tailwind" -> setup and configure TailwindCSS
  - user: "Tailwind classes don't work" -> diagnose and recompile
  - user: "compile the CSS" -> run Tailwind compilation
  Never use for non-Tailwind CSS (vanilla CSS, SCSS, PostCSS without Tailwind).
---

## CRITICAL RULE

**Every time you add, modify, or remove Tailwind classes in ANY file (.twig,
.html.twig, .php, .module, .theme), you MUST recompile the CSS and clear
Drupal caches.** Tailwind only includes classes it finds in scanned files.
New classes that aren't compiled will NOT appear in the browser.

### Mandatory post-change sequence

```bash
# 1. Recompile Tailwind CSS (ALWAYS after class changes)
docker exec $WEB_CONTAINER npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# 2. Clear Drupal cache (renders may reference old CSS)
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# 3. Verify in browser with hard refresh (Ctrl+Shift+R / Cmd+Shift+R)
#    Or use Playwright with cache disabled for testing
```

**If you skip step 1, new Tailwind classes will NOT render.** This is the
most common cause of "Tailwind classes not working."

## Installation in a Drupal theme

```bash
# Navigate to theme directory inside container
docker exec $WEB_CONTAINER bash -c "cd $DDEV_DOCROOT/themes/custom/<THEME> && npm init -y"
docker exec $WEB_CONTAINER bash -c "cd $DDEV_DOCROOT/themes/custom/<THEME> && npm install -D tailwindcss"
docker exec $WEB_CONTAINER bash -c "cd $DDEV_DOCROOT/themes/custom/<THEME> && npx tailwindcss init"
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
| `npm run dev` | Watch mode, auto-recompile on file changes | During active development |
| `npm run build` | One-time compile + minify | Before commit, after changes |

### tailwind.config.js

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    // Drupal theme templates
    './templates/**/*.html.twig',
    './components/**/*.html.twig',
    // Custom modules that use Tailwind classes
    '../../modules/custom/**/*.html.twig',
    '../../modules/custom/**/*.php',
    '../../modules/custom/**/*.module',
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

**CRITICAL**: The `content` array must include ALL file paths where Tailwind
classes appear. If a file is not scanned, its classes are purged from the
compiled CSS.

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
# Development: watch mode (auto-recompiles on save)
docker exec $WEB_CONTAINER npm run dev --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# Production: one-time build with minification
docker exec $WEB_CONTAINER npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# After build, ALWAYS clear Drupal cache
docker exec $WEB_CONTAINER ./vendor/bin/drush cr
```

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
| Classes in PHP not found | `.php`/`.module`/`.theme` files not in content | Add `'../../modules/custom/**/*.php'` to content |
| Watch mode not detecting | File outside content paths | Add missing glob pattern to content array |
| `@apply` not working | Custom class not in @layer | Wrap in `@layer components { }` |

## Verification

After ANY Tailwind class change:

```bash
# 1. Build
docker exec $WEB_CONTAINER npm run build --prefix $DDEV_DOCROOT/themes/custom/<THEME>

# 2. Verify the class is in compiled CSS
docker exec $WEB_CONTAINER grep "your-class" $DDEV_DOCROOT/themes/custom/<THEME>/css/styles.css

# 3. Clear Drupal cache
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# 4. Test in browser (use Playwright or hard refresh)
```
