# Privacy policy

ticktock runs entirely on your machine. It has no server, makes no network
requests, and collects no telemetry. Nothing it reads or writes is sent to the
author or to any third party.

## What it reads

* The event name and session id that Claude Code passes to each hook.
* Its own config file, `~/.claude/ticktock.json`.
* The system clock and timezone database, to format the current time.

## What it writes

* `~/.claude/ticktock.json`, a default config created on first run and changed
  only by the `/ticktock` command.
* One small file per session under `$TMPDIR/ticktock-<uid>/`, holding the time of
  the last hook as a Unix timestamp. Nothing else goes in it.

## What it passes to Claude

Each hook adds the current time to the session, optionally with your UTC offset
and the time elapsed since the previous hook, for example
`[14:32:15 UTC-7 | +3m25s]`. Session start adds the full date. That text becomes
part of your session like any other context, and Claude Code handles it under
Anthropic's terms, not this plugin's. Turn the timezone off with `/ticktock tz off`,
or turn the plugin off with `/ticktock off`.

## Contact

Questions go to [GitHub issues](https://github.com/nnemirovsky/ticktock/issues).