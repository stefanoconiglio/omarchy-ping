# Log

One dated entry per working session: what changed, decisions and who made them, open questions.
The machine-side record (shell.json, backups, inventory) and the history before this repository
(the PingScope fork it replaces) are in omarchy-customizations' LOG.md.

## 2026-10-08 20:40 CEST — First version

Decision (user): the widget is no longer PingScope (sierrab1989/omarchy-pingscope, which
stefanoconiglio/omarchy-pingscope forks) but a widget of its own, with no PingScope code; name
chosen by the user: omarchy-ping, plugin id `coniglio.ping`, public repository.

- Written new: `manifest.json` (one setting, `host`, default `www.google.it`), `Ping.qml`,
  `Latency.js` with `Latency.test.js`, `README.md`, `LICENSE` (MIT), this log. PingScope's
  per-second `ping -c 1` probes (SitePinger.qml), its host handling (PingModel.js), its panel,
  manifest, README and preview are gone. Kept from the user's own work in the fork: the outline
  face (sizing and ink centring, now re-commented), `Attention.qml`/`Attention.js` (identical to
  omarchy-power's copy), and the session design of the same day (`ping-terminal.sh`, renamed
  `ping-session.sh`; `tmux.conf`).
- The face's ping: one long-running `ping -n -O -i 1 -- <host>` (LC_ALL=C), read line by line
  instead of a new process every second. State: "down" after 10 s without a reply (a late reply
  still counts), "waiting" before the first, else good / slow (≥ 50 ms, orange) / bad (≥ 100 ms,
  red). If ping exits it starts again after 2 s.
- The session: tmux server `coniglio-ping`, session `ping`, terminal class
  `coniglio.ping.terminal`, IPC target `coniglio.ping` (`open`, `close`, `toggle`, `status`).
  Hover view, attach and close-on-blur as in omarchy-customizations' LOG (2026-10-08 20:21).
- Checked:
  - `node Latency.test.js` passes (reply lines including `time<1ms` and IPv6 sources; "no answer
    yet" and unreachable lines ignored; thresholds; labels; host validation).
  - `omarchy plugin validate` passes. The session script: usage on bad arguments, one session
    after two starts, the prompt line `~ ❯ ping www.google.it -i 1` and replies.
  - On the live bar after `omarchy restart shell`: no message from the widget in the journal;
    IPC `status` "www.google.it 74 ms"; exactly two pings running (the session's and the face's).
  - Attach through IPC `open`, the window routed to `special:agents` for about 2 s: floating,
    720×300 at (998, 31), under the pill; one tmux client; IPC `close` closed it, no client left,
    the session still running; none of the user's windows moved.
  - Cost: tmux server 2.2 MB, the session's bash 2.9 MB, its ping 0.5 MB, the face's ping 0.4 MB
    (PSS), no CPU time after 44 s. One attached Ghostty: 0.56 s of CPU, 126 MB peak (systemd
    scope accounting), freed when it closes.
  - Not checked by me: the hover view on screen and the close on blur in real use.
- Preview: the pill cropped from the live bar.

## 2026-10-08 20:46 CEST — The click terminal removed

Report (user): a click starts a Ghostty window that dies at once; remove the feature, it is
useless. Removed without looking for the cause (user's decision).

- Ping.qml: no click (the face's MouseArea takes no button, plain cursor), no attached terminal,
  no Hyprland event handling, no focus timers; IPC keeps `status` only. Hover view unchanged.
- ping-session.sh: `attach` and its window rule gone; `session` only. The session can still be
  reached by hand: `tmux -L coniglio-ping attach -t ping`.
- manifest descriptions, README, tmux.conf comment updated. The last attach's runtime window rule
  (`coniglio_ping_rule`) disabled in Hyprland.
- Checked: `omarchy plugin validate` passes; after `omarchy restart shell` no message from the
  widget in the journal, IPC `status` "www.google.it 35 ms", IPC `open` "Function not found.",
  the session and the two pings running.

## 2026-10-08 20:52 CEST — A click pauses and resumes the ping

Request (user): clicking stops the ping, clicking again resumes it.

- Both pings pause: the face's process is stopped (no restart while paused), the session's ping
  gets Ctrl+C, so no ICMP at all; the face reads `off`, dimmed, and the hover view shows the
  stopped ping with its statistics. A resume restarts the face's ping and types the command again
  at the session's prompt. The pause is the widget's setting `paused` (manifest default and
  schema), written into its shell.json entry, so it outlasts a shell restart.
- ping-session.sh now takes `<host> running|paused`: starts the session (with or without the
  ping typed in), or Ctrl+C / retypes depending on its foreground command (`ping` or `bash`;
  anything else, as in a session attached by hand, is left alone), and returns only once the
  session is in that state (3 s at most). Ping.qml runs one call at a time and applies a click
  made meanwhile after it, so quick clicks cannot leave the session out of step.
- Latency.js: label `off` for "paused" (tests added). IPC: `toggle`, `pause`, `resume`, `status`.
- Checked:
  - On a scratch copy with its own tmux server: paused start at the prompt; five toggles in
    0.24 s ending running, one ping; paused twice, no ping; cold start running; usage errors.
  - `node Latency.test.js`, `omarchy plugin validate` pass. After `omarchy restart shell`: no
    message in the journal. IPC `toggle`: status "www.google.it off", session at `bash`, no face
    ping, shell.json entry `"paused": true`; again: "34 ms", both pings back, `"paused": false`.
    Five quick toggles: paused, no pings; five more: running, one ping each.
  - Not checked: a real mouse click; the pause surviving a shell restart (needs a second restart).
- Seen on the way: the session's ping, stopped by the first pause after 12 min, had 744 packets
  sent, 19.8% lost, round trips 24 ms to 2.2 s (mean 85 ms).
