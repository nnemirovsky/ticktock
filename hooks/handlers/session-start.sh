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
