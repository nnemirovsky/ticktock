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
