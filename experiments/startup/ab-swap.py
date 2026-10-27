#!/usr/bin/env python3
"""Interleaved same-binary A/B by swapping one file between runs (cp -p keeps mtime; the swapped file's
mtime must be newer than its source or the loader compiles from source).
usage: ab-swap.py --target <path> --a <fileA> --b <fileB> [-n N] [--prompt RE] -- <cmd...>"""
import os, sys, argparse, subprocess, statistics
here = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--target', required=True); ap.add_argument('--a', required=True); ap.add_argument('--b', required=True)
ap.add_argument('-n', type=int, default=10); ap.add_argument('--prompt', default=r'[\r\n](-> |> )')
ap.add_argument('cmd', nargs=argparse.REMAINDER)
a = ap.parse_args()
cmd = a.cmd[1:] if a.cmd and a.cmd[0] == '--' else a.cmd
sys.argv = ['ttp.py', '-n', '1', '--prompt', a.prompt, '--'] + cmd
src = open(os.path.join(here, 'ttp.py')).read().split('xs = []')[0]
g = {}; exec(src, g); one = g['one']
def put(f): subprocess.run(['cp', '-p', f, a.target], check=True)
A=[]; B=[]
for i in range(a.n):
    put(a.a); x = one(); put(a.b); y = one()
    A.append(x); B.append(y)
    print(f"pair {i}: A {x:.1f}  B {y:.1f}  A-B {x-y:+.1f}", file=sys.stderr)
put(a.a)
d = [x-y for x,y in zip(A,B)]
print(f"n={a.n} A med {statistics.median(A):.1f} min {min(A):.1f} | B med {statistics.median(B):.1f} min {min(B):.1f} | A-B med {statistics.median(d):+.1f}, positive {sum(1 for v in d if v>0)}/{len(d)}")
