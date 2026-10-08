#!/bin/bash

# The ping session behind the widget: one shell running `ping <host> -i 1` at
# the user's own prompt, in a tmux session on a server of its own
# (coniglio-ping), so the ping goes on whether anyone looks or not. The widget
# shows its screen on hover and attaches a terminal to it on a click.
#
#   ping-session.sh session <host>                   start the session unless it runs
#   ping-session.sh attach <host> <x> <y> <w> <h>    a terminal attached to it, floating
#                                                    at x,y (monitor-local), w×h
#
# The session's shell reads this same file as its rcfile (bash --rcfile).

if [[ $- == *i* ]]; then
  [[ -f ~/.bashrc ]] && source ~/.bashrc

  # Type the command at the prompt, as if by hand: the shell asks the terminal
  # (tmux) for its status with CSI 5 n, and the answer, CSI 0 n, comes back as
  # input that readline turns into the command and Enter. Echo stays off until
  # the first prompt, so the answer is never shown as ^[[0n. Ctrl+C stops the
  # ping and leaves the shell; Up brings the command back to change it.
  bind "\"\\e[0n\": \"ping ${CONIGLIO_PING_HOST} -i 1\\C-m\""
  unset CONIGLIO_PING_HOST
  __coniglio_ping_echo() {
    stty echo
    PROMPT_COMMAND=${PROMPT_COMMAND/__coniglio_ping_echo;/}
    unset -f __coniglio_ping_echo
  }
  PROMPT_COMMAND="__coniglio_ping_echo;${PROMPT_COMMAND}"
  stty -echo
  printf '\e[5n'
  return
fi

SERVER=coniglio-ping
SESSION=ping
APP_ID=coniglio.ping.terminal
self=$(realpath "$0")
conf="${self%/*}/tmux.conf"

usage() {
  echo "usage: ${0##*/} session <host> | attach <host> <x> <y> <width> <height>" >&2
  exit 2
}

session_tmux() {
  tmux -L "$SERVER" -f "$conf" "$@"
}

start_session() {
  session_tmux has-session -t "=$SESSION" 2>/dev/null && return 0
  cd ~ || true
  # One bar per monitor may start it at the same moment: losing that race is fine.
  session_tmux new-session -d -s "$SESSION" -x 94 -y 17 -e "CONIGLIO_PING_HOST=$1" \
    bash --rcfile "$self" -i 2>/dev/null ||
    session_tmux has-session -t "=$SESSION" 2>/dev/null
}

# Hostnames and addresses only: the host is typed into the shell by readline.
[[ ${2:-} =~ ^[A-Za-z0-9][A-Za-z0-9.:-]*$ ]] || usage

case $1 in
  session)
    start_session "$2"
    ;;
  attach)
    (( $# == 6 )) || usage
    for n in "$3" "$4" "$5" "$6"; do [[ $n =~ ^[0-9]+$ ]] || usage; done
    start_session "$2" || exit 1
    # The terminal takes the place of the hover view. Each attach replaces the
    # rule of the last one, so rules never pile up.
    printf -v rule 'if coniglio_ping_rule then coniglio_ping_rule:set_enabled(false) end; coniglio_ping_rule = hl.window_rule({ match = { class = "^coniglio\\\\.ping\\\\.terminal$" }, float = true, move = { %d, %d }, size = { %d, %d } })' "$3" "$4" "$5" "$6"
    hyprctl eval "$rule" >/dev/null 2>&1
    exec omarchy-launch-tui --app-id="$APP_ID" tmux -L "$SERVER" -f "$conf" attach-session -t "=$SESSION"
    ;;
  *)
    usage
    ;;
esac
