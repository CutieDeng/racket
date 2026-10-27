#!/usr/bin/env python3
"""boot-stamps.py <racket> [n] [args...]: run with PLT_BOOT_STAMPS=1 under a pty (default: -i, Ctrl-D at
prompt) n times; print per-stage wall/cpu/gc deltas (median over runs). The first stamp's cpu is the CPU
spent before main.sps (Chez boot files + rumble/thread/io/expander instantiation)."""
import os,pty,time,select,signal,sys,re,statistics,collections
R=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 5; args=sys.argv[3:] or ['-i']
runs=[]
for i in range(n):
    pid,fd=pty.fork()
    if pid==0: os.execvpe(R,[R]+args,dict(os.environ,TERM='xterm-256color',PLT_BOOT_STAMPS='1'))
    buf=b''; t=time.monotonic(); sent=False
    while time.monotonic()-t<8:
        r,_,_=select.select([fd],[],[],0.1)
        if r:
            try: buf+=os.read(fd,1<<20)
            except OSError: break
        if not sent and re.search(rb'[\r\n]> ',buf) and time.monotonic()-t>0.3: os.write(fd,b'\x04'); sent=True
        if (sent and time.monotonic()-t>0.6) or (not sent and b'STAMP gc-window-closed' in buf and '-i' not in args and time.monotonic()-t>0.5): break
    try: os.kill(pid,signal.SIGKILL)
    except: pass
    st=[(m.group(1),float(m.group(2)),int(m.group(3)),int(m.group(4))) for m in re.finditer(rb'STAMP (\S+) ([\d.]+) (\d+) (\d+)',buf)]
    st=[(a.decode(),b,c,d) for a,b,c,d in st]
    runs.append(st)
if not runs or not runs[0]: print("no stamps"); sys.exit(1)
names=[s[0] for s in runs[0]]
print(f"{'stage':34s} {'wall':>7s} {'cpu':>5s} {'gc':>4s}   (median of %d; cpu = user+sys ms since exec; first row = before first stamp)"%n)
for i,name in enumerate(names):
    if i==0:
        print(f"{'<exec/dyld -> '+name+'>':34s} {'':>7s} {statistics.median(r[0][2] for r in runs):5.0f} {statistics.median(r[0][3] for r in runs):4.0f}")
        continue
    w=statistics.median(r[i][1]-r[i-1][1] for r in runs if len(r)>i); c=statistics.median(r[i][2]-r[i-1][2] for r in runs if len(r)>i); g=statistics.median(r[i][3]-r[i-1][3] for r in runs if len(r)>i)
    print(f"{'-> '+name:34s} {w:7.1f} {c:5.0f} {g:4.0f}")
