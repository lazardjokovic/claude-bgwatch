# Changelog

Notable changes to claude-bgwatch, newest first.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the
version stays below 1.0.0, the command line and the columns of the list may change
between minor versions.

## [Unreleased]

## [0.1.0]

### Added

- **One list of what every Claude Code session is running.** Bash tasks
  started with `run_in_background` (`bg`), commands Claude is waiting on
  (`fg`) and monitors (`monitor`, with their description), with the session's
  name, its project, how long each has run and how much it has printed.
- **Following**, like `tail -f`: one task, several with each line labelled,
  or `all`. It stops by itself when the task ends. A monitor's output goes to
  Claude over a socket rather than into a file, so following one shows the
  events Claude was sent, read from the session's transcript.
- **Ended background tasks**, with `--finished`, for as long as Claude Code
  keeps their output.
- **`show`** for a task's whole output, and **`kill`** to stop a task and
  everything it started, after asking.
