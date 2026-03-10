# ticktock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that injects timestamps into Claude's context via hooks, with smart elapsed-time filtering and configurable per-hook toggling.

**Architecture:** Four bash hook handlers (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse) share a common library. Each handler checks a JSON config file to see if it's enabled, reads the last-action timestamp from a temp file, computes elapsed time, and outputs a formatted timestamp string to stdout. A `/ticktock` slash command lets users toggle hooks and configure the threshold.

**Tech Stack:** Bash, jq, date (BSD/macOS), Claude Code plugin system (hooks.json + skills)

---

### Task 1: Initialize repo and plugin scaffolding

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `hooks/hooks.json`
- Create: `LICENSE`
- Create: `CLAUDE.md`

**Step 1: Initialize git repo**

```bash
cd /Users/nemirovsky/Developer/ticktock
git init
```

**Step 2: Create plugin.json**

Create `.claude-plugin/plugin.json`:
```json
{
  "name": "ticktock",
  "version": "0.1.0",
  "description": "Time awareness for Claude Code — injects timestamps and elapsed time into context via hooks"
}
```

**Step 3: Create marketplace.json**

Create `.claude-plugin/marketplace.json`:
```json
{
  "name": "ticktock",
  "version": "0.1.0",
  "description": "Time awareness for Claude Code — injects timestamps and elapsed time into context via hooks",
  "owner": {
    "name": "nnemirovsky"
  },
  "plugins": [
    {
      "name": "ticktock",
      "source": "./",
      "description": "Time awareness for Claude Code — injects timestamps and elapsed time into context via hooks"
    }
  ]
}
```

**Step 4: Create hooks.json**

Create `hooks/hooks.json`:
```json
{
  "description": "ticktock — time awareness hooks for Claude Code",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/session-start.sh",
            "async": false
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/user-prompt.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/pre-tool-use.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handlers/post-tool-use.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Step 5: Create LICENSE (MIT)**

Standard MIT license with copyright "2026 Nikita Nemirovsky".

**Step 6: Create CLAUDE.md**

Create `CLAUDE.md` with build/test/lint instructions for the project.

**Step 7: Commit**

```bash
git add .claude-plugin/ hooks/hooks.json LICENSE CLAUDE.md
git commit -m "feat: initialize ticktock plugin scaffolding"
```

---

### Task 2: Build common.sh shared library

**Files:**
- Create: `hooks/handlers/common.sh`

This is the core logic. All handlers source this file.

**Step 1: Write common.sh**

Create `hooks/handlers/common.sh`:
```bash
#!/usr/bin/env bash
# ticktock common library — sourced by all hook handlers
# Provides: config reading, elapsed computation, timestamp formatting

set -euo pipefail

TICKTOCK_CONFIG="${HOME}/.claude/ticktock.json"
TICKTOCK_DEFAULT_THRESHOLD=30

# Create default config if missing
ticktock_ensure_config() {
  if [ ! -f "$TICKTOCK_CONFIG" ]; then
    mkdir -p "$(dirname "$TICKTOCK_CONFIG")"
    cat > "$TICKTOCK_CONFIG" << 'CONF'
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
CONF
  fi
}

# Check if ticktock is globally enabled and this specific hook is enabled
# Args: $1 = hook name (e.g. "SessionStart")
# Returns: 0 if enabled, 1 if disabled
ticktock_is_enabled() {
  local hook_name="$1"
  ticktock_ensure_config

  local global
  global=$(jq -r '.enabled // true' "$TICKTOCK_CONFIG" 2>/dev/null || echo "true")
  if [ "$global" != "true" ]; then
    return 1
  fi

  local hook_enabled
  hook_enabled=$(jq -r ".hooks.${hook_name} // true" "$TICKTOCK_CONFIG" 2>/dev/null || echo "true")
  if [ "$hook_enabled" != "true" ]; then
    return 1
  fi

  return 0
}

# Get threshold from config
ticktock_threshold() {
  ticktock_ensure_config
  jq -r ".thresholdSeconds // ${TICKTOCK_DEFAULT_THRESHOLD}" "$TICKTOCK_CONFIG" 2>/dev/null || echo "$TICKTOCK_DEFAULT_THRESHOLD"
}

# Get temp file path for storing last timestamp
ticktock_temp_file() {
  local session_id="${CLAUDE_SESSION_ID:-default}"
  echo "/tmp/ticktock-${session_id}"
}

# Read last timestamp (epoch seconds) from temp file
# Returns: epoch seconds, or empty string if no previous timestamp
ticktock_last_timestamp() {
  local tmp
  tmp=$(ticktock_temp_file)
  if [ -f "$tmp" ]; then
    cat "$tmp"
  else
    echo ""
  fi
}

# Write current timestamp to temp file
ticktock_save_timestamp() {
  local tmp
  tmp=$(ticktock_temp_file)
  date +%s > "$tmp"
}

