# ticktock

Time awareness for Claude Code.

## What it does

ticktock is a Claude Code plugin that injects timestamps into Claude's context via hooks, so Claude always knows the current time and how long has passed between interactions. Smart filtering only shows elapsed time when the gap exceeds a configurable threshold (default 30 seconds), keeping token usage minimal during rapid back-and-forth exchanges.

## Output examples

Below threshold (rapid interaction):
```
[14:32:15 UTC-7]
```

Above threshold (gap exceeded 30s):
```
[14:32:15 UTC-7 | +3m25s]
```

Session start:
```
[Session started: 2026-04-05 14:30:00 UTC-7]
```

With timezone display disabled (`/ticktock tz off`):
```
[14:32:15]
```

## Installation

From the CLI:
```bash
claude plugin marketplace add nnemirovsky/ticktock
claude plugin install ticktock
```

Or interactively inside Claude Code:
```
/plugin marketplace add nnemirovsky/ticktock
/plugin install ticktock
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
  "thresholdSeconds": 30,
  "showTimezone": true,
  "timezone": "auto"
}
```

- `showTimezone`: whether to append timezone offset to timestamps (default: `true`)
- `timezone`: timezone to use. `"auto"` detects from system. Also accepts IANA names (`America/New_York`) or UTC offsets (`UTC+3`, `UTC-5:30`). Case-insensitive.

### Slash commands

| Command | Description |
|---|---|
| `/ticktock` | Show current configuration |
| `/ticktock on` | Enable ticktock |
| `/ticktock off` | Disable ticktock |
| `/ticktock threshold <seconds>` | Set elapsed time threshold |
| `/ticktock hook <name> on\|off` | Toggle an individual hook |
| `/ticktock tz` | Show current timezone setting |
| `/ticktock tz <timezone>` | Set timezone (IANA name or UTC offset) |
| `/ticktock tz auto` | Revert to system timezone auto-detection |
| `/ticktock tz on\|off` | Show/hide timezone in timestamps |

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
