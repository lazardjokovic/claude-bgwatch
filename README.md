# claude-bgwatch

See what every Claude Code session on your machine is running in the
background, and follow any of it from a terminal: the Bash commands Claude
started with `run_in_background`, the monitors it is watching, and the
commands it is waiting on right now.

```
$ claude-bgwatch
  #  KIND     TASK        SESSION             PROJECT              AGE     OUT  COMMAND
  1  monitor  bqp5qn20u   fix-login-flow      web-app            23:43       -  "CI pipeline jobs"  while true; do gh run view…
  2  bg       bwuhnzyo8   web-app-06          web-app            00:34     87B  npm run dev
  3  fg       b7kq2m1xa   api-a3              api                02:10    1.2K  bundle exec rspec spec/models

$ claude-bgwatch 2          # follow one, like tail -f
$ claude-bgwatch 1 3        # follow several, each line labelled
$ claude-bgwatch all        # follow everything that is running
```

## Why

Claude Code is good at starting things and leaving them running: a dev
server, a build, a test suite, a monitor waiting on CI. Inside a session,
`/tasks` shows that session's own. With three or four sessions open there is
no one place that answers **"what is running right now, and what is it
printing?"**, and each task's output is a file in a temp folder named after a
session id.

This is that place. It reads what Claude Code already leaves on disk and in
the process table, and asks nothing of the sessions themselves: no hooks, no
settings, nothing to install into Claude.

## What you need

- **macOS or Linux.** It is one bash script, and it runs on the bash 3.2
  macOS ships.
- **Claude Code** on your `PATH`, recent enough to have `claude agents --json`.
- **`jq`** and **`lsof`**. macOS has both. On Linux, `apt install jq lsof` or
  the equivalent.

## Install

```sh
mkdir -p ~/.local/bin
curl -fsSL https://github.com/lazardjokovic/claude-bgwatch/releases/latest/download/claude-bgwatch \
  -o ~/.local/bin/claude-bgwatch
chmod +x ~/.local/bin/claude-bgwatch
```

`~/.local/bin` has to be on your `PATH`; Claude Code's own installer puts it
there. Each release also has a `claude-bgwatch.sha256` to check the download
against.

Or from a clone, which is also how to try an unreleased change:

```sh
git clone https://github.com/lazardjokovic/claude-bgwatch
ln -s "$PWD/claude-bgwatch/claude-bgwatch" ~/.local/bin/claude-bgwatch
```

## Using it

| | |
| --- | --- |
| `claude-bgwatch` | list what is running, in every session |
| `claude-bgwatch --finished` | ... and the background tasks that have ended (`-l N` for more than 10) |
| `claude-bgwatch 2` | follow task 2 until it ends or you press Ctrl-C |
| `claude-bgwatch 2 5` | follow several at once, each line prefixed with its task |
| `claude-bgwatch all` | follow everything that is running |
| `claude-bgwatch show 2` | the whole output so far, in `less` |
| `claude-bgwatch kill 2` | stop it, after asking (`-y` to skip the question) |

A task can be named by its number in the list or by its task id, whole or
the start of one: `claude-bgwatch bwuh`. **Numbers are recounted every run;
task ids never change**, so use an id in anything you script.

Following starts with the last 20 lines (`-n 50` for more) and **stops by
itself when the task ends**, with a `── ended ──` line.

### The three kinds

| Kind | What it is | What following it shows |
| --- | --- | --- |
| `bg` | a Bash command Claude started with `run_in_background` | its output, as it is written |
| `fg` | a Bash command Claude is sitting and waiting on | its output, as it is written |
| `monitor` | a Monitor, with its description in quotes | each event Claude was sent |

A monitor is the odd one. Its output goes to Claude over a socket, not into a
file, so there is nothing to tail. What is followed instead is the session's
transcript, where Claude Code writes every event it receives. You see what
Claude saw, which is the filtered stream, not whatever the command printed
that did not make it through its `grep`.

### Stopping a task

`kill` stops the command and everything it started. Claude is told the way
it would be for any command that exits early, as a failed task with an exit
code of 143 or 144, and carries on from there. The session is not touched.

## Known limitations

- **It depends on Claude Code internals.** Where the output files live, how
  Claude wraps a command, and what a transcript records are not a public
  interface, and an update can move any of them. When that happens the list
  comes up empty or wrong rather than doing any harm, and
  [docs/how-it-works.md](docs/how-it-works.md) says which piece to look at.
- **Only this machine and this user.** Sessions on the web, in the cloud, or
  under another account are not visible to it.
- **Background subagents are not listed.** Their work is a transcript, not a
  command, and it is on the [roadmap](ROADMAP.md).
- **A monitor's events come from the transcript**, so one whose tool call is
  not in it yet, in the first moment after it starts, shows with a task id of
  `-` and no events until the next run.
- **Ended tasks last as long as their files.** Claude Code keeps them in a
  temp folder that is cleared on reboot, and a monitor's age is its file's,
  not its last event's.

The [roadmap](ROADMAP.md) says which of these are being worked on and which
are settled. [Issues](../../issues) is the place to ask for something, and
[CHANGELOG.md](CHANGELOG.md) records what changed between releases.

## License

MIT. See [LICENSE](LICENSE).

## Not affiliated with Anthropic

claude-bgwatch is an independent hobby project. It is **not affiliated with,
endorsed by, or connected to Anthropic**. "Claude" and "Claude Code" are
Anthropic's trademarks and are used here only to describe what the tool reads.

It reads files Claude Code writes under your own user and changes none of
them. Output files can contain whatever a command printed, secrets included,
and nothing here sends them anywhere.
