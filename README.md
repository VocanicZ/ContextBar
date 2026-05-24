# ContextBar

A `/context`-style colored block bar for the **status line** of [Claude Code](https://claude.com/claude-code) — see your context usage at a glance on every prompt.

```
82.7k ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛀ ⛶ ⛶ ⛶ (83%|8%)
```

## Format

```
<cur>k <bar> (<max_bar%>|<actual_max%>)
```

| part | meaning |
|------|---------|
| `cur` | current total context, in thousands of tokens |
| `bar` | 20 colored blocks spanning `0 .. max_bar`. Fills completely at `max_bar`. Colors match `/context` categories (system prompt, tools, agents, memory, skills, messages). |
| `max_bar%` | `cur` as a percentage of **max_bar** — your configurable indicator |
| `actual_max%` | `cur` as a percentage of the model's **actual** context limit |

**max_bar** is a threshold you choose so the bar fills at a point that matters to *you*.
Example: on a 1M-context model you might set `max_bar = 100k` — the bar is full once
context reaches 100k, while `actual_max%` still shows how far you are from the real 1M limit.

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/VocanicZ/ContextBar/main/install.sh | bash
```

You'll be prompted for **scope** and **max_bar**. To skip the prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/VocanicZ/ContextBar/main/install.sh \
  | bash -s -- --scope user --max-bar 150000
```

Restart Claude Code (or wait for the status line refresh) to see the bar.

### Installer flags

| flag | values | meaning |
|------|--------|---------|
| `--scope` | `project` `user` `system` | which `settings.json` to write |
| `--max-bar` | tokens | bar full-point (the indicator). Default `min(150000, actual_max)` |
| `--actual-max` | tokens | override the detected model context limit |

### Scope → file

| scope | file | notes |
|-------|------|-------|
| `project` | `./.claude/settings.json` | shared with the repo |
| `user` | `~/.claude/settings.json` | all your projects |
| `system` | `/etc/claude-code/managed-settings.json` | machine-wide (needs `sudo`) |

The script itself is always installed to `~/.claude/contextbar/statusline.sh`; each scope's
`settings.json` just references it with its own baked-in `max_bar`.

## Configuration

`max_bar` is baked into the `statusLine` command per scope at install time. You can also
control everything at runtime via environment variables on the command:

| env var | default | meaning |
|---------|---------|---------|
| `CONTEXTBAR_MAX_BAR` | `min(150000, actual_max)` | bar full-point, in tokens |
| `CONTEXTBAR_ACTUAL_MAX` | from model table | override the model context limit |
| `CONTEXTBAR_BLOCKS` | `20` | number of blocks in the bar |

### Model context limits

`actual_max` is detected from `model.id`:

| model | actual_max |
|-------|-----------|
| `*sonnet*` | 1,000,000 |
| `*opus*` | 200,000 |
| `*haiku*` | 200,000 |
| (unknown) | 200,000 |

Override per install with `--actual-max`, or per run with `CONTEXTBAR_ACTUAL_MAX`.

## How it reads usage

ContextBar reads the most recent `usage` block from the session transcript
(`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`). The category sizes
(system prompt, tools, etc.) are approximations matching `/context`; only Claude Code's
internal `/context` knows the exact values.

## Requirements

- `bash`, `jq`, `awk`, `curl`
- A terminal/font with Unicode block glyphs (`⛁ ⛀ ⛶`)

## Pairs with UsageBar

ContextBar shares the single status line with [UsageBar](https://github.com/VocanicZ/UsageBar)
(Claude usage-limit meters). When both are installed, a small composer keeps **context on the
left and usage on the right**, in any install order. ContextBar records itself in
`~/.claude/statusbar/parts.json`; if `~/.claude/statusbar/compose.sh` (shipped by UsageBar)
is present, the status line is driven through it. ContextBar runs standalone when UsageBar
isn't installed.

## Uninstall

Remove the `"statusLine"` key from the relevant `settings.json` and delete
`~/.claude/contextbar/`.

## License

MIT
