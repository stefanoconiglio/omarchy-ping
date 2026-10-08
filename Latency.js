// What the face makes of a continuous `ping -n -O -i 1 <host>`, read one line
// at a time: the latest round trip, and whether replies still come.
//
// Plain functions, so the file runs under node too (Latency.test.js).

var slowMs = 50          // orange from here
var badMs = 100          // red from here
var downAfterMs = 10000  // no reply for this long: no network

// Hostnames and addresses only: the host is passed to ping and typed into a
// shell by readline.
function validHost(host) {
  return /^[A-Za-z0-9][A-Za-z0-9.:-]*$/.test(String(host || ""))
}

// The round trip of a reply line, in ms; null for any other line.
//   64 bytes from 142.250.129.94: icmp_seq=12 ttl=110 time=73.8 ms
function replyMs(line) {
  var m = /\bicmp_seq=\d+ .*\btime[=<]([0-9]+(?:\.[0-9]+)?) ?ms\b/.exec(String(line || ""))
  return m ? Number(m[1]) : null
}

// "down" once nothing has come back for downAfterMs (quietMs: since the last
// reply, or since the start before any), "waiting" before the first reply,
// otherwise "good", "slow" or "bad" by the latest round trip. A late reply
// still counts: on a slow link the face shows 5.6 s, not "no net".
function status(ms, hasReply, quietMs) {
  if (quietMs > downAfterMs) return "down"
  if (!hasReply) return "waiting"
  if (ms >= badMs) return "bad"
  if (ms >= slowMs) return "slow"
  return "good"
}

function label(state, ms, vertical) {
  if (state === "none") return "—"
  if (state === "down") return vertical ? "×" : "no net"
  if (state === "waiting") return "…"
  if (vertical) return String(Math.round(ms))
  return ms >= 1000 ? (ms / 1000).toFixed(1) + " s" : Math.round(ms) + " ms"
}

if (typeof module !== "undefined") {
  module.exports = {
    slowMs: slowMs,
    badMs: badMs,
    downAfterMs: downAfterMs,
    validHost: validHost,
    replyMs: replyMs,
    status: status,
    label: label
  }
}
