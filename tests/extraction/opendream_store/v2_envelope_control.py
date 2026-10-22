"""Frozen registered-v2 actual methods; effects must be injected by tests."""
from pathlib import PurePosixPath
import backend as b
import run as r
from hosted import seal_outputs, OUTPUT_KEYS

def observe_control(self, owned, phase, deadline):
        self._check(deadline)
        members = self.fx.members(owned)
        r.need(len(members)<=256, 'owned process count bound')
        names = self.fx.files(self.root, deadline)
        sizes = self.fx.sizes(self.root,names)
        sockets = self.fx.sockets(members)
        r.need(len(sockets)<=128, 'owned socket count bound')
        unexpected = False; clients = 0; outbound = 0
        for s in sockets:
            # Only IPv4 127.0.0.1 UDP19567 and Topic TCP LISTEN ephemeral.
            local, port = s['local'].split(':')
            allowed = (phase == 'runtime' and local == '0100007F' and
                ((s['proto'] == 'udp' and int(port,16) == 19567) or
                 (s['proto'] == 'tcp' and s['state'] == '0A' and int(port,16) != 0)))
            unexpected |= (not allowed if phase != 'setup' else s['proto'].startswith('tcp') and s['state'] == '0A')
            clients += int(phase == 'runtime' and s['proto'].startswith('tcp') and s['state'] != '0A')
            outbound += int(int(s['remote'].replace(':',''),16) != 0)
        tcp = [s for s in sockets if s['proto']=='tcp' and s['state']=='0A']
        udp = [s for s in sockets if s['proto']=='udp']
        if phase == 'runtime': unexpected |= len(tcp)>1 or len(udp)>1
        runtime = phase == 'runtime'
        # Runtime bytes are only its case, not source-build workspace contents.
        if runtime:
            prefix = 'cases/'+self.current+'/'
            selected = [(p,n) for p,n in zip(names,sizes) if p.startswith(prefix)]
        else: selected = list(zip(names,sizes))
        sample = {'owned':all(int(m['birth']) >= int(owned.birth) for m in members),
                  'clients':clients, 'outbound':outbound, 'unexpected_listener':unexpected,
                  'bytes':sum(n for p,n in selected), 'files':len(selected),
                  'depth':max((len(PurePosixPath(p).parts) for p,n in selected), default=0),
                  'rss':sum(m['rss'] for m in members), 'sockets':sockets,
                  'listeners_ready':len(tcp)==1 and len(udp)==1,'monitor_epoch':owned.label}
        return sample

def execute_control(route,digest,backend,clock,utc,*,entered=None,entered_utc=None):
    entered=clock() if entered is None else entered
    entered_utc=utc() if entered_utc is None else entered_utc
    backend.begin(route,digest,entered,entered_utc)
    primary=None; secondary=[]; result=None
    try:
        deadline=min(backend.work_end,entered+1500)
        last=None; epoch=None
        def guard(sample):
            nonlocal last,epoch
            backend._check(deadline); now=clock()
            if epoch!=sample.get('monitor_epoch'): last=None; epoch=sample.get('monitor_epoch')
            if last is not None:
                interval=route['resource_envelope']['sample_interval_seconds']
                r.need(interval*.5<=now-last<=interval*1.5,'bootstrap monitor cadence')
            r.observe(sample,route,build=True); last=now
        admitted=backend.bootstrap(deadline,guard)
        backend._check(deadline)
        # Fresh independent bytes-to-pins check before the existing five-case
        # orchestrator. Its own budget cannot extend backend's original deadline.
        r.need(seal_outputs(backend.package_bytes)=={k:admitted[k] for k in OUTPUT_KEYS},'package admission drift')
        r.admission_check(admitted)
        result=r.orchestrate(admitted,backend.inputs,backend.startup,backend,clock,utc=utc,
                             admission_sha256=r.sha(b.encoded(admitted)))
    except BaseException as error:
        primary=error
    finally:
        # Also covers bootstrap failure and pre-reserve orchestration rejection.
        clean_end=min(backend.end,clock()+30)
        try:
            clean=backend.cleanup(backend.token,clean_end)
            r.need(clean and clock()<=clean_end,'bootstrap/final cleanup failed')
        except BaseException as error: secondary.append(str(error)[:512])
        try:
            backend.fx.claim(backend.claim_dir+'/'+b.relative(route['allocation_id'])+'.bootstrap-receipt.json',
                b.encoded({'route':digest,'status':'FAIL' if primary or secondary else 'PASS',
                'primary':str(primary)[:1024] if primary else None,'secondary':secondary[:4],
                'receipts':backend.receipts}))
        except BaseException as error: secondary.append('retention: '+str(error)[:400])
    if primary:
        if secondary: raise r.Rejected(str(primary)[:1024]+'; cleanup/receipt: '+'; '.join(secondary[:4])) from primary
        raise primary
    r.need(not secondary,'; '.join(secondary[:4]))
    return result
