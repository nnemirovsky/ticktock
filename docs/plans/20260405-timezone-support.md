# Add Timezone Support

## Overview
- Add configurable timezone display to all ticktock timestamp output
- By default, auto-detect system timezone and display as UTC offset (e.g. `UTC-7`)
- Allow manual override with IANA names (`America/New_York`) or UTC offsets (`UTC+3`)
- Manual timezone values are case-insensitive
- Timezone display is toggleable independently via `showTimezone` config flag
- Manage via `/ticktock tz` subcommands

## Context (from discovery)
- Files/components involved:
  - `hooks/handlers/common.sh` - core library with `ticktock_emit()` and all helpers
  - `hooks/handlers/session-start.sh` - session start handler with separate date formatting
  - `skills/ticktock/SKILL.md` - `/ticktock` slash command skill definition
- Config stored at `~/.claude/ticktock.json`, managed via jq atomic updates
- All timestamps use bash `date` command (no gdate), formats: `%H:%M:%S` and `%Y-%m-%d %H:%M:%S`
- No existing timezone handling. System TZ is used implicitly.

## Development Approach
- **Testing approach**: Regular (code first, then manual verification via handler scripts)
- Complete each task fully before moving to the next
- Make small, focused changes
- **CRITICAL: every task MUST include testing** by running handler scripts manually:
  ```bash
  CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
  CLAUDE_SESSION_ID=test bash hooks/handlers/session-start.sh
  ```
- **CRITICAL: all tests must pass before starting next task**
- Run tests after each change
- Maintain backward compatibility (existing configs without timezone fields must work unchanged)

## Testing Strategy
- **Manual handler tests**: Run each handler with `CLAUDE_SESSION_ID=test` and verify output format
- **Config edge cases**: Test with missing timezone fields, invalid values, empty config
- **TZ validation**: Test IANA names, UTC offsets, case variations, invalid values
- No automated test framework (bash-only plugin)

## Progress Tracking
- Mark completed items with `[x]` immediately when done
- Add newly discovered tasks with + prefix
- Document issues/blockers with warning prefix
- Update plan if implementation deviates from original scope

## Solution Overview

### Config Changes
Add two new fields to `~/.claude/ticktock.json`:
```json
{
  "enabled": true,
  "hooks": { ... },
  "thresholdSeconds": 30,
  "showTimezone": true,
  "timezone": "auto"
}
```

- `showTimezone` (boolean, default `true`): Whether to append timezone to timestamps
- `timezone` (string, default `"auto"`): The timezone to use
  - `"auto"` - detect from system, display as UTC offset
  - IANA name (e.g. `"America/New_York"`) - use this timezone, display as UTC offset
  - UTC offset (e.g. `"UTC+3"`, `"UTC-5:30"`) - use this fixed offset

### Output Format Changes
- Current: `[14:32:15]` or `[14:32:15 | +3m25s]`
- New (with timezone): `[14:32:15 UTC-7]` or `[14:32:15 UTC-7 | +3m25s]`
- New (timezone hidden): `[14:32:15]` or `[14:32:15 | +3m25s]` (unchanged)
- Session start: `[Session started: 2026-04-05 14:30:00 UTC-7]`

### Timezone Resolution Flow
1. Read `timezone` from config (default: `"auto"`)
2. If `"auto"`: run `date +%z` to get system offset, format as `UTC-7` or `UTC+5:30`
3. If IANA name: set `TZ=<name>` then run `date +%z` to get offset
4. If UTC offset: parse directly, use `TZ=<offset>` for date commands
5. Case-insensitive matching for IANA names: look up correct casing from `/usr/share/zoneinfo/`

### /ticktock tz Commands
- `/ticktock tz` - show current timezone setting and resolved value
- `/ticktock tz <value>` - set timezone (IANA name or UTC offset, case-insensitive)
- `/ticktock tz auto` - revert to system timezone auto-detection
- `/ticktock tz on` - enable timezone display (`showTimezone: true`)
- `/ticktock tz off` - hide timezone display (`showTimezone: false`)

