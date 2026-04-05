#!/usr/bin/env bash
# ticktock common library — sourced by all hook handlers
# Provides: config reading, elapsed computation, timestamp formatting

set -euo pipefail

TICKTOCK_CONFIG="${TICKTOCK_CONFIG:-${HOME}/.claude/ticktock.json}"
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
  "thresholdSeconds": 30,
  "showTimezone": true,
  "timezone": "auto"
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

# Check if timezone display is enabled (default: true)
ticktock_show_timezone() {
  ticktock_ensure_config
  local val
  val=$(jq -r 'if has("showTimezone") then .showTimezone else true end' "$TICKTOCK_CONFIG" 2>/dev/null || echo "true")
  [ "$val" = "true" ]
}

# Get configured timezone value (default: "auto")
ticktock_timezone() {
  ticktock_ensure_config
  jq -r '.timezone // "auto"' "$TICKTOCK_CONFIG" 2>/dev/null || echo "auto"
}

# Convert a +HHMM / -HHMM offset string from `date +%z` to a display string like UTC-7 or UTC+5:30
# Args: $1 = offset string (e.g. "+0530", "-0700")
# Output: display string (e.g. "UTC+5:30", "UTC-7")
_ticktock_offset_to_display() {
  local raw="$1"
  local sign="${raw:0:1}"
  local hh="${raw:1:2}"
  local mm="${raw:3:2}"

  # Remove leading zeros from hours
  local hours=$((10#$hh))
  local minutes=$((10#$mm))

  if [ "$hours" -eq 0 ] && [ "$minutes" -eq 0 ]; then
    echo "UTC"
    return
  fi

  local display="UTC${sign}${hours}"
  if [ "$minutes" -gt 0 ]; then
    display="${display}:$(printf '%02d' "$minutes")"
  fi
  echo "$display"
}

# Normalize an IANA timezone name to its correctly-cased form by walking /usr/share/zoneinfo/.
# Uses iterative ls + grep -ix on each path component for case-insensitive matching.
# Args: $1 = IANA timezone name (e.g. "america/new_york")
# Output: correctly-cased name on stdout (e.g. "America/New_York")
# Returns: 0 on success, 1 if not found
ticktock_normalize_iana() {
  local input="$1"
  local zoneinfo="/usr/share/zoneinfo"

  # Split input on "/" into components
  local IFS="/"
  local -a parts
  read -ra parts <<< "$input"

  local base="$zoneinfo"
  for part in "${parts[@]}"; do
    local match
    match=$(ls "$base" 2>/dev/null | grep -ixF "$part" | head -1)
    if [ -z "$match" ]; then
      echo "unknown timezone: ${input}" >&2
      return 1
    fi
    base="${base}/${match}"
  done

  # Must resolve to a file (not a directory)
  if [ ! -f "$base" ]; then
    echo "unknown timezone: ${input}" >&2
    return 1
  fi

  # Strip the zoneinfo prefix to get the normalized IANA name
  echo "${base#${zoneinfo}/}"
  return 0
}

# Validate and normalize a timezone value.
# For IANA names: case-insensitive lookup in /usr/share/zoneinfo/
# For UTC offsets: validate format and range (-12 to +14)
# For "auto": pass through as-is
# Args: $1 = timezone value to validate
# Output: normalized value on stdout
# Returns: 0 on success, 1 with error message on stderr
ticktock_validate_timezone() {
  local input="$1"

  # Handle "auto" as a special value
  if [ "$input" = "auto" ]; then
    echo "auto"
    return 0
  fi

  # Check if it's a UTC offset (case-insensitive)
  local input_upper
  input_upper=$(echo "$input" | tr '[:lower:]' '[:upper:]')
  if [[ "$input_upper" =~ ^UTC([+-])([0-9]{1,2})(:[0-9]{2})?$ ]]; then
    local sign="${BASH_REMATCH[1]}"
    local hours="${BASH_REMATCH[2]}"
    local frac="${BASH_REMATCH[3]}"

    # Validate hour range: -12 to +14
    local hour_val=$((10#$hours))
    if [ "$sign" = "-" ] && [ "$hour_val" -gt 12 ]; then
      echo "invalid UTC offset: ${input} (range is UTC-12 to UTC+14)" >&2
      return 1
    fi
    if [ "$sign" = "+" ] && [ "$hour_val" -gt 14 ]; then
      echo "invalid UTC offset: ${input} (range is UTC-12 to UTC+14)" >&2
      return 1
    fi

    # Validate minutes if present (only 00, 15, 30, 45 are real-world UTC offsets)
    local min_val=0
    if [ -n "$frac" ]; then
      min_val=$((10#${frac#:}))
      case "$min_val" in
        0|15|30|45) ;;
        *)
          echo "invalid UTC offset minutes: ${input} (must be 00, 15, 30, or 45)" >&2
          return 1
          ;;
      esac
    fi

    # Reject combined boundary offsets: UTC+14 and UTC-12 only allow :00 minutes
    if [ "$min_val" -gt 0 ]; then
      if { [ "$sign" = "+" ] && [ "$hour_val" -ge 14 ]; } || \
         { [ "$sign" = "-" ] && [ "$hour_val" -ge 12 ]; }; then
        echo "invalid UTC offset: ${input} (UTC${sign}${hour_val} only allows :00 minutes)" >&2
        return 1
      fi
    fi

    # Normalize: uppercase UTC, strip leading zeros from hours
    echo "UTC${sign}${hour_val}${frac}"
    return 0
  fi

  # Check if input looks like a bad UTC offset (starts with UTC+/- but didn't match valid regex)
  # Plain "UTC" without a sign falls through to IANA lookup since /usr/share/zoneinfo/UTC exists
  if [[ "$input_upper" =~ ^UTC[+-] ]]; then
    echo "invalid UTC offset format: ${input} (expected UTC+N, UTC-N, UTC+N:MM, or UTC-N:MM)" >&2
    return 1
  fi

  # Try to normalize as an IANA timezone name
  ticktock_normalize_iana "$input"
}

# Classify the configured timezone value.
# Sets variables in the caller's scope:
#   _tz_type   = "auto", "offset", or "iana"
#   _tz_config = the raw config value
# For "offset" type, also sets parsed components:
#   _tz_sign   = "+" or "-"
#   _tz_hours  = hour digits (no leading zeros)
#   _tz_frac   = fractional part including colon (e.g. ":30") or empty
_ticktock_classify_tz() {
  _tz_config=$(ticktock_timezone)

  if [ "$_tz_config" = "auto" ]; then
    _tz_type="auto"
    return
  fi

  local tz_upper
  tz_upper=$(echo "$_tz_config" | tr '[:lower:]' '[:upper:]')
  if [[ "$tz_upper" =~ ^UTC([+-])([0-9]{1,2})(:[0-9]{2})?$ ]]; then
    local sign="${BASH_REMATCH[1]}"
    local hours=$((10#${BASH_REMATCH[2]}))
    # Range-validate offset hours (UTC-12 to UTC+14)
    if { [ "$sign" = "-" ] && [ "$hours" -le 12 ]; } || { [ "$sign" = "+" ] && [ "$hours" -le 14 ]; }; then
      _tz_type="offset"
      _tz_sign="$sign"
      _tz_hours="$hours"
      _tz_frac="${BASH_REMATCH[3]}"
      return
    fi
  fi

  _tz_type="iana"
}

# Resolve configured timezone to a UTC offset display string (e.g. "UTC-7", "UTC+5:30")
# Uses the config timezone value to determine what to display.
# Output: display string like "UTC-7" or "UTC+5:30", or empty if resolution fails
ticktock_resolve_tz_offset() {
  local _tz_type _tz_config _tz_sign _tz_hours _tz_frac
  _ticktock_classify_tz

  case "$_tz_type" in
    auto)
      _ticktock_offset_to_display "$(date +%z)"
      ;;
    offset)
      # Classifier already stores hours without leading zeros
      echo "UTC${_tz_sign}${_tz_hours}${_tz_frac}"
      ;;
    iana)
      local raw_offset
      raw_offset=$(TZ="$_tz_config" date +%z 2>/dev/null) || {
        echo ""
        return
      }
      _ticktock_offset_to_display "$raw_offset"
      ;;
  esac
}

# Return the TZ value to use with date commands.
# For "auto": returns empty string (use system default)
# For IANA names: returns the name directly (e.g. "America/New_York")
# For UTC offsets: applies POSIX sign inversion (user UTC+3 -> POSIX UTC-3)
# Output: TZ-compatible string, or empty for system default
ticktock_tz_value() {
  local _tz_type _tz_config _tz_sign _tz_hours _tz_frac
  _ticktock_classify_tz

  case "$_tz_type" in
    auto)
      echo ""
      ;;
    offset)
      # POSIX TZ sign inversion: user UTC+3 means 3 hours ahead of UTC,
      # but POSIX defines positive as west-of-UTC, so we invert the sign.
      local posix_sign
      if [ "$_tz_sign" = "+" ]; then
        posix_sign="-"
      else
        posix_sign="+"
      fi
      echo "UTC${posix_sign}${_tz_hours}${_tz_frac}"
      ;;
    iana)
      echo "$_tz_config"
      ;;
  esac
}

# Build timezone suffix string for timestamp display.
# Returns " UTC-7" (with leading space) if timezone display is enabled, or empty string.
ticktock_tz_suffix() {
  if ticktock_show_timezone; then
    local tz_display
    tz_display=$(ticktock_resolve_tz_offset)
    if [ -n "$tz_display" ]; then
      echo " ${tz_display}"
      return
    fi
  fi
  echo ""
}

# Get temp file path for storing last timestamp
# Uses TMPDIR (or /tmp) with restricted-permission directory to avoid symlink attacks
ticktock_temp_file() {
  local session_id="${CLAUDE_SESSION_ID:-default}"
  # Sanitize session_id: strip path separators to prevent directory traversal
  session_id="${session_id//\//_}"
  session_id="${session_id//\\/_}"
  local dir="${TMPDIR:-/tmp}/ticktock-$(id -u)"
  mkdir -p -m 700 "$dir" 2>/dev/null || true
  echo "${dir}/${session_id}"
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
    return 0
  fi

  local tz_val
  tz_val=$(ticktock_tz_value)

  local now_epoch
  now_epoch=$(date +%s)
  local now_time
  # When tz_val is empty (auto mode), do not set TZ at all.
  # On macOS, TZ="" resolves to UTC rather than the local timezone.
  if [ -n "$tz_val" ]; then
    now_time=$(TZ="$tz_val" date +"%H:%M:%S")
  else
    now_time=$(date +"%H:%M:%S")
  fi
  local threshold
  threshold=$(ticktock_threshold)
  local last
  last=$(ticktock_last_timestamp)

  local tz_suffix
  tz_suffix=$(ticktock_tz_suffix)

  local output
  if [ -z "$last" ]; then
    output="[${now_time}${tz_suffix}]"
  else
    local elapsed=$((now_epoch - last))
    if [ "$elapsed" -ge "$threshold" ]; then
      local formatted
      formatted=$(ticktock_format_elapsed "$elapsed")
      output="[${now_time}${tz_suffix} | +${formatted}]"
    else
      output="[${now_time}${tz_suffix}]"
    fi
  fi

  ticktock_save_timestamp
  echo "$output"
}
