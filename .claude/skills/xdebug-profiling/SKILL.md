---
name: xdebug-profiling
description: >-
  Enables Xdebug tracing and profiling in DDEV to debug errors and analyze
  performance. Covers trace mode (function call tree, arguments, return values),
  profile mode (cachegrind analysis), triggering for specific requests, and
  programmatic output analysis. Use when debugging page errors, analyzing slow
  pages, finding performance bottlenecks, or tracing code execution paths.
  Examples:
  - user: "debug this page error" -> enable Xdebug trace, trigger request, analyze trace
  - user: "why is this page slow" -> enable Xdebug profiler, trigger request, analyze cachegrind
  - user: "trace the execution of /admin/content" -> trace mode workflow
  - user: "find where this error comes from" -> enable Xdebug trace and analyze
  - user: "this page loads slowly" -> enable profiler and analyze bottlenecks
  - user: "analyze performance of this request" -> profile mode workflow
  Never use for step debugging with IDE breakpoints (that requires IDE integration).
---

## Environment

All commands run via `ssh web`. Xdebug output is stored
inside the web container at `/tmp/xdebug/`. **Use `$DDEV_DOCROOT` for paths.**

## Two Modes

| Mode | Use for | Output | Analysis |
|------|---------|--------|----------|
| **trace** | Debug errors, trace execution path | `.xt` files (function calls, args, returns) | Read trace, find error origin |
| **profile** | Performance bottlenecks, slow pages | `cachegrind.out.*` files | Find slowest/most-called functions |

## Setup (run once per session)

```bash
ssh web mkdir -p /tmp/xdebug
ssh web php -m | grep -i xdebug  # If missing: phpenmod xdebug && kill -USR2 $(pgrep -o php-fpm)
```

## Workflow A: Trace Mode (Debug Errors)

### Step 1: Enable trace

```bash
ssh web bash -c "
  PHP_VER=\$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;')
  cat > /etc/php/\${PHP_VER}/fpm/conf.d/99-xdebug-custom.ini <<'EOF'
xdebug.mode=trace
xdebug.start_with_request=trigger
xdebug.output_dir=/tmp/xdebug
xdebug.trace_format=1
xdebug.collect_return=1
xdebug.collect_assignments=1
xdebug.trace_output_name=trace.%t.%p
EOF
  kill -USR2 \$(pgrep -o php-fpm)
"
```

### Step 2: Trigger the request

```bash
# Via curl inside web container (or Playwright with ?XDEBUG_TRIGGER=1)
ssh web curl -s -b 'XDEBUG_TRIGGER=1' 'http://localhost/the-page' -o /dev/null -w '%{http_code}'
```

### Step 3: Analyze the trace

```bash
# Find latest trace file
ssh web ls -lt /tmp/xdebug/trace.*.xt | head -3

# Quick analysis: top 25 slowest functions
ssh web php -r "
\$lines = file('/tmp/xdebug/TRACE_FILE');
\$entries = []; \$calls = [];
foreach (\$lines as \$line) {
    \$f = explode(\"\t\", trim(\$line));
    if (count(\$f) < 5) continue;
    if (\$f[2] === '0' && isset(\$f[5])) {
        \$entries[\$f[1]] = ['name' => \$f[5], 'start' => (float)\$f[3], 'file' => \$f[8] ?? '', 'line' => \$f[9] ?? ''];
    } elseif (\$f[2] === '1' && isset(\$entries[\$f[1]])) {
        \$d = (float)\$f[3] - \$entries[\$f[1]]['start'];
        \$n = \$entries[\$f[1]]['name'];
        if (!isset(\$calls[\$n])) \$calls[\$n] = ['count' => 0, 'total' => 0, 'file' => \$entries[\$f[1]]['file'], 'line' => \$entries[\$f[1]]['line']];
        \$calls[\$n]['count']++;
        \$calls[\$n]['total'] += \$d;
    }
}
uasort(\$calls, fn(\$a, \$b) => \$b['total'] <=> \$a['total']);
printf(\"%-45s %6s %10s %s\n\", 'Function', 'Calls', 'Time(s)', 'Location');
echo str_repeat('-', 90) . \"\n\";
foreach (array_slice(\$calls, 0, 25) as \$n => \$d) {
    printf(\"%-45s %6d %10.4f %s:%s\n\", substr(\$n, 0, 45), \$d['count'], \$d['total'], basename(\$d['file']), \$d['line']);
}
"
```

