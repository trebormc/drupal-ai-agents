# Model Strategy

## Token System

Agent files use model tokens instead of hardcoded model names. This makes agents portable across OpenCode and Claude Code.

| Token | Claude Code | Purpose |
|-------|-------------|---------|
| `$MODEL_GENIUS` | Opus | Hardest tasks: important code reviews, architecture decisions |
| `$MODEL_SMART` | Opus | Quality gates, planning, deep research |
| `$MODEL_NORMAL` | Sonnet | Development, review, content generation |
| `$MODEL_CHEAP` | Haiku | Exploration, fast tasks, code navigation |
| `$MODEL_APPLIER` | Haiku | Mechanical code application (zero creativity) |
| `$MODEL_VISION` | Sonnet | Image/screenshot interpretation — must accept image input |

Backward compatibility: when an `.env.agents` file does not define them, `GENIUS` falls back to the `SMART` value and `VISION` falls back to the `NORMAL` value. Most non-Claude NORMAL/CHEAP models are text-only — anything that must SEE an image goes through `$MODEL_VISION`.

## Agent-Model Assignments

| Agent | Token | Justification |
|-------|-------|---------------|
| code-review | $MODEL_GENIUS | Code quality evaluation requires maximum capability |
| output-verifier | $MODEL_SMART | Quality gate for non-code outputs |
| ralph-planner | $MODEL_SMART | Complex planning for autonomous execution |
| deep-research | $MODEL_NORMAL | Multi-source investigation needs deep reasoning |
| drupal-dev | $MODEL_NORMAL | Structured development with clear patterns |
| drupal-theme | $MODEL_NORMAL | Frontend work with established conventions |
| drupal-test-generator | $MODEL_NORMAL | Test generation follows skill templates |
| visual-test | $MODEL_VISION | Captures pages and verifies rendering; needs image input |
| visual-analyzer | $MODEL_VISION | Interprets image content: design review, comparisons |
| code-explorer | $MODEL_CHEAP | Navigation only, no deep analysis |
| applier | $MODEL_APPLIER | Mechanical application, zero creativity needed |

## Changing Models

Edit `.env.agents` to change which models all agents use:

```bash
# OpenCode models
OC_MODEL_GENIUS=opencode/glm-5.2
OC_MODEL_SMART=opencode/glm-5.2
OC_MODEL_NORMAL=opencode/deepseek-v4-pro
OC_MODEL_CHEAP=opencode/deepseek-v4-flash
OC_MODEL_APPLIER=opencode/gpt-5-nano
OC_MODEL_VISION=opencode/minimax-m3

# Claude Code models
CC_MODEL_GENIUS=opus
CC_MODEL_SMART=opus
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
CC_MODEL_VISION=sonnet
```

## Cost Optimization

Development agents (drupal-dev, drupal-theme, drupal-test-generator) intentionally run on $MODEL_NORMAL instead of $MODEL_SMART: their prompts are structured (exact commands, decision tables, verification steps) so they do not require top-tier reasoning. Quality is protected by the $MODEL_SMART gates (code-review, output-verifier). If budget is tight, downgrade $MODEL_NORMAL agents before touching the quality gates — never downgrade code-review first.
