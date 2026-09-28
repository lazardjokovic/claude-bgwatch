# claude-bgwatch

## What this is

One bash script, `claude-bgwatch`, that lists and follows what every live
Claude Code session on the machine is running: background Bash tasks (`bg`),
commands a session is waiting on (`fg`) and monitors. It reads Claude Code's
temp files, the process table and session transcripts, and changes nothing.

Everything it reads is undocumented. `docs/how-it-works.md` is the list of
each piece and how it was measured; keep it true when a change depends on
something new.

## Decisions already made

- **One file, no build.** Installed by downloading it. Anything that would
  need a second file at run time is a reason to reconsider, not a default.
- **bash 3.2.** macOS ships it and that is where this is used most. No
  associative arrays, `mapfile`, `${var,,}`, `declare -n` or `|&`. CI runs
  the suite on macOS to catch them.
- **Dependencies are `jq`, `lsof`, `ps` and Claude Code's own
  `claude agents --json`.** Nothing that is not on a stock Mac.
- **Read only.** The one thing that acts is `kill`, which asks first and stops
  only the command and what it started, never a session.
- **Unofficial.** The README says it is not affiliated with Anthropic; keep
  that, and keep Anthropic's name out of anything that could look like an
  endorsement.

## Working here

```sh
tests/run.sh                                  # the suite, against a fake Claude Code
shellcheck claude-bgwatch tests/run.sh        # or: docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable claude-bgwatch tests/run.sh
./claude-bgwatch                              # against your real sessions
```

`tests/run.sh` builds a fake of every undocumented piece: a stand-in `claude`
that lists one session, a process in its place with a Bash task and a monitor
below it wrapped the way Claude wraps them, and a transcript. When Claude Code
changes one of those, change the fake to match what was measured, then the
script.

## Working rules

- **Test everything before a merge, and audit for gaps honestly.** Say which
  claims rest on a local run against real sessions and which on the fake.
- **Prove a test can fail.** Break the code on purpose and watch the matching
  test fail before trusting a green run.
- **`main` is protected.** Changes arrive only by a squash-merged PR, with
  `shellcheck`, `tests (ubuntu-latest)` and `tests (macos-latest)` passing on a
  branch that is up to date with `main`. No force pushes, no deleting `main`,
  and `v*` tags cannot be moved or deleted once pushed. If a CI job is
  renamed, the required check in the `main` ruleset has to be renamed with it,
  or every PR waits for a check that never reports.
- **Releases** follow `docs/releasing.md`. A release is not done until the
  CHANGELOG, `VERSION` and the tag all say the same version.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  and nothing else. **PR descriptions** end with
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Keep the owner's real name out of anything public.** Commit as `Lazar`.
- **No real output in the repo.** Task output can hold secrets; examples in
  docs and fixtures in tests are made up.

## Where things stand

**0.1.0 is written and tested (2026-09-28), not released.** Built against
Claude Code 2.1.283 on macOS. Linux is covered only by CI with the fake.
