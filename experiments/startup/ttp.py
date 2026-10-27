#!/usr/bin/env python3
"""pty time-to-prompt. usage: ttp.py [-n N] [--prompt REGEX] [--env K=V ...] [--wait S] -- <racket> [args...]
Prints per-run ttp (ms, spawn to prompt) and min/median. Sends Ctrl-D `wait` seconds after the prompt."""
import os, pty, re, sys, time, select, statistics, argparse, signal
ap = argparse.ArgumentParser()
ap.add_argument('-n', type=int, default=5)
ap.add_argument('--prompt', default=r'[\r\n](-> |> )')
ap.add_argument('--env', action='append', default=[])
ap.add_argument('--wait', type=float, default=0.3)
ap.add_argument('cmd', nargs=argparse.REMAINDER)
a = ap.parse_args()
cmd = a.cmd[1:] if a.cmd and a.cmd[0] == '--' else a.cmd
env = dict(os.environ); env.update(kv.split('=', 1) for kv in a.env)
env['TERM'] = env.get('TERM', 'xterm-256color')
pat = re.compile(a.prompt.encode())
def one():
    t = time.monotonic()
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(cmd[0], cmd, env)
    buf = b''; ttp = None
    while True:
        r, _, _ = select.select([fd], [], [], 10)
        if not r:
            os.kill(pid, signal.SIGKILL); break
        try: data = os.read(fd, 65536)
        except OSError: break
        if not data: break
        buf += data
        if ttp is None and pat.search(buf[-64:]):
            ttp = (time.monotonic() - t) * 1000
            time.sleep(a.wait); os.write(fd, b'\x04')
    os.waitpid(pid, 0); os.close(fd)
    return ttp
xs = []
for i in range(a.n):
    v = one(); xs.append(v); print(f"run {i}: {v and round(v,1)}", file=sys.stderr)
xs = [x for x in xs if x is not None]
print(f"n={len(xs)} min={min(xs):.1f} median={statistics.median(xs):.1f}")
