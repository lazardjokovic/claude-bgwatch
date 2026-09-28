# Roadmap

What is planned for claude-bgwatch, what is being considered, and what is
deliberately out of scope. Ordered by intent rather than by date: this is a
hobby project and nothing here carries a delivery promise.

Version numbers are deliberately not attached to anything below. Releases get
numbered for what they turn out to contain, not the other way around.

If what you want is missing, [open an issue](../../issues).

## Next

- **Try it for a while on a real week of sessions.** The first version is
  built from one machine's Claude Code 2.1.283. What a busier machine, a
  Linux one, or the next Claude Code update does to it is what decides the
  rest of this list.

## Delivered

**The first version.** A list of what every live session is running, across
all of them, in three kinds: `bg`, `fg` and `monitor`. Follow one, several or
all of them until they end, with a monitor's events read from its session's
transcript. The whole output of a task, ended ones included, and stopping a
task and what it started.

## Considering

- **Background subagents.** An agent Claude sends off in the background has a
  transcript of its own, linked from the session's `tasks/` folder. Showing
  it means deciding what "its output" is: the agent's messages, its tool
  calls, or only its final answer.

- **`--json`.** The list as JSON, for scripts and for a status line. Wanted
  once somebody has a use for it, since the column set would then be
  something to keep stable.

- **Picking with fzf.** `claude-bgwatch pick` with a preview of each task's
  output, used only when `fzf` is installed.

- **A list that keeps itself up to date**, like `watch`. `watch -n 2
  claude-bgwatch` does most of this already, which is why it is not first.

- **Homebrew.** A tap would make it `brew install`. Worth doing once there
  are releases people are on, not before.

## Not planned

- **Controlling a session.** Starting tasks, answering Claude, or anything
  else that changes what a session does. `kill` is the one exception, and it
  only does what Ctrl-C on that command would.
- **Sessions on other machines or in the cloud.** It reads local files. The
  Claude Code app and `claude agents` already cover sessions elsewhere.
- **Keeping its own history.** It shows what Claude Code keeps, for as long
  as Claude Code keeps it.
