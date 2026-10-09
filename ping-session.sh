#!/bin/bash

# The ping session behind the widget: one shell running `ping <host> -i 1` at
# the user's own prompt, in a tmux session on a server of its own
# (coniglio-ping), so the ping goes on whether anyone looks or not. The widget
# shows its screen on hover, and pauses and resumes the ping on a click;
# `tmux -L coniglio-ping attach -t ping` reaches it from any terminal.
#
#   ping-session.sh <host> running   start the session, or type the ping
#                                    again at its prompt
#   ping-session.sh <host> paused    start the session at its prompt, or
#                                    Ctrl+C its ping
#
# Either returns once the session is in that state (or after 3 s), so calls
# made one after the other never overtake each other. A session doing
# something else (attached by hand) is left alone.
#
# The session's shell reads this same file as its rcfile (bash --rcfile).

if [[ $- == *i* ]]; then
  [[ -f ~/.bashrc ]] && source ~/.bashrc

  # Type the command at the prompt, as if by hand: the shell asks the terminal
  # (tmux) for its status with CSI 5 n, and the answer, CSI 0 n, comes back as
  # input that readline turns into the command and Enter. Echo stays off until
  # the first prompt, so the answer is never shown as ^[[0n. Ctrl+C stops the
  # ping and leaves the shell; Up brings the command back to change it.
  if [[ -n ${CONIGLIO_PING_HOST:-} ]]; then
    bind "\"\\e[0n\": \"ping ${CONIGLIO_PING_HOST} -i 1\\C-m\""
    __coniglio_ping_echo() {
      stty echo
      PROMPT_COMMAND=${PROMPT_COMMAND/__coniglio_ping_echo;/}
      unset -f __coniglio_ping_echo
    }
    PROMPT_COMMAND="__coniglio_ping_echo;${PROMPT_COMMAND}"
    stty -echo
    printf '\e[5n'
  fi
  unset CONIGLIO_PING_HOST
  return
fi

SERVER=coniglio-ping
SESSION=ping
self=$(realpath "$0")
conf="${self%/*}/tmux.conf"
host=${1:-}
state=${2:-}

# Hostnames and addresses only: the host is typed into the shell.
if [[ ! $host =~ ^[A-Za-z0-9][A-Za-z0-9.:-]*$ || ! $state =~ ^(running|paused)$ || $# -ne 2 ]]; then
  echo "usage: ${0##*/} <host> running|paused" >&2
  exit 2
fi

session_tmux() {
  tmux -L "$SERVER" -f "$conf" "$@"
}

# What the session's shell runs in the foreground: `ping`, or `bash` at its
# prompt; nothing when there is no session.
foreground() {
  session_tmux display-message -p -t "=$SESSION:" '#{pane_current_command}' 2>/dev/null
}

await() {
  for _ in {1..60}; do
    [[ $(foreground) == "$1" ]] && return 0
    sleep 0.05
  done
  return 1
}

case $(foreground) in
  "")
    cd ~ || true
    # The ping is typed in by the shell itself when given a host. One bar per
    # monitor may start the session at the same moment: losing that race is fine.
    session_tmux new-session -d -s "$SESSION" -x 94 -y 17 \
      -e "CONIGLIO_PING_HOST=$([[ $state == running ]] && echo "$host")" \
      bash --rcfile "$self" -i 2>/dev/null
    ;;
  bash)
    if [[ $state == running ]]; then
      session_tmux send-keys -t "=$SESSION:" -l "ping $host -i 1"
      session_tmux send-keys -t "=$SESSION:" Enter
    fi
    ;;
  ping)
    [[ $state == paused ]] && session_tmux send-keys -t "=$SESSION:" C-c
    ;;
esac

await "$([[ $state == running ]] && echo ping || echo bash)"
