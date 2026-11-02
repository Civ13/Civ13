"""Hosted data-only PE/provider facts. Never loads or launches a BYOND binary."""
import argparse, hashlib, json, os, platform, re, struct, time
from pathlib import Path
from urllib.parse import urlsplit
import urllib.request
import acquire as A

EVIDENCE_CAP = 4 * 1024**2

def require(value, message):
    if not value: raise ValueError(message)

def https_url(url):
    parsed = urlsplit(url)
    require(parsed.scheme == 'https' and parsed.port in (None, 443) and not parsed.username
            and not parsed.password and parsed.hostname and
            (parsed.hostname == 'byond.com' or parsed.hostname.endswith('.byond.com')),
            'Data acquisition requires official BYOND HTTPS on port443')

class OfficialRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        https_url(newurl)
        return super().redirect_request(request, fp, code, msg, headers, newurl)

def pe_imports(raw):
    def unpack(fmt, offset):
        require(0 <= offset <= len(raw)-struct.calcsize(fmt), 'PE field outside input')
        return struct.unpack_from(fmt, raw, offset)
    require(raw[:2] == b'MZ', 'Expected PE image')
    nt = unpack('<I', 0x3c)[0]
    require(raw[nt:nt+4] == b'PE\0\0', 'PE signature')
    machine, count = unpack('<HH', nt+4); opt = nt+24
    require(0 < count <= 96, 'PE section bound')
    optional_size = unpack('<H', nt+20)[0]; magic = unpack('<H', opt)[0]
    require(magic in (0x10b, 0x20b), 'PE optional format')
    directory = opt + (96 if magic == 0x10b else 112)
    image_base = unpack('<I' if magic == 0x10b else '<Q', opt+(28 if magic == 0x10b else 24))[0]
    headers = unpack('<I', opt+60)[0]; sections = []
    for i in range(count):
        virtual_size, address, raw_size, start = unpack('<IIII', opt+optional_size+i*40+8)
        sections.append((address, max(virtual_size, raw_size), start, raw_size))
    def offset(rva):
        require(rva >= 0, 'Negative PE RVA')
        if rva < headers: return rva
        for address, size, start, raw_size in sections:
            if address <= rva < address+size:
                require(rva-address < raw_size, 'PE RVA has no file bytes')
                return start+rva-address
        raise ValueError('Unmapped PE RVA')
    def dll_name(rva):
        start = offset(rva); end = raw.find(b'\0', start, min(len(raw), start+512))
        require(end >= start, 'DLL name bound')
        name = raw[start:end].decode('ascii')
        require(re.fullmatch(r'[A-Za-z0-9_.-]+\.(?:dll|drv|ocx)', name, re.I), 'Nonliteral DLL name')
        return name
    directory_count = unpack('<I', opt+(92 if magic==0x10b else 108))[0]
    require(directory_count <= 32, 'PE data directory count bound')
    imports = []
    for index, kind, width in ((1, 'normal', 20), (13, 'delay', 32)):
        if index >= directory_count: continue
        rva, size = unpack('<II', directory+index*8)
        if not rva: continue
        base = offset(rva)
        for i in range(256):
            row = unpack('<'+'I'*(width//4), base+i*width)
            if not any(row): break
            name = row[3] if kind == 'normal' else row[1]-(0 if row[0]&1 else image_base)
            imports.append(dict(kind=kind, name=dll_name(name)))
        else: raise ValueError('DLL import count bound')
    return dict(machine=machine, format='PE32' if magic == 0x10b else 'PE32+', imports=imports)

def pe_machine(raw):
    require(len(raw)>=64 and raw[:2]==b'MZ', 'Provider image header')
    offset=struct.unpack_from('<I',raw,0x3c)[0]
    require(offset<=len(raw)-6 and raw[offset:offset+4]==b'PE\0\0', 'Provider PE header')
    return struct.unpack_from('<H',raw,offset+4)[0]

def admit_source(source, environment, system_name):
    require(system_name=='nt' and environment.get('RUNNER_ENVIRONMENT')=='github-hosted'
            and environment.get('RUNNER_OS')=='Windows' and environment.get('GITHUB_REPOSITORY')=='Civ13/Civ13'
            and environment.get('GITHUB_EVENT_NAME')=='workflow_dispatch', 'Exact repository hosted Windows manual audit only')
    require(re.fullmatch('[0-9a-f]{40}',source) and environment.get('GITHUB_SHA')==environment.get('GITHUB_WORKFLOW_SHA')==source
            and environment.get('GITHUB_RUN_ATTEMPT')=='1', 'Exact fresh source/workflow attempt1')

class Reader:
    def __init__(self, deadline):
        self.deadline = deadline; self.total = 0; self.cache = {}; self.paths = set()
    def read(self, path):
        require(time.monotonic() < self.deadline, 'Static audit deadline')
        path = Path(path); key = str(path.absolute()).casefold(); self.paths.add(key)
        require(len(self.paths) <= 128, 'Provider path bound')
        if key in self.cache: return self.cache[key]
        if not path.is_file(): return None
        before = path.stat()
        require(not path.is_symlink() and not getattr(before, 'st_file_attributes', 0)&0x400, 'Linked provider')
        require(0 < before.st_size <= 32*1024**2 and self.total+before.st_size <= 256*1024**2, 'Static read byte bound')
        raw = path.read_bytes(); after = path.stat()
        require((before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns) and len(raw)==before.st_size, 'Provider changed while reading')
        self.total += len(raw); self.cache[key] = raw
        return raw

def collect(binary, manifest, system_root, deadline):
    binary = Path(binary); reader = Reader(deadline); modules = {}; facts = []
    require(0 < len(manifest['files']) <= 256, 'Toolchain count bound')
    actual = {p.relative_to(binary).as_posix() for p in binary.rglob('*') if p.is_file()}
    require(actual == set(manifest['files']), 'Toolchain inventory drift')
    for name, expected in manifest['files'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts, 'Toolchain path')
        raw = reader.read(binary/name)
        require(raw is not None and len(raw)==expected['bytes'] and hashlib.sha256(raw).hexdigest()==expected['sha256'], 'Toolchain hash drift: '+name)
        if Path(name).suffix.lower() in ('.exe','.dll'): modules[name] = pe_imports(raw)
    for importer, image in modules.items():
        system = Path(system_root)/('SysWOW64' if image['machine']==0x14c and (Path(system_root)/'SysWOW64').is_dir() else 'System32')
        for item in image['imports']:
            fact = dict(importer=importer, kind=item['kind'], name=item['name'], machine=image['machine'])
            if item['name'].lower().startswith(('api-ms-','ext-ms-')):
                fact['classification'] = 'api_set_contract'; facts.append(fact); continue
            providers = []
            for location in (binary/item['name'], system/item['name']):
                raw = reader.read(location)
                if raw is None: continue
                machine = pe_machine(raw)
                providers.append(dict(path=str(location),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),machine=machine,matching_architecture=machine==image['machine']))
            fact.update(providers=providers, classification='matching_file_observed' if any(p['matching_architecture'] for p in providers) else 'not_found_or_wrong_architecture_in_bounded_locations')
            facts.append(fact)
    return dict(toolchain_modules=modules,provider_facts=facts,read_bytes=reader.total,provider_paths=len(reader.paths),
                unresolved_normal_imports=[x for x in facts if x['kind']=='normal' and x['classification']=='not_found_or_wrong_architecture_in_bounded_locations'],
                limit='Bounded file facts, not Windows loader resolution: API sets, KnownDLLs, WinSxS and runtime LoadLibrary are not emulated. Native readiness is not established.')

def write_report(output, report):
    raw = (json.dumps(report,indent=2,sort_keys=True)+'\n').encode()
    require(len(raw) <= EVIDENCE_CAP-65536, 'Audit evidence bound')
    (Path(output)/'audit.json').write_bytes(raw)

def audit(source, work, output):
    began = time.monotonic(); output = Path(output); output.mkdir(parents=True,exist_ok=False)
    report = dict(source=source,status='failed',native_executed=False,native_ready=False,software_installed=False,
                  image=dict(os=os.environ.get('ImageOS'),version=os.environ.get('ImageVersion'),platform=platform.platform()),error=None)
    try:
        admit_source(source,os.environ,os.name)
        pin = json.loads((A.ROOT/'tools/byond/version.json').read_text()); https_url(pin['url'])
        # Per-process HTTPS redirects only; no proxy/credential or machine setting.
        urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({}),OfficialRedirect()))
        manifest = A.acquire(Path(work), pin)
        require(time.monotonic()-began < 220, 'Acquisition left no audit reserve')
        binary = Path((Path(work)/'bin-path.txt').read_text())
        report.update(toolchain=manifest,inventory=collect(binary,manifest,os.environ['SystemRoot'],began+240),status='completed_file_facts')
    except BaseException as error:
        report['error'] = str(error)[:2048]
    finally:
        report['elapsed_seconds'] = time.monotonic()-began
        extract = Path(work)/'extract.log'
        if extract.is_file():
            with extract.open('rb') as stream: raw=stream.read(65537)
            if len(raw)>65536: report.update(status='failed',error='Acquisition diagnostic exceeded evidence bound')
            (output/'extract.log').write_bytes(raw[:65536])
        write_report(output,report)
        require(sum(p.stat().st_size for p in output.iterdir() if p.is_file())<=EVIDENCE_CAP,'Final audit evidence bound')
    return report['status']=='completed_file_facts'

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',required=True);parser.add_argument('--work',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    ok=audit(args.source,args.work,args.output);print(json.dumps(dict(data_only_audit_completed=ok,native_executed=False)));raise SystemExit(0 if ok else 1)
