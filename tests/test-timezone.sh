#!/usr/bin/env bash
# Automated tests for ticktock timezone functions
# Run: bash tests/test-timezone.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_SH="${REPO_DIR}/hooks/handlers/common.sh"

# Use a temporary config to avoid touching real config
TEST_CONFIG=$(mktemp)
trap 'rm -f "$TEST_CONFIG"' EXIT

passed=0
failed=0
errors=()

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    errors+=("  FAIL: ${test_name}: expected '${expected}', got '${actual}'")
  fi
}

assert_ok() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    errors+=("  FAIL: ${test_name}: expected exit 0, got ${exit_code}")
  fi
}

assert_fail() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -ne 0 ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    errors+=("  FAIL: ${test_name}: expected non-zero exit, got 0")
  fi
}

# Set TICKTOCK_CONFIG before sourcing so common.sh picks it up at init time
export TICKTOCK_CONFIG="$TEST_CONFIG"
export CLAUDE_SESSION_ID="test-tz"

# Source common.sh (sets set -euo pipefail, defines all functions)
source "$COMMON_SH"

write_config() {
  cat > "$TEST_CONFIG" << EOF
{
  "enabled": true,
  "hooks": {
    "SessionStart": true,
    "UserPromptSubmit": true,
    "PreToolUse": true,
    "PostToolUse": true
  },
  "thresholdSeconds": 30,
  "showTimezone": $1,
  "timezone": "$2"
}
EOF
}

echo "=== ticktock timezone tests ==="

# --- _ticktock_offset_to_display ---

echo "--- _ticktock_offset_to_display ---"

result=$(_ticktock_offset_to_display "+0000")
assert_eq "offset +0000 -> UTC" "UTC" "$result"

result=$(_ticktock_offset_to_display "-0700")
assert_eq "offset -0700 -> UTC-7" "UTC-7" "$result"

result=$(_ticktock_offset_to_display "+0530")
assert_eq "offset +0530 -> UTC+5:30" "UTC+5:30" "$result"

result=$(_ticktock_offset_to_display "+0545")
assert_eq "offset +0545 -> UTC+5:45" "UTC+5:45" "$result"

result=$(_ticktock_offset_to_display "+1200")
assert_eq "offset +1200 -> UTC+12" "UTC+12" "$result"

result=$(_ticktock_offset_to_display "-0330")
assert_eq "offset -0330 -> UTC-3:30" "UTC-3:30" "$result"

result=$(_ticktock_offset_to_display "+0300")
assert_eq "offset +0300 -> UTC+3" "UTC+3" "$result"

# --- ticktock_validate_timezone ---

echo "--- ticktock_validate_timezone ---"

# Valid IANA
result=$(ticktock_validate_timezone "America/New_York" 2>/dev/null)
rc=$?
assert_ok "validate America/New_York exits 0" "$rc"
assert_eq "validate America/New_York output" "America/New_York" "$result"

# Case-insensitive IANA
result=$(ticktock_validate_timezone "america/new_york" 2>/dev/null)
rc=$?
assert_ok "validate america/new_york exits 0" "$rc"
assert_eq "validate america/new_york normalizes" "America/New_York" "$result"

# Invalid IANA
rc=0
result=$(ticktock_validate_timezone "Fake/City" 2>&1) || rc=$?
assert_fail "validate Fake/City exits non-zero" "$rc"

# Valid UTC offset
result=$(ticktock_validate_timezone "UTC+5:30" 2>/dev/null)
rc=$?
assert_ok "validate UTC+5:30 exits 0" "$rc"
assert_eq "validate UTC+5:30 output" "UTC+5:30" "$result"

# Invalid UTC offset (out of range)
rc=0
result=$(ticktock_validate_timezone "UTC+25" 2>&1) || rc=$?
assert_fail "validate UTC+25 exits non-zero" "$rc"

# Case-insensitive UTC
result=$(ticktock_validate_timezone "utc+3" 2>/dev/null)
rc=$?
assert_ok "validate utc+3 exits 0" "$rc"
assert_eq "validate utc+3 normalizes" "UTC+3" "$result"

