# ticktock

Claude Code plugin that provides time awareness by injecting timestamps and elapsed time into context via hooks. Entirely bash-based.

## Dependencies

- bash (4.0+)
- jq

## File Structure

```
.claude-plugin/
  plugin.json          # Plugin metadata and version
  marketplace.json     # Marketplace listing metadata
hooks/
  hooks.json           # Hook definitions (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse)
  handlers/
    common.sh          # Shared library (config, elapsed, timezone, formatting)
    session-start.sh   # Runs on session startup/resume/clear/compact
    user-prompt.sh     # Runs when the user submits a prompt
    pre-tool-use.sh    # Runs before a tool is invoked
    post-tool-use.sh   # Runs after a tool completes
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

Run hook handlers manually by setting the required environment variables:

```bash
CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/session-start.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/pre-tool-use.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/post-tool-use.sh
```

Set `TICKTOCK_CONFIG` to override the config file path (useful for testing with isolated configs):

```bash
TICKTOCK_CONFIG=/tmp/test-config.json CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
```

## Version Bumps

When releasing a new version, update the version field in both:

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
