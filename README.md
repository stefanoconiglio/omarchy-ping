# Ping

An Omarchy shell widget: the round trip to one host, inside a soft outline on
the bar. Hover over it to watch a continuous ping; click it to pause the ping,
and again to resume it.

![The widget on the bar](preview.png)

| Face     | Meaning                                    |
|----------|--------------------------------------------|
| `23 ms`  | the latest round trip, in the bar's colour |
| `73 ms`  | orange from 50 ms                          |
| `142 ms` | red from 100 ms                            |
| `5.6 s`  | a slow reply is shown as it is, in red     |
| `no net` | no reply for 10 s, in red                  |
| `…`      | no reply yet                               |
| `off`    | paused, dimmed                             |

The outline, in the bar's text colour at half strength, marks what belongs to
the widget; its width never changes, so the widgets next to it never move.
The colours (`Attention.qml`, `Attention.js`): the theme's own orange when it
has a real one, a standard orange otherwise, always a standard red, either one
darkened or lightened just enough to read at 3:1 against the bar.

- **Hover**: a view under the face shows a shell running `ping <host> -i 1`,
  updated twice a second.
- **Click**: pauses both pings (no traffic at all); the face reads `off` and
  the view shows the stopped ping, with its statistics. Another click types
  the ping again and restarts the face's. The pause is kept in `shell.json`,
  so it outlasts a restart of the shell.

## How it works

Two pings run all the time, one a second each:

- The face's own, `ping -n -O -i 1 -- <host>`, read line by line
  (`Latency.js`). A late reply still counts, so a slow link shows its round
  trip rather than "no net"; "no net" means nothing came back for 10 s. If
  ping ends (no name resolution, no network), it starts again 2 s later.
- The session's, typed at your own prompt in a tmux session on a server of
  its own, `coniglio-ping`, apart from your tmux (`ping-session.sh`,
  `tmux.conf`). The shell reads `~/.bashrc`, then the command is typed in by
  readline, so it looks and behaves as if typed by hand: it is a real history
  entry, and Ctrl+C leaves you at a real prompt. The face keeps measuring
  whatever you do there.

The hover view is `tmux capture-pane`, read every 0.5 s while it shows. A
pause sends Ctrl+C to the session's ping, a resume types the command again at
its prompt; one change at a time, each finished before the next, so quick
clicks never leave the session out of step with the face. To
type in that shell (stop the ping with Ctrl+C, Up to change the command),
attach to it from any terminal: `tmux -L coniglio-ping attach -t ping`.

What it costs, measured on Omarchy 4 (Hyprland 0.56, Ghostty): about 6 MB of
memory for the tmux server, the shell and the two pings together (PSS), and no
measurable CPU.

## Settings

The widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "coniglio.ping", "host": "www.google.it", "paused": false }
```

`host` is a hostname or an address; `www.google.it` when absent. `paused` is
set by clicks. After a
change, `tmux -L coniglio-ping kill-server` restarts the session on the new
host.

## Install

```bash
git clone https://github.com/stefanoconiglio/omarchy-ping.git ~/repos/omarchy-ping
ln -s ~/repos/omarchy-ping ~/.config/omarchy/plugins/coniglio.ping
omarchy plugin enable coniglio.ping right
```

Needs `ping` (iputils), `tmux`, and bash as the shell of the session.

## Files

| File               | Purpose                                                       |
|--------------------|---------------------------------------------------------------|
| `manifest.json`    | Omarchy plugin manifest for `coniglio.ping`                   |
| `Ping.qml`         | The face, its ping, the hover view                            |
| `Latency.js`       | Reply lines, state and label; `node Latency.test.js` tests it |
| `ping-session.sh`  | Starts the session; pauses and resumes its ping               |
| `tmux.conf`        | The session's tmux server: no status line                     |
| `Attention.qml/js` | The face's colours, readable on every theme's bar             |

## License

MIT, see [LICENSE](LICENSE).
