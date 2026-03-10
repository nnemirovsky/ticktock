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
    session-start.sh   # Runs on session startup/resume/clear/compact
    user-prompt.sh     # Runs when the user submits a prompt
    pre-tool-use.sh    # Runs before a tool is invoked
    post-tool-use.sh   # Runs after a tool completes
docs/
  plans/               # Design and planning documents
```

## Testing

Run hook handlers manually by setting the required environment variables:

```bash
CLAUDE_SESSION_ID=test bash hooks/handlers/user-prompt.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/session-start.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/pre-tool-use.sh
CLAUDE_SESSION_ID=test bash hooks/handlers/post-tool-use.sh
```

## Version Bumps

When releasing a new version, update the version field in both:

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
