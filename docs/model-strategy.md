# Model Strategy

## Token System

Agent files use model tokens instead of hardcoded model names. This makes agents portable across OpenCode and Claude Code.

| Token | Claude Code | Purpose |
|-------|-------------|---------|
| `$MODEL_SMART` | Opus | Quality gates, planning, deep research |
| `$MODEL_NORMAL` | Sonnet | Development, review, content generation |
| `$MODEL_CHEAP` | Haiku | Exploration, fast tasks, code navigation |
| `$MODEL_APPLIER` | Haiku | Mechanical code application (zero creativity) |

## Agent-Model Assignments

| Agent | Token | Justification |
|-------|-------|---------------|
| code-review | $MODEL_SMART | Code quality evaluation requires maximum capability |
| deep-research | $MODEL_NORMAL | Multi-source investigation needs deep reasoning |
| ralph-planner | $MODEL_SMART | Complex planning for autonomous execution |
| drupal-dev | $MODEL_NORMAL | Structured development with clear patterns |
| drupal-theme | $MODEL_NORMAL | Frontend work with established conventions |
| output-verifier | $MODEL_NORMAL | Validation is less complex than evaluation |
| visual-test | $MODEL_NORMAL | Needs to interpret visual screenshots |
| code-explorer | $MODEL_CHEAP | Navigation only, no deep analysis |
| applier | $MODEL_APPLIER | Mechanical application, zero creativity needed |

## Changing Models

Edit `.env.agents` to change which models all agents use:

```bash
# OpenCode models
OC_MODEL_SMART=opencode/kimi-k2.5
OC_MODEL_NORMAL=opencode/minimax-m2.5
OC_MODEL_CHEAP=opencode/gpt-5-nano
OC_MODEL_APPLIER=opencode/gpt-5-nano

# Claude Code models
CC_MODEL_SMART=opus
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
```

## Cost Optimization

Moving drupal-dev and drupal-theme from $MODEL_SMART to $MODEL_NORMAL can reduce costs 40-60% per development session without notable quality loss, since these agents operate with structured instructions that don't require Opus-level reasoning.