# Leading zeros normalized
result=$(ticktock_validate_timezone "UTC+03" 2>/dev/null)
rc=$?
assert_ok "validate UTC+03 exits 0" "$rc"
assert_eq "validate UTC+03 strips leading zero" "UTC+3" "$result"

# Auto passthrough
result=$(ticktock_validate_timezone "auto" 2>/dev/null)
rc=$?
assert_ok "validate auto exits 0" "$rc"
assert_eq "validate auto output" "auto" "$result"

# Plain UTC (IANA lookup)
result=$(ticktock_validate_timezone "UTC" 2>/dev/null)
rc=$?
assert_ok "validate UTC exits 0" "$rc"
assert_eq "validate UTC output" "UTC" "$result"

# Boundary values
result=$(ticktock_validate_timezone "UTC-12" 2>/dev/null)
rc=$?
assert_ok "validate UTC-12 exits 0" "$rc"
assert_eq "validate UTC-12 output" "UTC-12" "$result"

result=$(ticktock_validate_timezone "UTC+14" 2>/dev/null)
rc=$?
assert_ok "validate UTC+14 exits 0" "$rc"
assert_eq "validate UTC+14 output" "UTC+14" "$result"

result=$(ticktock_validate_timezone "UTC+5:30" 2>/dev/null)
rc=$?
assert_ok "validate UTC+5:30 valid minutes exits 0" "$rc"

result=$(ticktock_validate_timezone "UTC+5:45" 2>/dev/null)
rc=$?
assert_ok "validate UTC+5:45 valid minutes exits 0" "$rc"

# Should fail: UTC+14:30 exceeds valid range in practice and has non-standard minutes at boundary
rc=0
result=$(ticktock_validate_timezone "UTC+15" 2>&1) || rc=$?
assert_fail "validate UTC+15 exits non-zero" "$rc"

rc=0
result=$(ticktock_validate_timezone "UTC-13" 2>&1) || rc=$?
assert_fail "validate UTC-13 exits non-zero" "$rc"

# Combined boundary offsets: non-zero minutes at extreme hours must fail
rc=0
result=$(ticktock_validate_timezone "UTC+14:30" 2>&1) || rc=$?
assert_fail "validate UTC+14:30 boundary overflow exits non-zero" "$rc"

rc=0
result=$(ticktock_validate_timezone "UTC-12:45" 2>&1) || rc=$?
assert_fail "validate UTC-12:45 boundary overflow exits non-zero" "$rc"

# Valid non-boundary offset with minutes should still pass
result=$(ticktock_validate_timezone "UTC+13:45" 2>/dev/null)
rc=$?
assert_ok "validate UTC+13:45 non-boundary with minutes exits 0" "$rc"
assert_eq "validate UTC+13:45 output" "UTC+13:45" "$result"

# Invalid minutes (not 00/15/30/45)
rc=0
result=$(ticktock_validate_timezone "UTC+5:20" 2>&1) || rc=$?
assert_fail "validate UTC+5:20 invalid minutes exits non-zero" "$rc"

rc=0
result=$(ticktock_validate_timezone "UTC-3:01" 2>&1) || rc=$?
assert_fail "validate UTC-3:01 invalid minutes exits non-zero" "$rc"

# --- ticktock_resolve_tz_offset ---

echo "--- ticktock_resolve_tz_offset ---"

write_config "true" "auto"
result=$(ticktock_resolve_tz_offset)
system_offset=$(date +%z)
expected=$(_ticktock_offset_to_display "$system_offset")
assert_eq "resolve auto matches system" "$expected" "$result"

write_config "true" "America/New_York"
result=$(ticktock_resolve_tz_offset)
ny_offset=$(TZ="America/New_York" date +%z)
expected=$(_ticktock_offset_to_display "$ny_offset")
assert_eq "resolve IANA America/New_York" "$expected" "$result"

write_config "true" "UTC+5:30"
result=$(ticktock_resolve_tz_offset)
assert_eq "resolve UTC+5:30" "UTC+5:30" "$result"

# --- ticktock_tz_value ---

echo "--- ticktock_tz_value ---"

write_config "true" "auto"
result=$(ticktock_tz_value)
assert_eq "tz_value auto -> empty" "" "$result"