## Technical Details

### Case-Insensitive IANA Lookup
IANA timezone names are case-sensitive at the OS level. To support case-insensitive input:
1. User provides e.g. `america/new_york`
2. Search `/usr/share/zoneinfo/` for a case-insensitive match using `find -ipath "*/<input>"` (use full path to be specific)
3. If multiple matches, prefer the shortest path (avoids legacy aliases)
4. Store the correctly-cased version in config
5. If no match found, reject with error
6. Note: `/usr/share/zoneinfo/` is the assumed path (works on macOS and Linux)

### UTC Offset Parsing
Accept formats: `UTC+3`, `UTC-7`, `UTC+5:30`, `UTC-05:30`, `utc+3` (case-insensitive)
- Validate the offset is within reasonable range (-12 to +14)
- Store normalized form (e.g. `UTC+3` not `utc+3`)
- For `date` command: convert to POSIX TZ format (note: POSIX TZ offsets are inverted, `UTC+3` = `TZ=UTC-3`)

### Backward Compatibility
- Missing `showTimezone` field defaults to `true`
- Missing `timezone` field defaults to `"auto"`
- Existing configs continue to work without changes
- Default config template updated to include new fields

## Implementation Steps

### Task 1: Add timezone resolution to common.sh

**Files:**
- Modify: `hooks/handlers/common.sh`

- [x] Add `ticktock_show_timezone()` function to read `showTimezone` from config (default: `true`)
- [x] Add `ticktock_timezone()` function to read `timezone` from config (default: `"auto"`)
- [x] Add `ticktock_resolve_tz_offset()` function that resolves configured timezone to a `UTC[+-]N` display string
  - `"auto"` -> run `date +%z`, convert `+HHMM`/`-HHMM` to `UTC-7` or `UTC+5:30`
  - IANA name -> `TZ=<name> date +%z`, convert similarly
  - UTC offset -> parse and return as-is (already in display format)
