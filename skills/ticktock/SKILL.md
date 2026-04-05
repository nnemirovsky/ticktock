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
tmpfile=$(mktemp)
jq '.enabled = true' ~/.claude/ticktock.json > "$tmpfile" && mv "$tmpfile" ~/.claude/ticktock.json
# off:
tmpfile=$(mktemp)
jq '.enabled = false' ~/.claude/ticktock.json > "$tmpfile" && mv "$tmpfile" ~/.claude/ticktock.json
```

### Set threshold
`/ticktock threshold <seconds>`:
```bash
tmpfile=$(mktemp)
jq '.thresholdSeconds = <seconds>' ~/.claude/ticktock.json > "$tmpfile" && mv "$tmpfile" ~/.claude/ticktock.json
```

### Toggle individual hook
`/ticktock hook <HookName> on|off`:
Valid hook names: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`
```bash
# on:
tmpfile=$(mktemp)
jq '.hooks.<HookName> = true' ~/.claude/ticktock.json > "$tmpfile" && mv "$tmpfile" ~/.claude/ticktock.json
# off:
tmpfile=$(mktemp)
jq '.hooks.<HookName> = false' ~/.claude/ticktock.json > "$tmpfile" && mv "$tmpfile" ~/.claude/ticktock.json
```

### Show timezone
`/ticktock tz` (no additional arguments):
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/common.sh"
tz_val=$(ticktock_timezone)
if ticktock_show_timezone; then show_tz="true"; else show_tz="false"; fi
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
ticktock_ensure_config
if normalized=$(ticktock_validate_timezone "<value>" 2>/dev/null); then
  tmpfile=$(mktemp)
  jq --arg tz "$normalized" '.timezone = $tz' "$TICKTOCK_CONFIG" > "$tmpfile" && mv "$tmpfile" "$TICKTOCK_CONFIG"
  echo "Timezone set to: $normalized"
else
  error=$(ticktock_validate_timezone "<value>" 2>&1 || true)
  echo "Error: $error"
fi
```
If validation fails, display the error and do not update the config.

### Reset timezone to auto
`/ticktock tz auto`:
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/common.sh"
ticktock_ensure_config
tmpfile=$(mktemp)
jq '.timezone = "auto"' "$TICKTOCK_CONFIG" > "$tmpfile" && mv "$tmpfile" "$TICKTOCK_CONFIG"
```

### Toggle timezone display
`/ticktock tz on` or `/ticktock tz off`:
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/common.sh"
ticktock_ensure_config
# on:
tmpfile=$(mktemp)
jq '.showTimezone = true' "$TICKTOCK_CONFIG" > "$tmpfile" && mv "$tmpfile" "$TICKTOCK_CONFIG"
# off:
tmpfile=$(mktemp)
jq '.showTimezone = false' "$TICKTOCK_CONFIG" > "$tmpfile" && mv "$tmpfile" "$TICKTOCK_CONFIG"
```

After any change, display the updated config to confirm.