write_config "true" "America/New_York"
result=$(ticktock_tz_value)
assert_eq "tz_value IANA -> name" "America/New_York" "$result"

write_config "true" "UTC+3"
result=$(ticktock_tz_value)
assert_eq "tz_value UTC+3 -> POSIX inverted UTC-3" "UTC-3" "$result"

write_config "true" "UTC-5:30"
result=$(ticktock_tz_value)
assert_eq "tz_value UTC-5:30 -> POSIX inverted UTC+5:30" "UTC+5:30" "$result"

# --- ticktock_tz_suffix ---

echo "--- ticktock_tz_suffix ---"

write_config "true" "auto"
result=$(ticktock_tz_suffix)
system_offset=$(date +%z)
expected=" $(_ticktock_offset_to_display "$system_offset")"
assert_eq "tz_suffix enabled auto" "$expected" "$result"

write_config "false" "auto"
result=$(ticktock_tz_suffix)
assert_eq "tz_suffix disabled -> empty" "" "$result"

write_config "true" "UTC+3"
result=$(ticktock_tz_suffix)
assert_eq "tz_suffix UTC+3" " UTC+3" "$result"

write_config "true" "America/New_York"
result=$(ticktock_tz_suffix)
ny_offset=$(TZ="America/New_York" date +%z)
expected=" $(_ticktock_offset_to_display "$ny_offset")"
assert_eq "tz_suffix IANA America/New_York" "$expected" "$result"

# --- ticktock_show_timezone ---

echo "--- ticktock_show_timezone ---"

write_config "true" "auto"
ticktock_show_timezone
assert_ok "show_timezone true" "$?"

write_config "false" "auto"
ticktock_show_timezone && rc=0 || rc=$?
assert_fail "show_timezone false" "$rc"

# --- backward compatibility (missing fields) ---

echo "--- backward compatibility ---"

cat > "$TEST_CONFIG" << 'EOF'
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
EOF

result=$(ticktock_timezone)
assert_eq "missing timezone defaults to auto" "auto" "$result"

ticktock_show_timezone
assert_ok "missing showTimezone defaults to true" "$?"

# --- handler integration ---

echo "--- handler integration ---"

write_config "true" "auto"