### Step 4: Search for errors/patterns in trace

```bash
ssh web grep -n "Exception\|Error\|fatal" /tmp/xdebug/TRACE_FILE | head -20
ssh web grep "query\|execute\|select" /tmp/xdebug/TRACE_FILE | head -30
```

## Workflow B: Profile Mode (Performance Analysis)

### Step 1: Enable profiler

```bash
ssh web bash -c "
  PHP_VER=\$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;')
  cat > /etc/php/\${PHP_VER}/fpm/conf.d/99-xdebug-custom.ini <<'EOF'
xdebug.mode=profile
xdebug.start_with_request=trigger
xdebug.output_dir=/tmp/xdebug
xdebug.profiler_output_name=cachegrind.out.%t.%p
EOF
  kill -USR2 \$(pgrep -o php-fpm)
"
```

### Step 2: Trigger and analyze

```bash
ssh web curl -s -b 'XDEBUG_TRIGGER=1' 'http://localhost/slow-page' -o /dev/null -w '%{http_code}'
```

### Step 3: Analyze cachegrind

```bash
# Find latest profile
ssh web ls -lt /tmp/xdebug/cachegrind.out.* | head -3

# Analyze with callgrind_annotate (install if needed)
ssh web bash -c "
  which callgrind_annotate || (apt-get update -qq && apt-get install -y -qq valgrind > /dev/null 2>&1)
  callgrind_annotate --inclusive=yes /tmp/xdebug/CACHEGRIND_FILE | head -80
"

# Or quick PHP analysis of top 20 expensive functions
ssh web php -r "
\$lines = file('/tmp/xdebug/CACHEGRIND_FILE');
\$fns = []; \$cur = '';
foreach (\$lines as \$l) {
    \$l = trim(\$l);
    if (strpos(\$l, 'fn=') === 0) \$cur = substr(\$l, 3);
    elseif (preg_match('/^(\d+) (\d+)$/', \$l, \$m) && \$cur) {
        \$fns[\$cur] = (\$fns[\$cur] ?? 0) + (int)\$m[2];
    }
}
arsort(\$fns);
printf(\"%-55s %12s\n\", 'Function', 'Cost');
echo str_repeat('-', 68) . \"\n\";
foreach (array_slice(\$fns, 0, 20) as \$fn => \$cost) {
    printf(\"%-55s %12d\n\", substr(\$fn, 0, 55), \$cost);
}
"
```

## Workflow C: CLI Debugging (No PHP-FPM restart needed)

```bash
# Trace a Drush command (XDEBUG_MODE env var = single-command, zero impact)
ssh web bash -c 'XDEBUG_MODE=trace php -d xdebug.start_with_request=yes -d xdebug.output_dir=/tmp/xdebug -d xdebug.trace_format=1 -d xdebug.collect_return=1 -d xdebug.trace_output_name=trace.%t.%p ./vendor/bin/drush cr'

# Profile a Drush command
ssh web bash -c 'XDEBUG_MODE=profile php -d xdebug.start_with_request=yes -d xdebug.output_dir=/tmp/xdebug -d xdebug.profiler_output_name=cachegrind.out.%t.%p ./vendor/bin/drush status'
```

## ALWAYS: Disable and Cleanup

```bash
# Disable Xdebug (CRITICAL — leaving it on kills performance)
ssh web bash -c "
  PHP_VER=\$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;')
  rm -f /etc/php/\${PHP_VER}/fpm/conf.d/99-xdebug-custom.ini
  kill -USR2 \$(pgrep -o php-fpm)
"

# Clean up output files
ssh web rm -rf /tmp/xdebug/*
```

## Quick Reference

| Problem | Mode | Action |
|---------|------|--------|
| Page error / 500 / white screen | trace | Find exception/error in trace output |
| Slow page / timeout | profile | Find top expensive functions in cachegrind |
| Drush command fails / slow | CLI workflow | No FPM restart needed |
| See execution path for URL | trace | Read full function call tree |

- **Always disable Xdebug after debugging** — it adds 20-50% overhead
- Trace files can be 100MB+ — use `head` or `grep` to filter
- For Playwright: add `?XDEBUG_TRIGGER=1` to the URL in `browser_navigate`
- Replace `TRACE_FILE` / `CACHEGRIND_FILE` with actual filenames from `ls`
