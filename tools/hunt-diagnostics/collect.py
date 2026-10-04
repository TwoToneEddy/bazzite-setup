import pathlib as P, subprocess as S, datetime as D, time, json, gzip, shutil, os
root=P.Path(__file__).resolve().parent
out=root/D.datetime.now().strftime('%Y%m%d-%H%M%S');out.mkdir();(root/'latest.txt').write_text(str(out))
pid=27648; game=P.Path('/proc')/str(pid);start=(game/'stat').read_text().rsplit(')',1)[1].split()[19]
cwd=(game/'cwd').resolve(); children=[]
def read(p):
 try:return P.Path(p).read_text()
 except OSError:return None
def snapshot(name,cmd):
 with open(out/name,'w') as f:
  try:S.run(cmd,stdout=f,stderr=S.STDOUT,timeout=20)
  except Exception as e:f.write(str(e))
def follow(name,cmd):
 f=open(out/name,'w');children.append(S.Popen(cmd,stdout=f,stderr=S.STDOUT));f.close()
for name,cmd in [('gpu-baseline.txt',['nvidia-smi','-q']),('system.txt',['uname','-a']),('cpu.txt',['lscpu']),('disks.txt',['lsblk','-o','NAME,MODEL,FSTYPE,SIZE,MOUNTPOINTS']),('processes.txt',['ps','-eo','pid,ppid,comm,args']),('kernel-baseline.log',['journalctl','-k','-b','--no-pager'])]:snapshot(name,cmd)
env=read(game/'environ') or ''
allowed=('PROTON','WINE','DXVK','VKD3D','NVIDIA','__GL','MANGOHUD','LD_PRELOAD','SteamAppId','STEAM_COMPAT','ENABLE_VKBASALT')
(out/'game-environment.txt').write_text('\n'.join(e for e in env.split('\0') if e.startswith(allowed)))
for p in [cwd/'USER/Game.log',cwd/'USER/game.cfg',cwd/'USER/system.cfg',cwd/'system.cfg',cwd/'crycrash_error.log']:
 if p.is_file():shutil.copy2(p,out/('initial-'+p.name))
follow('kernel.log',['journalctl','-k','-f','-n','0','--no-pager','-o','short-iso-precise'])
follow('desktop.log',['journalctl','--user','-f','-n','0','--no-pager','-o','short-iso-precise','_COMM=kwin_wayland','_COMM=pipewire','_COMM=wireplumber'])
fields='timestamp,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr,clocks.mem,clocks_event_reasons.active,clocks_event_reasons.sw_power_cap,clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.hw_power_brake_slowdown,pcie.link.gen.gpucurrent,pcie.link.width.current'
follow('gpu.csv',['nvidia-smi','--query-gpu='+fields,'--format=csv','-lms','500'])
if (cwd/'USER/Game.log').is_file():follow('game-live.log',['tail','-n','0','-F',str(cwd/'USER/Game.log')])
sensors={}
for h in P.Path('/sys/class/hwmon').glob('hwmon*'):
 sensors[str(h)]={'name':read(h/'name'),'labels':{str(p):read(p) for p in h.glob('*_label')}}
(out/'sensor-labels.json').write_text(json.dumps(sensors))
sensorpaths=[p for h in P.Path('/sys/class/hwmon').glob('hwmon*') for pat in ['temp*_input','power*_average','fan*_input'] for p in h.glob(pat)]
paths=['/proc/stat','/proc/meminfo','/proc/vmstat','/proc/diskstats','/proc/pressure/cpu','/proc/pressure/io','/proc/pressure/memory','/proc/net/dev','/proc/net/snmp','/proc/net/netstat']
print(str(out),flush=True)
try:
 with gzip.open(out/'samples.jsonl.gz','wt',compresslevel=1) as f:
  deadline=time.monotonic()+7200;n=0
  while time.monotonic()<deadline:
   tick=time.monotonic();stat=read(game/'stat')
   if not stat or stat.rsplit(')',1)[1].split()[19]!=start:break
   row={'time':D.datetime.now().astimezone().isoformat(),'monotonic':tick,'system':{p:read(p) for p in paths},'game':{p:read(game/p) for p in ['stat','status','io','schedstat']},'threads':{}}
   for t in (game/'task').iterdir():row['threads'][t.name]={p:read(t/p) for p in ['stat','schedstat','wchan']}
   if n%5==0:
    row['sensors']={str(p):read(p) for p in sensorpaths}
    row['processes']={}
    for p in P.Path('/proc').iterdir():
     if p.name.isdigit():row['processes'][p.name]=read(p/'stat')
    row['cache']={str(p):{'size':p.stat().st_size,'mtime':p.stat().st_mtime} for p in cwd.glob('vkd3d*') if p.is_file()}
   row['collection_seconds']=time.monotonic()-tick
   f.write(json.dumps(row)+'\n');f.flush();n+=1
   time.sleep(max(0,1-(time.monotonic()-tick)))
finally:
 for p in children:p.terminate()
 for p in children:
  try:p.wait(timeout=3)
  except S.TimeoutExpired:p.kill()
 if (cwd/'USER/Game.log').is_file():shutil.copy2(cwd/'USER/Game.log',out/'final-Game.log')
 (out/'finished.txt').write_text(D.datetime.now().astimezone().isoformat())
