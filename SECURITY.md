# Security policy

## Reporting a vulnerability

Report privately through GitHub, not in a public issue:

**[Open a private security advisory](https://github.com/nnemirovsky/ticktock/security/advisories/new)**

The report is visible only to the maintainer ([@nnemirovsky](https://github.com/nnemirovsky)) until an advisory is published, so nothing sensitive is exposed while a fix is prepared. Expect an acknowledgement within a week.

If the form is unavailable, open a normal issue that says only "I would like a private channel for a security report", with no details, and a private advisory will be opened for you.

Never attach real credentials, tokens, personal data or private files to a report. Describe the shape of the problem instead.

## Supported versions

Only the latest release gets security fixes.

## Scope

ticktock is one bash hook that runs on every prompt and every tool call, plus the `/ticktock` skill that edits its config. A vulnerability here would be, for example:

- The hook running something from its input or its config as code. The hook input (`hook_event_name`, `session_id`) and `~/.claude/ticktock.json` are data. A value in either that the shell evaluates is a bug.
- Writing outside `~/.claude/ticktock.json` and `$TMPDIR/ticktock-<uid>/`, for example a session id that escapes the state directory.
- Adding anything to Claude's context other than the timestamp line, or making a network request.
- The `/ticktock` skill running a command the user did not ask for.

Out of scope: anything that needs an attacker who can already write to your `~/.claude` or run commands as your user.
