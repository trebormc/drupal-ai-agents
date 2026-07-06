# Model Strategy

## Token System

Agent files use model tokens instead of hardcoded model names. This makes agents portable across OpenCode and Claude Code.

| Token | Claude Code | Purpose |
|-------|-------------|---------|
| `$MODEL_MAIN` | Sonnet | The orchestrator: main conversation loop that receives prompts and delegates |
| `$MODEL_GENIUS` | Opus | Hardest tasks: important code reviews, architecture decisions |
| `$MODEL_SMART` | Opus | Quality gates, planning, deep research, delegation advice |
| `$MODEL_NORMAL` | Sonnet | Development, review, content generation |
| `$MODEL_CHEAP` | Haiku | Exploration, fast tasks, code navigation |
| `$MODEL_APPLIER` | Haiku | Mechanical code application (zero creativity) |
| `$MODEL_VISION` | Sonnet | Image/screenshot interpretation — must accept image input |

Backward compatibility: when an `.env.agents` file does not define them, `GENIUS` falls back to the `SMART` value, `VISION` falls back to the `NORMAL` value, and `MAIN` falls back to `CHEAP` on OpenCode and `NORMAL` on Claude Code. Most non-Claude NORMAL/CHEAP models are text-only — anything that must SEE an image goes through `$MODEL_VISION`.

`$MODEL_MAIN` is not an agent token: it sets the DEFAULT model of the tool itself — the top-level `model` in the generated `opencode.json` and the `model` key in the generated Claude Code settings. Telemetry shows the main conversation dominates session cost (~75% in measured sessions), so it is deliberately a cheap tier: the orchestrator coordinates and delegates (asking `task-router` when routing is unclear) instead of doing specialist work.

## Agent-Model Assignments

| Agent | Token | Justification |
|-------|-------|---------------|
| code-review | $MODEL_GENIUS | Code quality evaluation requires maximum capability |
| output-verifier | $MODEL_SMART | Quality gate for non-code outputs |
| ralph-planner | $MODEL_SMART | Complex planning for autonomous execution |
| task-router | $MODEL_SMART | Routing decisions need strong judgment; the cheap orchestrator consults it |
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
OC_MODEL_MAIN=opencode/deepseek-v4-flash
OC_MODEL_GENIUS=opencode/glm-5.2
OC_MODEL_SMART=opencode/glm-5.2
OC_MODEL_NORMAL=opencode/deepseek-v4-pro
OC_MODEL_CHEAP=opencode/deepseek-v4-flash
OC_MODEL_APPLIER=opencode/gpt-5-nano
OC_MODEL_VISION=opencode/minimax-m3

# Claude Code models
CC_MODEL_MAIN=sonnet
CC_MODEL_GENIUS=opus
CC_MODEL_SMART=opus
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
CC_MODEL_VISION=sonnet
```

## Cost Optimization

The single biggest cost lever is `$MODEL_MAIN`: the main conversation loop dominates spend (~75% in measured sessions), not the subagents. The strategy is a cheap orchestrator that delegates to specialists — directly when the routing is clear, or after consulting `task-router` ($MODEL_SMART) when it is not. Expensive models are reserved for punctual, high-value steps (code-review, planning, verification) invoked as subagents.

Development agents (drupal-dev, drupal-theme, drupal-test-generator) intentionally run on $MODEL_NORMAL instead of $MODEL_SMART: their prompts are structured (exact commands, decision tables, verification steps) so they do not require top-tier reasoning. Quality is protected by the $MODEL_SMART gates (code-review, output-verifier). If budget is tight, downgrade $MODEL_NORMAL agents before touching the quality gates — never downgrade code-review first.

Delegation is not free: a subagent starts with a cold cache and re-reads context as fresh input, which can cost more than a warm cached read on the main model. Delegate work that is output/reasoning-heavy and context-light; handle trivial or context-heavy steps inline.
