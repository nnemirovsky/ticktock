# Contributing

Thanks for looking at `ticktock`. This covers the dev loop, the tests and how changes land.

## Dev loop

Load the plugin from a working tree instead of through the marketplace:

```
claude --plugin-dir /path/to/ticktock
```

Every Claude Code restart re-reads the plugin from disk, with no `/plugin install` and no marketplace cache to flush. Hooks load at session start, so a change to `hooks/hooks.json` or to a handler needs a restart before it takes effect.

## Tests

```
claude plugin validate .
bash tests/test-timezone.sh
```

`tests/test-timezone.sh` covers timezone parsing and validation, the timestamp suffix, older config files and the handler run end to end for each hook. It points the handler at a temporary config through `TICKTOCK_CONFIG`, so your real `~/.claude/ticktock.json` is never touched.

Lint the scripts before opening a PR:

```
bash -n hooks/handlers/ticktock.sh tests/test-timezone.sh
shellcheck --severity=error hooks/handlers/ticktock.sh tests/test-timezone.sh
```

CI runs the validation, the test script and the lint on every PR.

Run the handler by hand with the event as the first argument:

```
CLAUDE_SESSION_ID=test bash hooks/handlers/ticktock.sh UserPromptSubmit </dev/null
```

The plugin directory puts a plugin on a policy hold for some shell patterns. `.claude/CLAUDE.md` lists them. In short: no here-documents or multi-line literals in the hook script, and the hook runs no other file.

## Pull requests

- Open a PR against `main`. Direct pushes are blocked.
- CI must be green and every review thread resolved before a PR can merge.
- PRs are squash-merged, and the PR title becomes the commit subject, so write it as a commit message.
- Bump `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in the PR that should ship as a release.

## Commits

Scoped conventional commits with a lowercase description:

```
feat(scope): add the thing
fix(scope): stop doing the wrong thing
```
