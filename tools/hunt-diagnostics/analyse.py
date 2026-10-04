import pathlib as P,gzip,json,csv,datetime as D,collections
out=P.Path(P.Path('/var/home/lee/bazzite-setup/tools/hunt-diagnostics/latest.txt').read_text())
s=[json.loads(l) for l in gzip.open(out/'samples.jsonl.gz','rt')]
def ts(v):return D.datetime.fromisoformat(v).timestamp()
def fields(v):return v.rsplit(')',1)[1].split()
def cpu(v):f=fields(v);return int(f[11])+int(f[12])
def net(r):
 for l in r['system']['/proc/net/dev'].splitlines():
  if 'enp5s0:' in l:return list(map(int,l.split(':')[1].split()))
def snmp(r):
 l=r['system']['/proc/net/snmp'].splitlines();d={}
 for a,b in zip(l[::2],l[1::2]):
  k=a.split();v=b.split();d.update({k[0]+'.'+x:int(y) for x,y in zip(k[1:],v[1:])})
 return d
print('SAMPLES',len(s),s[0]['time'],s[-1]['time'])
x,y=net(s[0]),net(s[-1]);print('NIC COUNTER DELTAS', [b-a for a,b in zip(x,y)])
x,y=snmp(s[0]),snmp(s[-1]);print('PROTOCOL ERROR DELTAS',{k:y[k]-x[k] for k in y if any(w in k for w in ['Retrans','Errors','Discards','Fails','NoPorts'])})
# Identify consecutive low game CPU intervals
runs=[];run=[]
for i in range(1,len(s)):
 a,b=s[i-1:i+1];delta=cpu(b['game']['stat'])-cpu(a['game']['stat'])
 if delta<100:run.append(i)
 else:
  if len(run)>=2:runs.append(run)
  run=[]
if len(run)>=2:runs.append(run)
for run in runs:
 a=s[run[0]-1];b=s[run[-1]]
 print('\nSTALL',a['time'],b['time'],'seconds',len(run))
 print('NETWORK rx/tx packets each second',[(net(s[i])[1]-net(s[i-1])[1],net(s[i])[9]-net(s[i-1])[9]) for i in run][:30])
 changes=[]
 for tid,t in b['threads'].items():
  if tid not in a['threads'] or not t['stat'] or not a['threads'][tid]['stat']:continue
  dt=cpu(t['stat'])-cpu(a['threads'][tid]['stat']);name=t['stat'].split('(',1)[1].rsplit(')',1)[0]
  changes.append((dt,tid,name,t['wchan']))
 print('ACTIVE THREADS',sorted(changes,reverse=True)[:12])
 print('KEY WAITS',[(tid,t['stat'].split('(',1)[1].rsplit(')',1)[0],t['wchan']) for tid,t in b['threads'].items() if t['stat'] and any(k in t['stat'] for k in ['(Main)','Render','Net','Streaming'])])
 print('PRESSURE',b['system']['/proc/pressure/io'].strip(),b['system']['/proc/pressure/memory'].strip())
print('\nGPU flags counts')
r=list(csv.DictReader(open(out/'gpu.csv')))
for k in r[0]:
 if 'reasons' in k:print(k,collections.Counter(x[k] for x in r))
