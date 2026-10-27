#!/usr/bin/env python3
"""expander-times.py <racket> [n] [args...]: run under a pty with PLT_EXPANDER_TIMES=1 (default REPL,
Ctrl-D at prompt) and print the region report lines of each run."""
import os,pty,time,select,signal,sys,re
R=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 1; args=sys.argv[3:] or ['-i']
for i in range(n):
    pid,fd=pty.fork()
    if pid==0: os.execvpe(R,[R]+args,dict(os.environ,TERM='xterm-256color',PLT_EXPANDER_TIMES='1'))
    buf=b''; t=time.monotonic(); sent=False
    while time.monotonic()-t<10:
        r,_,_=select.select([fd],[],[],0.2)
        if r:
            try: buf+=os.read(fd,1<<20)
            except OSError: break
        if not sent and re.search(rb'[\r\n]> ',buf) and time.monotonic()-t>0.3: os.write(fd,b'\x04'); sent=True
        if sent and b'expand' in buf and time.monotonic()-t>1.0: break
    try: os.kill(pid,signal.SIGKILL)
    except: pass
    txt=buf.decode('utf-8','replace').replace('\r','')
    print('\n'.join(l for l in txt.split('\n') if re.match(r'\s*[a-z0-9/+-]+\s+[\d.]+\s+\d+\s+[\d,]+\s+\d+',l)))
    print('---')
