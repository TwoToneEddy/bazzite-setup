#!/usr/bin/python3
"""Run with sudo during a game: Four-hour isolated scheduler/syscall trace and network metadata."""
import os,pathlib as P,subprocess as S,time,signal,selectors,json,datetime,shutil
if os.geteuid()!=0:raise SystemExit('Run this script with sudo in your terminal.')
root=P.Path(__file__).resolve().parent;out=P.Path((root/'latest.txt').read_text().strip())
if not (out/'game-pid.txt').exists() or (out/'finished.txt').exists():raise SystemExit('Start collect-next.py and the game first; no active new capture found.')
pid=int((out/'game-pid.txt').read_text());proc=P.Path('/proc')/str(pid)
if not proc.exists():raise SystemExit('Recorded game has exited.')
out=out/('kernel-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()))
out.mkdir(mode=0o700)
os.chown(out,int(os.environ.get('SUDO_UID','0')),int(os.environ.get('SUDO_GID','0')))
tids=[];names={}
for t in (proc/'task').iterdir():
 try:name=(t/'comm').read_text().strip()
 except OSError:continue
 if int(t.name)==pid or any(w in name.lower() for w in ['renderthread','streaming file','shadercompile','network','vkd3d']):tids.append(int(t.name));names[t.name]=name
trace=P.Path('/sys/kernel/tracing/instances')/('huntdiag-'+str(os.getpid()))
if not trace.parent.exists():raise SystemExit('Kernel tracefs instances unavailable; no settings changed.')
children=[];sel=selectors.DefaultSelector();files=[];total=0
os.umask(0o077)
def write(p,s):p.write_text(str(s))
def stop(*_):raise KeyboardInterrupt
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
trace.mkdir()
try:
 write(trace/'tracing_on','0');write(trace/'trace_clock','mono');write(trace/'buffer_size_kb','2048')
 selected=' || '.join('common_pid == '+str(t) for t in tids)
 enabled=[]
 for ev,expr in [('sched/sched_switch',' || '.join('prev_pid == '+str(t)+' || next_pid == '+str(t) for t in tids)),('sched/sched_wakeup',' || '.join('pid == '+str(t) for t in tids))]:
  d=trace/'events'/ev;write(d/'filter',expr);write(d/'enable','1');enabled.append(ev)
 for call in ['futex','futex_waitv','ioctl','poll','ppoll','epoll_wait','epoll_pwait','read','recvfrom','recvmsg','sendto','sendmsg']:
  for side in ['enter','exit']:
   ev='syscalls/sys_'+side+'_'+call;d=trace/'events'/ev
   if d.exists():write(d/'filter',selected);write(d/'enable','1');enabled.append(ev)
 # Kernel stacks on blocking switches of the actual main and rendering threads.
 blocking=[t for t in tids if t==pid or 'renderthread' in names[str(t)].lower()]
 try:write(trace/'events/sched/sched_switch/trigger','stacktrace if ('+' || '.join('prev_pid == '+str(t) for t in blocking)+') && prev_state != 0')
 except OSError as e:(out/'stack-trigger-error.txt').write_text(str(e))
 (out/'kernel-trace-metadata.json').write_text(json.dumps({'time':datetime.datetime.now().astimezone().isoformat(),'monotonic':time.monotonic(),'pid':pid,'threads':names,'events':enabled,'note':'Kernel stacks only; no userspace lock-owner attribution. Trace may alter timing.'},indent=2))
 fd=os.open(trace/'trace_pipe',os.O_RDONLY|os.O_NONBLOCK);f=open(out/'kernel-trace.log','wb');files.append(f);sel.register(fd,selectors.EVENT_READ,f)
 route=json.loads(S.check_output(['ip','-j','route','show','default']));iface=route[0]['dev']
 net=S.Popen(['tcpdump','-i',iface,'-nn','-tttt','-q','-l','-s','96','tcp or udp'],stdout=S.PIPE,stderr=open(out/'packet-capture-status.log','w'))
 children.append(net);nf=open(out/'packet-metadata.log','wb');files.append(nf);os.set_blocking(net.stdout.fileno(),False);sel.register(net.stdout,selectors.EVENT_READ,nf)
 write(trace/'tracing_on','1');print('Tracing for up to 4 hours / 100 GiB into '+str(out)+'. Ctrl+C stops and cleans up.',flush=True)
 deadline=time.monotonic()+14400
 while time.monotonic()<deadline and proc.exists() and total<100*1024*1024*1024:
  for key,_ in sel.select(timeout=0.5):
   try:data=os.read(key.fd,65536)
   except BlockingIOError:continue
   if data:key.data.write(data);total+=len(data)
  for f in files:f.flush()
finally:
 try:write(trace/'tracing_on','0')
 except OSError:pass
 for p in children:
  p.terminate()
  try:p.wait(timeout=3)
  except S.TimeoutExpired:p.kill();p.wait()
 for key in list(sel.get_map().values()):
  sel.unregister(key.fileobj)
  if isinstance(key.fileobj,int):os.close(key.fileobj)
 for f in files:f.close()
 try:trace.rmdir()
 except OSError as e:print('Trace disabled; instance removal failed:',e)
 uid=int(os.environ.get('SUDO_UID','0'));gid=int(os.environ.get('SUDO_GID','0'))
 for name in ['kernel-trace.log','kernel-trace-metadata.json','packet-metadata.log','packet-capture-status.log','stack-trigger-error.txt']:
  f=out/name
  if f.exists():os.chown(f,uid,gid)
 print('Capture stopped; wrote %.2f GiB. Files: %s' % (total/(1024**3),out),flush=True)
 print('No global tracing or power settings changed.',flush=True)
