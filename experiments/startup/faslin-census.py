#!/usr/bin/env python3
"""faslin-census.py <racket> [n]: run the default REPL under a pty with PLT_FASLIN_TRACE=1 (temporary
linklet.sls trace), send Ctrl-D at the prompt, and reduce the FASLIN lines to per-kind count/KB/ms.
With n>1 the per-kind ms is the median over runs."""
import os,pty,time,select,signal,sys,re,collections,statistics
R=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 1
runs=[]
for i in range(n):
    pid,fd=pty.fork()
    if pid==0: os.execvpe(R,[R,'-i'],dict(os.environ,TERM='xterm-256color',PLT_FASLIN_TRACE='1'))
    buf=b''; t=time.monotonic(); sent=False
    while time.monotonic()-t<10:
        r,_,_=select.select([fd],[],[],0.2)
        if r:
            try: buf+=os.read(fd,1<<20)
            except OSError: break
        if not sent and re.search(rb'[\r\n]> ', buf) and time.monotonic()-t>0.3:
            os.write(fd,b'\x04'); sent=True
        if sent and time.monotonic()-t>1.0: break
    try: os.kill(pid,signal.SIGKILL)
    except: pass
    txt=buf.decode('utf-8','replace').replace('\r','')
    per=collections.defaultdict(lambda:[0,0,0.0])
    for m in re.finditer(r'^FASLIN (\S+) (\d+) ([\d.]+)$',txt,re.M):
        k=m.group(1); v=per[k]; v[0]+=1; v[1]+=int(m.group(2)); v[2]+=float(m.group(3))
    runs.append(per)
kinds=sorted({k for p in runs for k in p}, key=lambda k:-max(p.get(k,[0,0,0])[2] for p in runs))
print(f"{'kind':24s} {'n':>5s} {'KB':>7s} {'ms(med)':>8s} {'us/KB':>6s}")
tot=[0,0,0.0]
for k in kinds:
    ns=[p[k][0] for p in runs if k in p]; kbs=[p[k][1]/1024 for p in runs if k in p]; mss=[p[k][2] for p in runs if k in p]
    nn=statistics.median(ns); kb=statistics.median(kbs); ms=statistics.median(mss)
    tot[0]+=nn; tot[1]+=kb; tot[2]+=ms
    print(f"{k:24s} {nn:5.0f} {kb:7.0f} {ms:8.2f} {1000*ms/kb if kb else 0:6.2f}")
print(f"{'total':24s} {tot[0]:5.0f} {tot[1]:7.0f} {tot[2]:8.2f}")
