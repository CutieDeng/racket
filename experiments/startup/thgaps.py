#!/usr/bin/env python3
"""thgaps.py <th.log> [min_gap_ms]: print events with wall/cpu/gc/alloc deltas; flag gaps >= min_gap."""
import sys
f=sys.argv[1]; mg=float(sys.argv[2]) if len(sys.argv)>2 else 1.0
prev=None
for ln in open(f, errors='replace'):
    p=ln.rstrip('\n').split(' ',5)
    if len(p)<6: continue
    tag,w,c,g,a,info=p[0],float(p[1]),int(p[2]),int(p[3]),int(p[4]),p[5]
    if prev:
        dw=w-prev[1]; dc=c-prev[2]; dg=g-prev[3]; da=(a-prev[4])/1024
        print(f"{'':6}  +{dw:6.2f}w +{dc:3d}c +{dg:2d}g {da:8.0f}KB{'  <== GAP' if dw>=mg else ''}")
    print(f"{w:7.2f} {tag:4} {info}")
    prev=(tag,w,c,g,a)
