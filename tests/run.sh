#!/usr/bin/env bash
#
# Runs claude-bgwatch against a fake Claude Code: a stand-in `claude` that
# lists one session, a process in that session's place with a Bash task and a
# monitor below it, shaped the way Claude starts them, and a transcript that
# records both. Nothing here touches a real session.
#
#   tests/run.sh

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
TOOL="$HERE/../claude-bgwatch"
T=$(mktemp -d "${TMPDIR:-/tmp}/bgwatch-test.XXXXXX")
T=$(cd -P "$T" && pwd)
SID=11111111-2222-3333-4444-555555555555
TASKS="$T/tmp/-fake-project/$SID/tasks"
TRANSCRIPT="$T/config/projects/-fake-project/$SID.jsonl"
SESSION_PID=''
FOLLOW_PID=''
PASS=0
FAIL=0

cleanup() {
  [ -n "$FOLLOW_PID" ] && kill "$FOLLOW_PID" 2>/dev/null
  if [ -n "$SESSION_PID" ]; then
    pkill -P "$SESSION_PID" 2>/dev/null
    kill "$SESSION_PID" 2>/dev/null
    wait "$SESSION_PID" 2>/dev/null
  fi
  pkill -f "$T/" 2>/dev/null
  rm -rf "$T"
}
trap cleanup EXIT

ok()   { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      | /'; }

# expect <name> <output> <fixed string that must be in it>
expect() { case $2 in *"$3"*) ok "$1" ;; *) fail "$1" "$2" ;; esac; }
reject() { case $2 in *"$3"*) fail "$1" "$2" ;; *) ok "$1" ;; esac; }

bgwatch() {
  CLAUDE_BGWATCH_CLAUDE="$T/bin/claude" CLAUDE_CONFIG_DIR="$T/config" \
  CLAUDE_BGWATCH_TMP="$T/tmp" COLUMNS=200 NO_COLOR=1 "$TOOL" "$@" 2>&1
}

mkdir -p "$TASKS" "${TRANSCRIPT%/*}" "$T/bin"

# ------------------------------------------------------------- the session ---

# Wrapped the way Claude wraps a command, including how each quotes a '.
# shellcheck disable=SC2016  # expanded by the task, not here
BG_CMD='while true; do echo "tick $(date +%s)"; sleep 1; done'
MON_CMD="sleep 300 # it's a monitor"
MON_QUOTED=${MON_CMD//\'/\'\"\'\"\'}

BG_WRAPPED="true && eval '${BG_CMD//\'/\'\\\'\'}' < /dev/null && pwd -P"
MON_WRAPPED="true && eval '$MON_QUOTED' < /dev/null && pwd -P"
{
  printf 'bash -c %q > %q 2>&1 &\n' "$BG_WRAPPED" "$TASKS/bgtask01.output"
  printf 'bash -c %q | cat > /dev/null &\n' "$MON_WRAPPED"
  printf 'wait\n'
} > "$T/session.sh"
bash "$T/session.sh" 2>/dev/null &
SESSION_PID=$!

cat > "$T/bin/claude" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "agents --json" ] || exit 2
cat <<JSON
[
  {
    "pid": $SESSION_PID,
    "cwd": "/home/someone/fake-project",
    "kind": "interactive",
    "sessionId": "$SID",
    "name": "fake-session",
    "status": "busy"
  }
]
JSON
EOF
chmod +x "$T/bin/claude"

# A task that has ended: its output is left behind, its process is gone.
printf 'built\nall done\n' > "$TASKS/oldtask01.output"

