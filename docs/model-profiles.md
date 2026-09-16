# Model profiles

Three ready-made `.env.agents` overrides. Copy one to `~/.ddev/agents-sync/.env.agents`
(all your projects) or `.ddev/.env.agents` (one project), then `ddev agents-update &&
ddev restart`. Each level of the cascade only needs the variables it changes; anything
not listed keeps the repo default. Model ids are examples: replace them with the ones
your providers expose (`opencode models` lists OpenCode's).

## Premium (the repo defaults)

Best quality, highest cost. Keep the repo defaults; nothing to override. On Claude Code:
`opus` for GENIUS/SMART, `sonnet` for MAIN/NORMAL/VISION, `haiku` for CHEAP/APPLIER.

## Cheap (paid APIs, low cost)

```bash
# Claude Code: everything on the mid tier, only the judge on opus
CC_MODEL_MAIN=sonnet
CC_MODEL_GENIUS=opus
CC_MODEL_SMART=sonnet
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
CC_MODEL_VISION=sonnet

# OpenCode: the repo defaults already are the cheap profile (deepseek / glm / minimax)
```

## Local (models served on your machine, near-zero cost)

Point OpenCode at a local provider (Ollama, LM Studio, vLLM) configured in
`~/.ddev/opencode/config/opencode.json`, then map the tokens. Keep one capable remote
model for GENIUS and VISION unless your local models can review code and see images:

```bash
OC_MODEL_MAIN=<provider>/<small-local-model>
OC_MODEL_GENIUS=opencode/glm-5.2          # keep a strong remote judge
OC_MODEL_SMART=<provider>/<largest-local-model>
OC_MODEL_NORMAL=<provider>/<coding-local-model>
OC_MODEL_CHEAP=<provider>/<small-local-model>
OC_MODEL_APPLIER=<provider>/<small-local-model>
OC_MODEL_VISION=opencode/minimax-m3       # local text-only models cannot see screenshots
```

What to expect from each profile with this pack: the rules and playbooks are written for
a weaker model (exact commands, fixed return formats, mechanical checks before
judgment), so the local profile works for well-specified tasks; keep GENIUS remote,
because the code-review judge and the arena's project manager are where weak judgment
costs the most. Measure instead of guessing: run the same task through two profiles as
arena candidates (`ai-arena init ... --candidates opencode,claude:sonnet`) and read the
wins log.
