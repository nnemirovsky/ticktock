# ticktock

Time awareness for Claude Code.

## What it does

ticktock is a Claude Code plugin that injects timestamps into Claude's context via hooks, so Claude always knows the current time and how long has passed between interactions. Smart filtering only shows elapsed time when the gap exceeds a configurable threshold (default 30 seconds), keeping token usage minimal during rapid back-and-forth exchanges.

## Output examples

Below threshold (rapid interaction):
```
[14:32:15]
```

Above threshold (gap exceeded 30s):
```
[14:32:15 | +3m25s]
```

Session start:
```
[Session started: 2026-03-10 14:30:00]
```

## Installation

```bash
claude plugin add nnemirovsky/ticktock
```

## Configuration

ticktock stores its configuration at `~/.claude/ticktock.json`. A default config is created automatically on first run:

```json
{
  "enabled": true,
  "hooks": {
    "SessionStart": true,
    "UserPromptSubmit": true,
    "PreToolUse": true,
    "PostToolUse": true
  },
  "thresholdSeconds": 30
}
```

### Slash commands

| Command | Description |
|---|---|
| `/ticktock` | Show current configuration |
| `/ticktock on` | Enable ticktock |
| `/ticktock off` | Disable ticktock |
| `/ticktock threshold <seconds>` | Set elapsed time threshold |
| `/ticktock hook <name> on\|off` | Toggle an individual hook |

Valid hook names: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`.

## Hooks

| Hook | Fires when | What it reveals |
|---|---|---|
| `SessionStart` | Session starts, resumes, or is cleared/compacted | Full date and time of session start |
| `UserPromptSubmit` | User submits a prompt | Current time; elapsed time since last interaction |
| `PreToolUse` | Before a tool is invoked | Current time; how long since the previous action |
| `PostToolUse` | After a tool completes | Current time; how long the tool execution took |

## Dependencies

- bash (4.0+)
- jq (`brew install jq` on macOS)

## License

MIT