# Format elapsed seconds as human-readable string
# Args: $1 = elapsed seconds
# Returns: formatted string like "3m25s" or "1h2m"
ticktock_format_elapsed() {
  local total="$1"
  local hours=$((total / 3600))
  local minutes=$(((total % 3600) / 60))
  local seconds=$((total % 60))

  if [ "$hours" -gt 0 ]; then
    echo "${hours}h${minutes}m"
  elif [ "$minutes" -gt 0 ]; then
    echo "${minutes}m${seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Main output function — computes elapsed and prints formatted timestamp
# Args: $1 = hook name (for config check)
# Outputs: formatted timestamp string to stdout, or nothing if disabled
ticktock_emit() {
  local hook_name="$1"

  if ! ticktock_is_enabled "$hook_name"; then
    exit 0
  fi

  local now_epoch
  now_epoch=$(date +%s)
  local now_time
  now_time=$(date +"%H:%M:%S")
  local threshold
  threshold=$(ticktock_threshold)
  local last
  last=$(ticktock_last_timestamp)

  local output
  if [ -z "$last" ]; then
    output="[${now_time}]"
  else
    local elapsed=$((now_epoch - last))
    if [ "$elapsed" -ge "$threshold" ]; then
      local formatted
      formatted=$(ticktock_format_elapsed "$elapsed")
      output="[${now_time} | +${formatted}]"
    else
      output="[${now_time}]"
    fi
  fi

  ticktock_save_timestamp
  echo "$output"
}
```

**Step 2: Make executable**

```bash
chmod +x hooks/handlers/common.sh
```

**Step 3: Commit**

```bash
git add hooks/handlers/common.sh
git commit -m "feat: add common.sh shared library with config, elapsed, and formatting"
```

---

### Task 3: Build hook handler scripts

**Files:**
- Create: `hooks/handlers/session-start.sh`
- Create: `hooks/handlers/user-prompt.sh`
- Create: `hooks/handlers/pre-tool-use.sh`
- Create: `hooks/handlers/post-tool-use.sh`

**Step 1: Write session-start.sh**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if ! ticktock_is_enabled "SessionStart"; then
  exit 0
fi

ticktock_save_timestamp
NOW=$(date +"%Y-%m-%d %H:%M:%S")

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "[Session started: ${NOW}]"
  }
}
EOF

exit 0
```

Note: SessionStart uses `additionalContext` JSON format (not plain stdout) per Claude Code hook protocol.

**Step 2: Write user-prompt.sh**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ticktock_emit "UserPromptSubmit"
exit 0
```

**Step 3: Write pre-tool-use.sh**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ticktock_emit "PreToolUse"
exit 0
```

**Step 4: Write post-tool-use.sh**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ticktock_emit "PostToolUse"
exit 0
```

**Step 5: Make all executable**

```bash
chmod +x hooks/handlers/*.sh
```

**Step 6: Test manually**

```bash
cd /Users/nemirovsky/Developer/ticktock
# Test with no config (should create default)
CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
# Expected: [HH:MM:SS]

# Wait a moment and run again
sleep 1
CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
# Expected: [HH:MM:SS] (under threshold)

# Test session start
CLAUDE_SESSION_ID=test bash hooks/handlers/session-start.sh
# Expected: JSON with additionalContext containing [Session started: ...]
```

**Step 7: Commit**

```bash
git add hooks/handlers/
git commit -m "feat: add all four hook handler scripts"
```

---

### Task 4: Build /ticktock slash command skill

**Files:**
- Create: `skills/ticktock/SKILL.md`

**Step 1: Write SKILL.md**

Create `skills/ticktock/SKILL.md`:
```markdown
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
```

**Step 2: Commit**

```bash
git add skills/
git commit -m "feat: add /ticktock slash command skill for config management"
```

---

### Task 5: Write README.md and test end-to-end

**Files:**
- Create: `README.md`

**Step 1: Write README.md**

Standard README with:
- What it does (1 paragraph)
- Installation: `claude plugin add ticktock@ticktock` (or from marketplace)
- Output format examples
- Configuration section showing default config and `/ticktock` commands
- Dependencies: bash, jq
- License: MIT

**Step 2: Test the full plugin locally**

```bash
cd /Users/nemirovsky/Developer/ticktock

# Verify all scripts are executable
ls -la hooks/handlers/

# Test session-start handler
CLAUDE_SESSION_ID=test-e2e bash hooks/handlers/session-start.sh
# Expected: valid JSON with additionalContext

# Test user-prompt handler (first call — no previous timestamp)
rm -f /tmp/ticktock-test-e2e
CLAUDE_SESSION_ID=test-e2e bash hooks/handlers/user-prompt.sh
# Expected: [HH:MM:SS]

# Test with elapsed below threshold
CLAUDE_SESSION_ID=test-e2e bash hooks/handlers/pre-tool-use.sh
# Expected: [HH:MM:SS]

# Test with elapsed above threshold (fake old timestamp)
echo "1" > /tmp/ticktock-test-e2e
CLAUDE_SESSION_ID=test-e2e bash hooks/handlers/post-tool-use.sh
# Expected: [HH:MM:SS | +XXyXXm] (very large elapsed)

# Test disable via config
jq '.hooks.PreToolUse = false' ~/.claude/ticktock.json > /tmp/tt.tmp && mv /tmp/tt.tmp ~/.claude/ticktock.json
CLAUDE_SESSION_ID=test-e2e bash hooks/handlers/pre-tool-use.sh
# Expected: no output (disabled)

# Restore
jq '.hooks.PreToolUse = true' ~/.claude/ticktock.json > /tmp/tt.tmp && mv /tmp/tt.tmp ~/.claude/ticktock.json

# Cleanup
rm -f /tmp/ticktock-test-e2e
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation, usage, and configuration"
```

---

### Task 6: Create GitHub repo and push

**Step 1: Create GitHub repo**

```bash
cd /Users/nemirovsky/Developer/ticktock
gh repo create ticktock --public --description "Time awareness plugin for Claude Code — injects timestamps and elapsed time into context via hooks" --source . --push
```

**Step 2: Verify**

```bash
gh repo view ticktock
```