output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rc=$?
assert_ok "user-prompt.sh exits 0" "$rc"
# Output should match: [HH:MM:SS UTC+/-N] or [HH:MM:SS UTC+/-N:MM] or [HH:MM:SS UTC] optionally with elapsed suffix
if [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\ UTC([+-][0-9]+(:[0-9]{2})?)?(\ \|\ \+[0-9]+[hms0-9]*)?\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt output format (expected [HH:MM:SS UTC...]), got: '${output}'")
fi

output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/session-start.sh" 2>&1)
rc=$?
assert_ok "session-start.sh exits 0" "$rc"
# Validate JSON
echo "$output" | jq . > /dev/null 2>&1
assert_ok "session-start.sh valid JSON" "$?"
# Verify additionalContext contains timezone suffix
additional=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // ""')
if [[ "$additional" =~ UTC ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: session-start additionalContext missing timezone, got: '${additional}'")
fi

# Integration test with explicit IANA timezone
echo "--- IANA integration ---"

write_config "true" "America/New_York"
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rc=$?
assert_ok "user-prompt.sh with IANA tz exits 0" "$rc"
# Resolve expected offset for America/New_York
ny_display=$(_ticktock_offset_to_display "$(TZ="America/New_York" date +%z)")
if [[ "$output" == *"$ny_display"* ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt IANA output missing ${ny_display}, got: '${output}'")
fi

# Portable HH:MM:SS to seconds-since-midnight (pure bash, no BSD/GNU date dependency)
_hms_to_sec() {
  local h m s
  IFS=: read -r h m s <<< "$1"
  echo $(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
}

# Wall clock assertion: verify rendered time matches configured timezone
echo "--- wall clock assertion ---"

write_config "true" "America/New_York"
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
# Extract HH:MM:SS from output
rendered_time=$(echo "$output" | sed 's/^\[\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
expected_time=$(TZ="America/New_York" date +%H:%M:%S)
# Compare within a 2-second window using portable arithmetic
rendered_sec=$(_hms_to_sec "$rendered_time")
expected_sec=$(_hms_to_sec "$expected_time")
diff_sec=$(( rendered_sec - expected_sec ))
if [ "$diff_sec" -lt 0 ]; then diff_sec=$(( -diff_sec )); fi
# Handle midnight wraparound (e.g. 23:59:59 vs 00:00:01 = 2 sec apart, not 86398)
if [ "$diff_sec" -gt 43200 ]; then diff_sec=$(( 86400 - diff_sec )); fi
if [ "$diff_sec" -le 2 ]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: wall clock mismatch for America/New_York: rendered=${rendered_time}, expected=${expected_time}")
fi

# Wall clock assertion for auto mode: verify it uses local time, not UTC
write_config "true" "auto"
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rendered_time=$(echo "$output" | sed 's/^\[\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
expected_time=$(date +%H:%M:%S)
rendered_sec=$(_hms_to_sec "$rendered_time")
expected_sec=$(_hms_to_sec "$expected_time")
diff_sec=$(( rendered_sec - expected_sec ))
if [ "$diff_sec" -lt 0 ]; then diff_sec=$(( -diff_sec )); fi
if [ "$diff_sec" -gt 43200 ]; then diff_sec=$(( 86400 - diff_sec )); fi
if [ "$diff_sec" -le 2 ]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: auto mode wall clock mismatch: rendered=${rendered_time}, expected local=${expected_time}")
fi

# Integration test with showTimezone: false
echo "--- showTimezone false integration ---"

write_config "false" "auto"
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rc=$?
assert_ok "user-prompt.sh with showTimezone false exits 0" "$rc"
# Output should be a timestamp without any UTC reference
if [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}(\ \|\ \+[0-9]+[hms0-9]*)?\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt showTimezone false has unexpected format, got: '${output}'")
fi
if [[ "$output" != *"UTC"* ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt showTimezone false should not contain UTC, got: '${output}'")
fi

# --- _ticktock_classify_tz ---

echo "--- _ticktock_classify_tz ---"

write_config "true" "auto"
_tz_type="" _tz_config="" _tz_sign="" _tz_hours="" _tz_frac=""
_ticktock_classify_tz
assert_eq "classify auto" "auto" "$_tz_type"

write_config "true" "UTC+5:30"
_ticktock_classify_tz
assert_eq "classify UTC+5:30 type" "offset" "$_tz_type"
assert_eq "classify UTC+5:30 sign" "+" "$_tz_sign"
assert_eq "classify UTC+5:30 hours" "5" "$_tz_hours"
assert_eq "classify UTC+5:30 frac" ":30" "$_tz_frac"

write_config "true" "America/New_York"
_ticktock_classify_tz
assert_eq "classify IANA" "iana" "$_tz_type"

# --- ticktock_normalize_iana ---

echo "--- ticktock_normalize_iana ---"

result=$(ticktock_normalize_iana "America/New_York" 2>/dev/null)
rc=$?
assert_ok "normalize_iana America/New_York exits 0" "$rc"
assert_eq "normalize_iana America/New_York" "America/New_York" "$result"

result=$(ticktock_normalize_iana "america/new_york" 2>/dev/null)
rc=$?
assert_ok "normalize_iana case-insensitive exits 0" "$rc"
assert_eq "normalize_iana case-insensitive" "America/New_York" "$result"

rc=0
result=$(ticktock_normalize_iana "Fake/Nowhere" 2>&1) || rc=$?
assert_fail "normalize_iana invalid exits non-zero" "$rc"

# 3-level IANA name
result=$(ticktock_normalize_iana "America/Indiana/Indianapolis" 2>/dev/null)
rc=$?
assert_ok "normalize_iana 3-level exits 0" "$rc"
assert_eq "normalize_iana 3-level" "America/Indiana/Indianapolis" "$result"

# --- ticktock_tz_value with plain UTC ---

echo "--- ticktock_tz_value edge cases ---"

write_config "true" "UTC"
result=$(ticktock_tz_value)
assert_eq "tz_value plain UTC -> IANA path" "UTC" "$result"

# --- ticktock_resolve_tz_offset with leading zeros ---

echo "--- ticktock_resolve_tz_offset leading zeros ---"

write_config "true" "UTC+03"
result=$(ticktock_resolve_tz_offset)
assert_eq "resolve UTC+03 strips leading zero" "UTC+3" "$result"

write_config "true" "UTC-09:30"
result=$(ticktock_resolve_tz_offset)
assert_eq "resolve UTC-09:30 strips leading zero" "UTC-9:30" "$result"

# --- ticktock_resolve_tz_offset with invalid IANA ---

echo "--- ticktock_resolve_tz_offset error paths ---"

write_config "true" "Fake/Nowhere"
result=$(ticktock_resolve_tz_offset 2>/dev/null)
# Invalid IANA falls back to UTC on most systems (date doesn't error, just uses UTC)
assert_eq "resolve_tz_offset with invalid IANA falls back to UTC" "UTC" "$result"

# --- ticktock_show_timezone with non-boolean config ---

echo "--- ticktock_show_timezone edge cases ---"

cat > "$TEST_CONFIG" << 'EOF'
{
  "enabled": true,
  "hooks": { "SessionStart": true, "UserPromptSubmit": true, "PreToolUse": true, "PostToolUse": true },
  "thresholdSeconds": 30,
  "showTimezone": "yes",
  "timezone": "auto"
}
EOF
ticktock_show_timezone && rc=0 || rc=$?
assert_fail "show_timezone non-boolean 'yes' -> false" "$rc"

# --- pre-tool-use and post-tool-use integration ---

echo "--- pre/post tool-use integration ---"

write_config "true" "auto"

output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/pre-tool-use.sh" 2>&1)
rc=$?
assert_ok "pre-tool-use.sh exits 0" "$rc"
if [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\ UTC([+-][0-9]+(:[0-9]{2})?)?(\ \|\ \+[0-9]+[hms0-9]*)?\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: pre-tool-use output format (expected [HH:MM:SS UTC...]), got: '${output}'")
fi

output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/post-tool-use.sh" 2>&1)
rc=$?
assert_ok "post-tool-use.sh exits 0" "$rc"
if [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\ UTC([+-][0-9]+(:[0-9]{2})?)?(\ \|\ \+[0-9]+[hms0-9]*)?\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: post-tool-use output format (expected [HH:MM:SS UTC...]), got: '${output}'")
fi

# --- negative/error-path tests ---

echo "--- error path tests ---"

# Empty CLAUDE_SESSION_ID should still work (falls back to "default")
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID="" bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rc=$?
assert_ok "user-prompt with empty session ID exits 0" "$rc"
# Output should still be a bracketed timestamp
if [[ "$output" =~ ^\[.+\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt with empty session ID output not formatted, got: '${output}'")
fi

# Corrupted config (invalid JSON) should not crash handler
cat > "$TEST_CONFIG" << 'EOF'
{ this is not valid json
EOF
output=$(TICKTOCK_CONFIG="$TEST_CONFIG" CLAUDE_SESSION_ID=test-tz bash "${REPO_DIR}/hooks/handlers/user-prompt.sh" 2>&1)
rc=$?
# Handler should still exit 0 (graceful degradation via jq defaults)
assert_ok "user-prompt with corrupted config exits 0" "$rc"
# Output should still be a properly formatted timestamp with HH:MM:SS
if [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}(\ UTC([+-][0-9]+(:[0-9]{2})?)?)?(\ \|\ \+[0-9]+[hms0-9]*)?\]$ ]]; then
  passed=$((passed + 1))
else
  failed=$((failed + 1))
  errors+=("  FAIL: user-prompt with corrupted config output not HH:MM:SS format, got: '${output}'")
fi

# Restore valid config for any subsequent tests
write_config "true" "auto"

# === Summary ===

echo ""
echo "=== Results: ${passed} passed, ${failed} failed ==="
if [ "$failed" -gt 0 ]; then
  printf '%s\n' "${errors[@]}"
  exit 1
fi
echo "All tests passed."
exit 0
