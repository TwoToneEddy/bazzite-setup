from pathlib import Path
import re,json,gzip,collections,shutil
p=Path('/var/home/lee/bazzite-setup/tools/hunt-diagnostics/20261003-204501-deep');k=next(x for x in p.glob('kernel-*') if x.is_dir());fpath=k/'kernel-trace.log'
pat=re.compile(rb'\s(\d+\.\d+): ')
def seektime(f,target):
 lo=0;hi=fpath.stat().st_size
 while hi-lo>65536:
  mid=(lo+hi)//2;f.seek(mid);f.readline();b=f.read(32768);m=pat.search(b)
  if not m:hi=mid;continue
  if float(m[1])<target:lo=mid
  else:hi=mid
 return max(0,lo-65536)
counts=collections.Counter();events=[];lost=[]
with fpath.open('rb') as f, (p/'freeze-selected-trace.log').open('wb') as o:
 f.seek(seektime(f,920));f.readline();last=0;keep=False
 for l in f:
  m=pat.search(l)
  if m:last=float(m[1])
  if last>932:break
  if last<920:continue
  if b'LOST' in l:lost.append(l.decode())
  if m:
   keep=bool(re.search(rb'-(7341|7523|7609|7647)\s',l)) or b'pid=7341 ' in l or b'pid=7523 ' in l
  if keep:o.write(l)
print('EXTRACTED', (p/'freeze-selected-trace.log').stat().st_size,'lost notices',lost[:5])