# The transcript: each task's tool call, the result naming its task id, and
# three monitor events, one of them queued and then delivered, which Claude
# writes down twice.
{
  jq -nc --arg c "$BG_CMD" '{type:"assistant",cwd:"/home/someone/fake-project",message:{content:[{type:"tool_use",id:"tu1",name:"Bash",input:{command:$c,run_in_background:true,description:"tick forever"}}]}}'
  jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"tu1",content:"Command running in background with ID: bgtask01. Output is being written to: x"}]}}'
  jq -nc '{type:"assistant",message:{content:[{type:"tool_use",id:"tu2",name:"Bash",input:{command:"make build",run_in_background:true,description:"build it"}}]}}'
  jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"tu2",content:"Command running in background with ID: oldtask01. Output is being written to: x"}]}}'
  jq -nc --arg c "$MON_CMD" '{type:"assistant",message:{content:[{type:"tool_use",id:"tu3",name:"Monitor",input:{command:$c,description:"watch the fake build"}}]}}'
  jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"tu3",content:"Monitor started (task montask01, expires in 30m)"}]}}'
  ev() { printf '<task-notification>\n<task-id>montask01</task-id>\n<summary>Monitor event: "watch the fake build"</summary>\n<event>%s</event>\n</task-notification>' "$1"; }
  jq -nc --arg c "$(ev 'step 1 &amp; more')" '{type:"user",message:{role:"user",content:$c}}'
  jq -nc --arg c "$(ev 'step 2')" '{type:"queue-operation",operation:"enqueue",content:$c}'
  jq -nc --arg c "$(ev 'step 2')" '{type:"user",message:{role:"user",content:$c}}'
  jq -nc --arg c "$(ev 'step 3')" '{type:"queue-operation",operation:"enqueue",content:$c}'
  jq -nc --arg c "$(ev 'step 3')" '{type:"queue-operation",operation:"remove",content:$c}'
} > "$TRANSCRIPT"

# Give the session a moment to start its commands and write output.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$TASKS/bgtask01.output" ] && break
  sleep 0.5
done

# ----------------------------------------------------------------- checks ---

out=$(bgwatch --version)
expect "--version prints the version in the script" "$out" \
  "$(sed -n "s/^VERSION='\(.*\)'$/\1/p" "$TOOL")"

out=$(bgwatch)
expect "list shows the Bash task as bg" "$out" "bg       bgtask01"
expect "list shows the Bash command" "$out" "$BG_CMD"
expect "list shows the monitor, found by its command" "$out" "monitor  montask01"
expect "a monitor quoted with '\"'\"' is read back whole" "$out" "$MON_CMD"
expect "list shows the monitor's description" "$out" '"watch the fake build"'
expect "list names the session" "$out" "fake-session"
expect "list names the project" "$out" "fake-project"
reject "ended tasks are hidden by default" "$out" "oldtask01"
expect "and counted" "$out" "1 ended task(s) not shown"

out=$(bgwatch --finished)
expect "--finished lists the ended task" "$out" "oldtask01"
expect "with the command from the transcript" "$out" "make build"

out=$(bgwatch show oldtask01)
expect "show prints an ended task's output" "$out" "all done"

out=$(bgwatch show montask)
expect "show takes the start of a task id" "$out" "step 2"
expect "monitor events are unescaped" "$out" "step 1 & more"
n=$(printf '%s\n' "$out" | grep -c '^step 2$')
if [ "$n" -eq 1 ]; then ok "an event queued and then delivered is shown once"
else fail "an event queued and then delivered is shown once" "$out"; fi
expect "a queued event that was removed is still shown" "$out" "step 3"

out=$(bgwatch show nosuchtask)
expect "an unknown task is an error" "$out" "no task 'nosuchtask'"

out=$(bgwatch 99)
expect "an unknown number is an error" "$out" "no task '99'"

# Follow the Bash task, stop it from another invocation, and the follower
# should notice and end by itself.
bgwatch -n 1 bgtask01 > "$T/follow.out" &
FOLLOW_PID=$!
sleep 3
out=$(bgwatch kill -y bgtask01)
expect "kill -y stops the task" "$out" "stopped"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  kill -0 "$FOLLOW_PID" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$FOLLOW_PID" 2>/dev/null; then
  fail "following ends when the task does" "$(cat "$T/follow.out")"
else
  ok "following ends when the task does"
  FOLLOW_PID=''
fi
out=$(cat "$T/follow.out")
expect "following streamed the task's output" "$out" "tick "
expect "and said it ended" "$out" "── ended ──"

out=$(bgwatch)
reject "a stopped task is no longer running" "$out" "bg       bgtask01"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
