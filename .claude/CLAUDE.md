# ticktock

Claude Code plugin that provides time awareness by injecting timestamps and elapsed time into context via hooks. Entirely bash-based.

## Dependencies

- bash (4.0+)
- jq

## File Structure

```
.claude/
  CLAUDE.md            # This file. Under .claude/ so the plugin validator does not flag it at the root
.claude-plugin/
  plugin.json          # Plugin metadata and version
  marketplace.json     # Marketplace listing metadata
hooks/
  hooks.json           # Hook definitions (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse)
  handlers/
    ticktock.sh        # The only handler. Every hook runs it; the skill and tests source it
skills/
  ticktock/
    SKILL.md           # /ticktock slash command (config, hook toggles, timezone)
tests/
  test-timezone.sh     # Automated tests for timezone functions
docs/
  plans/               # Design and planning documents
    completed/         # Completed plans
```

## Testing

Run automated tests:

```bash
bash tests/test-timezone.sh
```

Run the handler manually by passing the hook event as the first argument. As a real
hook it reads `hook_event_name` and `session_id` from stdin instead:

```bash
CLAUDE_SESSION_ID=test bash hooks/handlers/ticktock.sh UserPromptSubmit </dev/null
CLAUDE_SESSION_ID=test bash hooks/handlers/ticktock.sh SessionStart </dev/null
echo '{"hook_event_name":"PreToolUse","session_id":"test"}' | bash hooks/handlers/ticktock.sh
```

Set `TICKTOCK_CONFIG` to override the config file path (useful for testing with isolated configs):

```bash
TICKTOCK_CONFIG=/tmp/test-config.json CLAUDE_SESSION_ID=test bash hooks/handlers/ticktock.sh UserPromptSubmit </dev/null
```

## Plugin directory rules

- Hook commands point straight at `ticktock.sh` by a literal path. A hook script that
  runs or sources another file puts the plugin on a policy hold for manual review.
- No text file may name the listing icon or any other image or font. That also
  triggers a policy hold.

## Version Bumps

When releasing a new version, update the version field in both:

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
