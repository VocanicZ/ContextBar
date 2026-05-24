# ContextBar — design

## Goal

Publish the author's Claude Code first-line context-usage bar as a reusable tool with a
one-line install script. Reformat the label to expose two reference points: a user-chosen
indicator (`max_bar`) and the model's real context limit (`actual_max`).

## Output format

```
<cur>k <bar> (<max_bar%>|<actual_max%>)
```

- `cur` — current total context tokens / 1000.
- `bar` — `BLOCKS` (default 20) colored glyphs spanning `0 .. max_bar`. Auto-adjusts: one
  block = `max_bar / BLOCKS` tokens. Full at `cur >= max_bar`. Category coloring preserved
  from `/context` (system prompt, tools, agents, memory, skills, messages).
- `max_bar%` — `round(cur*100/max_bar)`. The configurable indicator.
- `actual_max%` — `round(cur*100/actual_max)`. Distance from the real model limit.

## Configuration model

| value | source | default |
|-------|--------|---------|
| `actual_max` | `CONTEXTBAR_ACTUAL_MAX`, else lookup by `model.id` | 200000 (sonnet → 1000000) |
| `max_bar` | `CONTEXTBAR_MAX_BAR` | `min(150000, actual_max)`, clamped `<= actual_max` |
| `BLOCKS` | `CONTEXTBAR_BLOCKS` | 20 |

`max_bar` is baked into each scope's `statusLine` command string at install time, so scopes
are independent.

## Components

- **statusline.sh** — reads the status-line JSON on stdin, derives `total` from the latest
  transcript `usage` block, resolves config, renders the bar + label. No external state.
- **install.sh** — one-line `curl | bash`. Resolves scope → settings path, prompts via
  `/dev/tty` when flags are absent, installs the script to `~/.claude/contextbar/`, and
  patches the chosen `settings.json` `.statusLine` via `jq`. Falls back to copying a local
  `statusline.sh` when run from a clone instead of curling.

## Scope → settings path

| scope | path | privilege |
|-------|------|-----------|
| project | `./.claude/settings.json` | user |
| user | `~/.claude/settings.json` | user |
| system | `/etc/claude-code/managed-settings.json` | sudo |

## Decisions

- **Strip the personal `graphify` indicator** from the source bar; keep category coloring.
- **Lookup table + env override** for `actual_max` (vs forcing the user to configure it).
- **max_bar baked per scope** into the command string (vs a shared config file) for
  scope independence and zero extra files to read at render time.
