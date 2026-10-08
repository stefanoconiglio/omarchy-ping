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
