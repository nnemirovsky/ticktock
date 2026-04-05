#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if ! ticktock_is_enabled "SessionStart"; then
  exit 0
fi

ticktock_save_timestamp

# Resolve timezone for date commands
tz_val=$(ticktock_tz_value)

if [ -n "$tz_val" ]; then
  NOW=$(TZ="$tz_val" date +"%Y-%m-%d %H:%M:%S")
else
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
fi

# Build timezone suffix if enabled
tz_suffix=""
if ticktock_show_timezone; then
  tz_display=$(ticktock_resolve_tz_offset)
  if [ -n "$tz_display" ]; then
    tz_suffix=" ${tz_display}"
  fi
fi

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "[Session started: ${NOW}${tz_suffix}]"
  }
}
EOF

exit 0
