#!/usr/bin/env python3
"""linklet-times.py <racket> [n]: default REPL under a pty with PLT_LINKLET_TIMES=1, Ctrl-D at the prompt,
print faslin-code / faslin-literals / read-bundle / read / instantiate / total ms per run."""
import os,pty,time,select,signal,sys,re
R=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 3
for i in range(n):
    pid,fd=pty.fork()
    if pid==0: os.execvpe(R,[R,'-i'],dict(os.environ,TERM='xterm-256color',PLT_LINKLET_TIMES='1'))
    buf=b''; t=time.monotonic(); sent=False
    while time.monotonic()-t<8:
        r,_,_=select.select([fd],[],[],0.2)
        if r:
            try: buf+=os.read(fd,65536)
            except OSError: break
        if not sent and b'> ' in buf and time.monotonic()-t>0.3:
            os.write(fd,b'\x04'); sent=True
        if sent and b'total' in buf and time.monotonic()-t>1.0: break
    try: os.kill(pid,signal.SIGKILL)
    except: pass
    txt=buf.decode('utf-8','replace').replace('\r','')
    g=lambda k: (re.search(k+r'\s+(\d+)',txt) or [None,'?'])[1]
    print(f"faslin-code {g('faslin-code')} faslin-literals {g('faslin-literals')} read-bundle {g('read-bundle')} read {g(';; read')} instantiate {g('instantiate')} total {g('total')}")
