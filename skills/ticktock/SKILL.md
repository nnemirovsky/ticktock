---
name: ticktock
description: Configure ticktock time awareness plugin — toggle hooks on/off, set elapsed threshold
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
Display the result in a readable format.

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

After any change, display the updated config to confirm.
