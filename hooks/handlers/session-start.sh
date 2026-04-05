#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if ! ticktock_is_enabled "SessionStart"; then
  exit 0
fi

ticktock_save_timestamp

# Resolve timezone for date commands
tz_val=$(ticktock_tz_value)

# When tz_val is empty (auto mode), do not set TZ at all.
# On macOS, TZ="" resolves to UTC rather than the local timezone.
if [ -n "$tz_val" ]; then
  NOW=$(TZ="$tz_val" date +"%Y-%m-%d %H:%M:%S")
else
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
fi

tz_suffix=$(ticktock_tz_suffix)

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "[Session started: ${NOW}${tz_suffix}]"
  }
}
EOF

exit 0