- [x] Add `ticktock_tz_value()` helper that returns the timezone identifier for use as `TZ="$(ticktock_tz_value)" date ...` (empty string for auto/system)
  - For IANA names: return the name directly (e.g. `America/New_York`)
  - For UTC offsets: apply POSIX TZ sign inversion (user's `UTC+3` -> POSIX `UTC-3`) since POSIX defines west-of-UTC as positive
- [x] Implement and verify POSIX TZ sign inversion in `ticktock_tz_value()`: test that `UTC+3` input produces times 3 hours ahead of UTC (not behind)
- [x] Test auto mode: run handler with `timezone: "auto"`, verify output matches system `date +%z` formatted as UTC offset
- [x] Test IANA mode: set `timezone: "America/New_York"` in config, run handler, verify offset matches expected value for that zone
- [x] Test UTC offset mode: set `timezone: "UTC+5:30"` in config, verify output shows `UTC+5:30` and time is shifted correctly
- [x] Test defaults: verify missing `showTimezone`/`timezone` fields default to `true`/`"auto"` with a clean config

### Task 2: Integrate timezone into timestamp output

**Files:**
- Modify: `hooks/handlers/common.sh`
- Modify: `hooks/handlers/session-start.sh`

- [x] Update `ticktock_emit()` to append timezone offset after the time when `showTimezone` is true
  - Format: `[14:32:15 UTC-7]` or `[14:32:15 UTC-7 | +3m25s]`
- [x] Update `ticktock_emit()` to use `TZ="$(ticktock_tz_value)"` so date commands respect configured timezone
- [x] Update `session-start.sh` to append timezone to the session start message
  - Format: `[Session started: 2026-04-05 14:30:00 UTC-7]`
- [x] Update `session-start.sh` to use `TZ="$(ticktock_tz_value)"` for date commands
- [x] Verify `session-start.sh` JSON output structure remains valid (pipe output through `jq .` to validate)
- [x] Test: run all four handlers and verify timezone appears in output
- [x] Test: set `showTimezone: false` and verify timezone is hidden
- [x] Test: set a manual IANA timezone and verify output uses that timezone's offset
- [x] Run tests: all handlers must pass before next task

### Task 3: Add case-insensitive IANA timezone validation

**Files:**
- Modify: `hooks/handlers/common.sh`

- [x] Add `ticktock_validate_timezone()` function that validates and normalizes a timezone value
  - For IANA names: case-insensitive lookup in `/usr/share/zoneinfo/` using iterative `ls | grep -ix` per path component
  - For UTC offsets: validate format and range (-12 to +14)
  - Returns 0 with normalized value on stdout, or returns 1 with error message on stderr
  - Handle multiple zoneinfo matches by preferring shortest path (grep -ix + head -1)
- [x] Add `ticktock_normalize_iana()` helper to find correct casing from zoneinfo
- [x] Test valid IANA: `America/New_York` -> returns 0, outputs `America/New_York`
- [x] Test case-insensitive IANA: `america/new_york` -> returns 0, outputs `America/New_York`
- [x] Test invalid IANA: `Fake/City` -> returns 1, error on stderr
- [x] Test valid UTC offset: `UTC+5:30` -> returns 0, outputs `UTC+5:30`
- [x] Test invalid UTC offset: `UTC+25` -> returns 1, error on stderr
- [x] Test case-insensitive UTC: `utc+3` -> returns 0, outputs `UTC+3`
- [x] Run tests: all validation cases must pass before next task

### Task 4: Update default config template

**Files:**
- Modify: `hooks/handlers/common.sh`

- [ ] Update `ticktock_ensure_config()` default config to include `showTimezone` and `timezone` fields
- [ ] Verify existing configs without these fields still work (backward compat via `// true` and `// "auto"` jq defaults)
- [ ] Test: delete config, run a handler, verify new config has timezone fields

### Task 5: Update /ticktock skill with tz subcommands

**Files:**
- Modify: `skills/ticktock/SKILL.md`

- [ ] Add `tz` subcommand documentation and handling instructions
- [ ] Add `/ticktock tz` (no args) to show current timezone setting and resolved offset
- [ ] Add `/ticktock tz <value>` to set timezone with validation (call validation function via bash)
- [ ] Add `/ticktock tz auto` to reset timezone to auto-detect
- [ ] Add `/ticktock tz on|off` to toggle `showTimezone`
- [ ] Update the skill's argument-hint frontmatter to include tz options
- [ ] Update the commands list shown when running `/ticktock` with no args
- [ ] Test: verify embedded bash commands in SKILL.md work when run manually (jq config updates)
- [ ] Note: full `/ticktock tz` integration test requires a live Claude Code session (see Post-Completion)

### Task 6: Verify acceptance criteria

**Files:**
- (no file changes, verification only)

- [ ] Verify default behavior: no config changes needed, timezone auto-detected and shown as UTC offset
- [ ] Verify manual IANA timezone with case-insensitive input
- [ ] Verify manual UTC offset
- [ ] Verify `tz off` hides timezone, `tz on` shows it
- [ ] Verify `tz auto` reverts to system timezone
- [ ] Verify backward compatibility: old config without timezone fields works
- [ ] Verify session-start output includes timezone
- [ ] Run all four handlers end-to-end: `CLAUDE_SESSION_ID=test bash hooks/handlers/{session-start,user-prompt,pre-tool-use,post-tool-use}.sh`

### Task 7: [Final] Update documentation

**Files:**
- Modify: `CLAUDE.md` (if needed)
- Move: `docs/plans/20260405-timezone-support.md` -> `docs/plans/completed/`

- [ ] Update CLAUDE.md if new patterns discovered
- [ ] Move this plan to `docs/plans/completed/`

## Post-Completion

**Manual verification:**
- Install plugin in a fresh Claude Code session and verify timestamps show timezone
- Test on macOS (primary target) to confirm `/usr/share/zoneinfo/` path works
- Verify elapsed time calculations are not affected by timezone changes
- Test with edge case timezones (half-hour offsets like India UTC+5:30, Nepal UTC+5:45)
