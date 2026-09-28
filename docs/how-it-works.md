# How it works

Nothing claude-bgwatch reads is a documented Claude Code interface. This is
the list of what it relies on, measured on Claude Code 2.1.283 on macOS, so
that when an update moves something the fix starts with the right piece.
`tests/run.sh` builds a fake of each of them, and is the first thing to
update when one changes.

## 1. The sessions: `claude agents --json`

The only documented piece. It prints every live session with its `pid`,
`sessionId`, `name` and `cwd`, and is where the SESSION and PROJECT columns
come from.

## 2. The commands: children of a session's process

Claude runs each command as a direct child of the session's process, wrapped
like this (zsh; bash is the same shape):

```
/bin/zsh -c source ~/.claude/shell-snapshots/snapshot-zsh-....sh 2>/dev/null || true
  && setopt ... && eval '<the command>' < /dev/null && pwd -P >| /tmp/claude-xxxx-cwd
```

A child with `eval '` in its arguments is a command Claude started, and what
is between the quotes is the command as Claude wrote it. Each `'` inside it
is quoted, as `'\''` for a Bash task and as `'"'"'` for a monitor, and both
are undone. Other children, such as MCP servers, have no `eval` and are
skipped.

## 3. Bash task or monitor: where stdout goes

`lsof` on the child's file descriptor 1:

- **A Bash command** writes into
  `/tmp/claude-<uid>/<project>/<session id>/tasks/<task id>.output`, and the
  file name is the task id.
- **A monitor**'s stdout is a unix socket to the session, so there is no file
  to tail. Its stderr goes to a `tasks/<task id>.output` file of its own,
  usually empty.

`/tmp` is `/private/tmp` on macOS, and `lsof` reports the resolved path.

A foreground command writes into the same kind of file. Claude deletes it
when the command finishes; a background task's file stays, which is what
`--finished` lists.

## 4. Which is which: the transcript

Each session's transcript is
`~/.claude/projects/<project>/<session id>.jsonl` (under `$CLAUDE_CONFIG_DIR`
when that is set), one JSON object per line. Two records are joined on the
tool call's id:

- the tool call, an `assistant` message with a `tool_use` of name `Bash`
  (with `run_in_background: true`) or `Monitor`, carrying `command` and
  `description`;
- its result, a `tool_result` saying `Command running in background with ID:
  <task id>` or `Monitor started (task <task id>, ...)`.

A Bash task whose id is in that map is `bg`, and one that is not is `fg`. A
monitor has no id of its own anywhere in the process, so it is matched to its
tool call by the command, with runs of whitespace made single on both sides.

## 5. A monitor's events: the transcript again

Every event Claude receives is a `<task-notification>` naming the task id:

```
<task-notification>
<task-id>b5xbjdjfl</task-id>
<summary>Monitor event: "the description"</summary>
<event>the line the monitor printed</event>
</task-notification>
```

It is written down in one of two ways:

- as a `user` message whose content is that text, when it is delivered
  straight away;
- as a `queue-operation` with `operation: "enqueue"`, when it arrives
  mid-turn. That is sometimes followed by a `remove` and sometimes by a `user`
  message with the same text once it is delivered.

Each enqueue is printed, and a `user` message whose text matches an earlier
enqueue is not, so an event is shown once either way. The text is
HTML-escaped (`&amp;`, `&lt;`, ...) and is unescaped for display.
