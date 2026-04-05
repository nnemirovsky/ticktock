---
name: ticktock
description: Configure ticktock time awareness plugin — toggle hooks on/off, set elapsed threshold, manage timezone
argument-hint: '[on|off|threshold <seconds>|hook <name> on|off|tz [auto|on|off|<timezone>]]'
---

# ticktock Configuration

Manage the ticktock time awareness plugin. Config is stored at `~/.claude/ticktock.json`.

## Usage

When the user invokes `/ticktock`, parse their arguments and run the appropriate bash command:

### Show config
If no arguments (just `/ticktock`):
```bash
cat ~/.claude/ticktock.json 2>/dev/null || echo "No config found — ticktock will use defaults"
```
Display the result in a readable table format, followed by available commands:

```
Commands:
  /ticktock                        Show current config
  /ticktock on|off                 Enable/disable all hooks
  /ticktock threshold <seconds>    Set elapsed time threshold
  /ticktock hook <name> on|off     Toggle individual hook
                                   (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse)
  /ticktock tz                     Show current timezone setting
  /ticktock tz <timezone>          Set timezone (IANA name or UTC offset)
  /ticktock tz auto                Revert to system timezone auto-detection
  /ticktock tz on|off              Show/hide timezone in timestamps
```

### Enable/disable all
`/ticktock on` or `/ticktock off`:
```bash
# on:
jq '.enabled = true' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
# off:
jq '.enabled = false' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
```

### Set threshold
`/ticktock threshold <seconds>`:
```bash
jq '.thresholdSeconds = <seconds>' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
```

### Toggle individual hook
`/ticktock hook <HookName> on|off`:
Valid hook names: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`
```bash
# on:
jq '.hooks.<HookName> = true' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
# off:
jq '.hooks.<HookName> = false' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
```

### Show timezone
`/ticktock tz` (no additional arguments):
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/common.sh"
tz_val=$(ticktock_timezone)
show_tz=$(ticktock_show_timezone && echo "true" || echo "false")
resolved=$(ticktock_resolve_tz_offset)
echo "timezone: ${tz_val}"
echo "showTimezone: ${show_tz}"
echo "resolved: ${resolved}"
```
Display the timezone setting, whether display is on/off, and the resolved UTC offset.

### Set timezone
`/ticktock tz <value>` where `<value>` is an IANA timezone name (e.g. `America/New_York`, `Europe/London`) or a UTC offset (e.g. `UTC+3`, `UTC-5:30`). Values are case-insensitive.

To validate and set the timezone, run:
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/common.sh"
normalized=$(ticktock_validate_timezone "<value>")
if [ $? -eq 0 ]; then
  jq --arg tz "$normalized" '.timezone = $tz' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
  echo "Timezone set to: $normalized"
else
  echo "Error: $normalized"
fi
```
If validation fails, display the error and do not update the config.

### Reset timezone to auto
`/ticktock tz auto`:
```bash
jq '.timezone = "auto"' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
```

### Toggle timezone display
`/ticktock tz on` or `/ticktock tz off`:
```bash
# on:
jq '.showTimezone = true' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
# off:
jq '.showTimezone = false' ~/.claude/ticktock.json > /tmp/ticktock-cfg.tmp && mv /tmp/ticktock-cfg.tmp ~/.claude/ticktock.json
```

After any change, display the updated config to confirm.
