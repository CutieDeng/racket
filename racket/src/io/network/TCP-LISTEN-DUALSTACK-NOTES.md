# tcp-listen wildcard port-0: two-socket + retry vs single dual-stack socket

Status: DESIGN NOTE (no change recommended at present).
Audience: whoever next touches the listen path in `tcp-listen.rkt` /
`rktio_network.c`, or investigates a port-0 `EADDRINUSE` report. Written
2026-08-18 against v9.3-dev (9.3.3), after the question "should Racket adopt
Go's model?" was analyzed with experiments. Verify file:line references
before relying on them.

## 1. Current model (what ships)

`(tcp-listen 0)` on a wildcard address binds ONE SOCKET PER ADDRESS FAMILY
and presents a single port:

- `racket/src/io/network/tcp-listen.rkt:59-61` — `rktio_listen_opt` gets
  `RKTIO_LISTEN_RETRY_ADDRINUSE` **only when `port-no` is literally 0**.
- `racket/src/rktio/rktio_network.c` (listen path) — binds IPv6 first with
  `IPV6_V6ONLY=1` set **explicitly** (deterministic cross-platform behavior;
  some kernels default 0, some 1, OpenBSD forces 1), reads the ephemeral
  port the kernel picked (`get_no_portno`), then binds the remaining
  families to that same port (`first_was_zero`/`no_port`).
- The second bind can hit `EADDRINUSE`: the kernel only guaranteed the port
  free in the first family's namespace. Classic TOCTOU. With the flag, the
  whole allocation restarts (all sockets closed, fresh port-0 bind → fresh
  ephemeral port), at most `MAX_LISTEN_RETRY_ADDRINUSE_COUNT` (4) times,
  and only for `EADDRINUSE`. Explicit ports never retry (fail fast is
  correct there — an in-use explicit port usually means a leaked listener).

Residual failure = 5 consecutive collisions ≈ ephemeral-range exhaustion or
adversarial squatting, where erroring is the desired behavior.

## 2. The alternative (Go's model) and what experiments showed

Go/Java/Node bind ONE `AF_INET6` socket with `IPV6_V6ONLY=0`; the kernel
allocates the port atomically and v4 peers arrive as v4-mapped
(`::ffff:a.b.c.d`) addresses, which Go unmaps before surfacing. Verified
on macOS (M5, Darwin 25.4) 2026-08-18:

- `net.Listen("tcp", ":0")` → lsof shows exactly ONE fd
  (`IPv6 *:PORT LISTEN`); dialing `tcp4 127.0.0.1:PORT` and
  `tcp6 [::1]:PORT` both connect; `RemoteAddr()` reports the v4 peer as
  plain `127.0.0.1` (unmapped). `sysctl net.inet6.ip6.v6only` = 0 (macOS
  default allows dual-stack).
- **The trick only covers wildcard binds.** `net.Listen("tcp",
  "localhost:0")` bound ONLY `127.0.0.1`; dialing `[::1]` was refused.
  v4-mapped reception works for wildcard-bound sockets, not for sockets
  bound to a specific v6 address. Go simply does not offer
  "all resolved addresses share one port".
- On OpenBSD the kernel forbids dual-stack (v6only immutable), and Go's
  wildcard listen silently degrades to an **IPv4-only** socket — the model
  keeps one socket by sacrificing an address family.

## 3. Why Racket stays with two-socket + retry (for now)

1. **Racket's semantics are strictly richer.** `tcp-listen` with a hostname
   binds ALL getaddrinfo results (e.g. both loopbacks for "localhost") on
   one port. That case is inherently multi-socket — no kernel primitive
   makes it atomic (POSIX has no "bind these fds to one fresh port") — so
   the retry machinery must exist regardless. A single-socket wildcard fast
   path would only *narrow* the retry's use, at the cost of a second code
   path.
2. **Address semantics are a real compat surface.** Single-socket means v4
   peers appear as `::ffff:...` unless unmapping is implemented everywhere
   addresses escape (`tcp-addresses`, accept results, logging users rely
   on). Go built unmapping in from day one; retrofitting 25-year-old
   observable behavior risks user-visible breakage that outweighs the
   benefit.
3. **The benefit is already ~zero.** Bounded retry collapses the wildcard
   race to negligible probability; what remains (exhaustion/adversarial)
   *should* error.

## 4. If this is ever revisited

Trigger: real reports of hitting the 4-retry ceiling under legitimate load,
or per-fd cost pressure from massive listener counts.

Sketch: runtime probe (create AF_INET6, clear V6ONLY, test-bind
`::ffff:127.0.0.1` — Go's probe) → wildcard listens use one socket;
non-wildcard and probe-failure keep today's path. MUST ship together with
v4-mapped unmapping at every address egress, and MUST keep OpenBSD (and any
forced-v6only platform) on the two-socket path binding BOTH families (do
not copy Go's v4-only degradation — it trades away reachability silently).
