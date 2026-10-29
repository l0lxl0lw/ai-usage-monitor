"""Private transport/tool boundary instrumentation, never a production option."""
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import struct
import subprocess
import sys
import tempfile
import zipfile

from preview_support import INSTALLER, embedded, metadata

WRAPPER = r'''#!PYTHON
import json,os,pathlib,shutil,signal,subprocess,sys,time,tempfile
root=pathlib.Path(__file__).parent
cfg=json.loads((root/'config.json').read_text())
tool=sys.argv[0].split('/')[-1]; args=sys.argv[1:]
with tempfile.NamedTemporaryFile(mode='w',prefix='call-',dir=root,delete=False) as f: f.write(json.dumps([tool,*[x.replace(str(root),'.') for x in args]])+'\n')
mode=cfg.get('mode','')
if tool=='curl':
 out=pathlib.Path(args[args.index('--output')+1]); url=args[-1]
 if mode in ['http','timeout','redirect','partial']:
  out.write_bytes(b'partial'); sys.exit(28 if mode=='timeout' else 22)
 if mode=='oversize':
  try:
   with out.open('wb') as f:
    for i in range(2048): f.write(b'x'*1048576); f.flush()
  except OSError:
   (root/'os-bound.json').write_text(json.dumps({'size':out.stat().st_size}))
   sys.exit(1)
  sys.exit(0)
 source=cfg['checksum'] if url.endswith('.sha256') else cfg['archive']
 shutil.copyfile(source,out); sys.exit(0)
if tool=='uname' and mode=='host': print('x86_64'); sys.exit(0)
if tool=='sw_vers' and mode=='os': print('13.0'); sys.exit(0)
if tool=='ditto' and mode=='extract-fail': sys.exit(1)
if tool=='ditto' and mode=='extract-extra':
 subprocess.run(['/usr/bin/ditto',*args],check=True)
 (pathlib.Path(args[-1])/'Relay.app'/'extra').write_text('bad'); sys.exit(0)
if tool=='codesign' and mode=='signature': sys.exit(1)
if tool=='plutil' and mode=='plist': print('wrong'); sys.exit(0)
if tool=='stat' and mode=='postcondition' and args[-1].endswith('/Relay.app') and '.relay-install.' not in args[-1]: print('0:0'); sys.exit(0)
if tool=='shasum' and mode=='posthash' and os.getcwd().endswith('/Relay.app') and '.relay-install.' not in os.getcwd(): print('0'*64+'  mismatch'); sys.exit(0)
if tool=='osascript' and mode=='postinventory' and len(args)>2 and args[2].endswith('/inventory.js') and '.relay-install.' not in args[-1]: print('[]'); sys.exit(0)
if tool=='osascript' and len(args)>2 and args[2].endswith('/zip.js'):
 if mode=='reader-timeout': time.sleep(40)
 if mode in ['reader-output','reader-stderr']:
  for i in range(100): os.write(1 if mode=='reader-output' else 2,b'x'*1024)
  sys.exit(0)
 if mode=='reader-short':
  p=pathlib.Path(args[2]);p.write_text(p.read_text().replace('h.readDataOfLength(n)','h.readDataOfLength(n-1)'))
if tool=='osascript' and len(args)>2 and args[2].endswith('/promote.js'):
 src,dst=map(pathlib.Path,args[-2:]); st=src.stat()
 (root/'pre.json').write_text(json.dumps({'source':str(src),'identity':[st.st_dev,st.st_ino]}))
 if mode.startswith('race-'):
  if mode=='race-directory': dst.mkdir(); (dst/'sentinel').write_text('keep')
  elif mode=='race-file': dst.write_text('keep')
  elif mode=='race-symlink': dst.symlink_to('missing-target')
  s=dst.lstat(); (root/'collision.json').write_text(json.dumps([s.st_dev,s.st_ino]))
 if mode=='interrupt-before': os.kill(int(os.environ['INSTALLER_PID']),signal.SIGTERM); time.sleep(.2); sys.exit(1)
 if mode=='syscall': sys.exit(1)
 if mode=='fake-rename': sys.exit(0)
 if mode=='binding': args[2]=str(root/'bad-binding.js')
 if mode=='interrupt-after':
  subprocess.run(['/usr/bin/osascript',*args],check=True)
  os.kill(int(os.environ['INSTALLER_PID']),signal.SIGTERM); time.sleep(.2); sys.exit(1)
real='/usr/bin/'+tool
os.execv(real,[real,*args])
'''


class Harness:
    def __init__(self, root, archive, tag):
        self.root = root
        self.tag = tag
        self.archive = root / f'Relay-{tag}-macos-arm64.zip'
        self.archive.write_bytes(archive)
        self.checksum = root / 'checksum'
        self.set_archive(archive)
        self.parent = root / 'Applications space \' quote ; $() \\ backslash'
        self.parent.mkdir(mode=0o700)
        self.calls = root / 'calls'
        self.script = root / 'installer.sh'
        text = INSTALLER.read_text()
        for tool in ['curl', 'ditto', 'osascript', 'uname', 'sw_vers', 'codesign', 'plutil', 'stat', 'shasum']:
            wrapper = root / tool
            wrapper.write_text(WRAPPER.replace('PYTHON', sys.executable, 1))
            wrapper.chmod(0o700)
            text = text.replace('/usr/bin/' + tool, str(wrapper))
        self.script.write_text(text)
        (root / 'bad-binding.js').write_text("ObjC.bindFunction('nonexistent_relay_syscall',['int',[]]); function run(a) { $.nonexistent_relay_syscall(); }")

    def set_archive(self, data):
        self.archive.write_bytes(data)
        self.checksum.write_text(f'{hashlib.sha256(data).hexdigest()}  {self.archive.name}\n')

    def run(self, mode='', tag=None, parent=None, timeout=60):
        (self.root / 'config.json').write_text(json.dumps(dict(mode=mode, archive=str(self.archive), checksum=str(self.checksum))))
        # exec preserves the shell PID for real signal injection at promotion.
        command = 'export INSTALLER_PID=$$; exec /bin/sh "$1" "$2" "$3"'
        result = subprocess.run(['/bin/sh', '-c', command, 'test', str(self.script), tag or self.tag, str(parent or self.parent)], capture_output=True, timeout=timeout)
        calls = [json.loads(p.read_text()) for p in self.root.glob('call-*')]
        assert not list(self.parent.glob('.relay-install.*')), 'owned staging leaked'
        return result, calls


def private():
    # /var is a macOS symlink; production deliberately rejects linked components.
    return tempfile.TemporaryDirectory(prefix='relay-proof-', dir=str(Path(tempfile.gettempdir()).resolve()))


def mutations(data):
    """Deterministic raw-header mutations; outer checksum is recomputed by Harness."""
    with zipfile.ZipFile(__import__('io').BytesIO(data)) as z:
        entries = z.infolist()
    central = data.rfind(b'PK\x05\x06')
    co = struct.unpack_from('<I', data, central + 16)[0]
    positions = []; p = co
    for entry in entries:
        positions.append((p, entry.header_offset, entry))
        n, e, c = struct.unpack_from('<HHH', data, p + 28)
        p += 46 + n + e + c

    def changed(name, patches):
        b = bytearray(data)
        for off, fmt, value in patches:
            struct.pack_into(fmt, b, off, value)
        return name, bytes(b)

    c, l, entry = next(x for x in positions if not x[2].is_dir())
    for bit in range(16):
        if bit in [3, 11]:
            continue
        for where in ['local', 'central', 'both']:
            patches = []
            if where in ['local', 'both']: patches.append((l+6, '<H', entry.flag_bits | (1<<bit)))
            if where in ['central', 'both']: patches.append((c+8, '<H', entry.flag_bits | (1<<bit)))
            yield changed(f'unsupported-flag-{bit}-{where}', patches)
    for field, offset, fmt, value in [('signature',0,'<I',0),('disk',4,'<H',1),('other-disk',6,'<H',1),('disk-count',8,'<H',7),('count',10,'<H',9),('zip64-count',10,'<H',65535),('size',12,'<I',65537),('offset',16,'<I',0xffffffff),('comment',20,'<H',1)]:
        yield changed('eocd-'+field, [(central+offset,fmt,value)])
    yield 'trailing', data+b'x'
    yield 'truncated', data[:-1]
    yield 'empty', b''
    for name, off, fmt, value in [
        ('central-signature',c,'<I',0), ('local-signature',l,'<I',0),
        ('central-version',c+6,'<H',45), ('local-version',l+4,'<H',45),
        ('central-method',c+10,'<H',99), ('local-method',l+8,'<H',99),
        ('central-crc',c+16,'<I',0), ('central-size',c+24,'<I',268435457),
        ('compressed-size',c+20,'<I',0xffffffff), ('ratio',c+20,'<I',1),
        ('local-crc',l+14,'<I',1), ('local-size',l+22,'<I',1), ('local-compressed',l+18,'<I',1),
        ('central-namelen',c+28,'<H',129), ('local-namelen',l+26,'<H',1),
        ('central-extra-length',c+30,'<H',4097), ('local-extra-length',l+28,'<H',4097),
        ('comment',c+32,'<H',1), ('disk',c+34,'<H',1), ('internal-attributes',c+36,'<H',1),
        ('symlink',c+38,'<I',0xa1ff0000), ('special',c+38,'<I',0x21ff0000),
        ('setuid',c+38,'<I',0x89ed0000), ('overlap',c+42,'<I',0), ('gap',c+42,'<I',l+1),
        ('name-byte',c+46,'<B',47), ('local-name-byte',l+30,'<B',92)]:
        yield changed(name, [(off,fmt,value)])
    nl, el = struct.unpack_from('<HH', data, l+26)
    desc = l+30+nl+el+entry.compress_size
    for off in [0,4,8,12]:
        yield changed('descriptor-'+str(off), [(desc+off,'<I',0)])
    for record, off, n in [('central', c+46+len(entry.filename),8),('local',l+30+nl,12)]:
        yield changed(record+'-unknown-extra', [(off,'<H',0x9999)])
        yield changed(record+'-zip64-extra', [(off,'<H',1)])
        yield changed(record+'-extra-shape', [(off+2,'<H',n-1)])
    yield changed('local-central-extra-value',[(l+30+nl+4,'<I',0)])
    yield changed('utf8-flag-disagreement',[(l+6,'<H',entry.flag_bits|0x800)])
    yield changed('descriptor-flag-disagreement',[(l+6,'<H',0)])
    yield changed('version-made-unknown',[(c+4,'<H',0x031e)])
    yield changed('local-offset-outside',[(c+42,'<I',0xffffffff)])
    for label, inserted in [('unsigned-descriptor',-4),('zip64-descriptor',8)]:
        b=bytearray(data)
        if inserted<0: del b[desc:desc+4]
        else: b[desc+16:desc+16]=b'\0'*8
        # Preserve an otherwise well-placed EOCD to reach descriptor/range checks.
        struct.pack_into('<I',b,len(b)-6,co+inserted)
        yield label,bytes(b)


def boundary_suite(root):
    """Sparse metadata-only fixtures prove caps without allocating/decompressing bombs.

    Header acceptance here is not CRC or app acceptance; stock integrity testing
    remains mandatory afterward. Reader call/aggregate caps are defensive: exact
    eight records and name/extra limits imply each request <=4096 and aggregate
    <=69142, strictly below 65536/262144. They cannot be reached by valid structure.
    """
    names=['Relay.app/','Relay.app/Contents/','Relay.app/Contents/MacOS/','Relay.app/Contents/_CodeSignature/','Relay.app/Contents/Info.plist','Relay.app/Contents/MacOS/Relay','Relay.app/Contents/MacOS/relay-bridge','Relay.app/Contents/_CodeSignature/CodeResources']
    file=root/'sparse.zip'

    def make(plains, compressed=None, archive_size=None):
        sizes=compressed if compressed is not None else [math.ceil(x/200) for x in plains]
        # Every payload region is sparse. Local/central headers are real bytes.
        def write(sizes):
            central=[]
            with file.open('wb') as f:
                for i,name in enumerate(names):
                    raw=name.encode();isdir=i<4;plain=0 if isdir else plains[i-4];comp=0 if isdir else sizes[i-4]
                    offset=f.tell();method=0 if isdir else 8
                    f.write(struct.pack('<IHHHHHIIIHH',0x04034b50,20,0,method,0,0,0,comp,plain,len(raw),0)+raw)
                    f.seek(comp,1)
                    mode=0o40755 if isdir else 0o100644
                    central.append(struct.pack('<IHHHHHHIIIHHHHHII',0x02014b50,0x0314,20,0,method,0,0,0,comp,plain,len(raw),0,0,0,0,mode<<16,offset)+raw)
                co=f.tell();cd=b''.join(central);f.write(cd)
                f.write(struct.pack('<IHHHHIIH',0x06054b50,0,0,8,8,len(cd),co,0))
        if archive_size:
            write([0]*4);overhead=file.stat().st_size
            sizes=[archive_size-overhead,0,0,0];plains[:]=sizes
        write(sizes)

    cases=[('per-file-at-cap',[268435456,0,0,0],True),('per-file-over-cap',[268435457,0,0,0],False),('total-at-cap',[268435456,268435456,0,0],True),('total-over-cap',[268435456,268435456,1,0],False)]
    for name,plains,accepted in cases:
        make(plains)
        try: metadata(file)
        except subprocess.CalledProcessError:
            assert not accepted,name
        else: assert accepted,name
    for plain,accepted in [(20000,True),(20001,False)]:
        make([plain,0,0,0],[100,0,0,0])
        try: metadata(file)
        except subprocess.CalledProcessError: assert not accepted
        else: assert accepted
    for size,accepted in [(268435456,True),(268435457,False)]:
        make([0,0,0,0],archive_size=size)
        assert file.stat().st_size==size
        try: metadata(file)
        except subprocess.CalledProcessError: assert not accepted,('archive cap',size)
        else: assert accepted
    print('Sparse raw metadata caps: file/total/ratio/archive exact limits and +1; reader caps structurally dominated')


def metadata_suite(data):
    with private() as directory:
        root = Path(directory)
        file = root / 'fixture.zip'
        file.write_bytes(data)
        metadata(file)  # real producer form must pass FIRST
        utf=bytearray(data)
        with zipfile.ZipFile(file) as producer:
            cs=struct.unpack_from('<I',utf,len(utf)-6)[0]
            for entry in producer.infolist():
                struct.pack_into('<H',utf,entry.header_offset+6,entry.flag_bits|0x800)
                struct.pack_into('<H',utf,cs+8,entry.flag_bits|0x800)
                n,e,c=struct.unpack_from('<HHH',utf,cs+28);cs+=46+n+e+c
        file.write_bytes(utf);metadata(file)
        boundary_suite(root)
        count = 0
        for name, hostile in mutations(data):
            file.write_bytes(hostile)
            try:
                metadata(file)
            except subprocess.CalledProcessError:
                count += 1
            else:
                raise AssertionError('accepted hostile metadata: ' + name)
        assert count == 98, 'metadata case inventory changed or became empty'
        # Exercise accepted stored/deflated, descriptors absent, optional UTF8.
        with zipfile.ZipFile(__import__('io').BytesIO(data)) as original:
            for method in [zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED]:
                with zipfile.ZipFile(file, 'w', compression=method) as z:
                    for entry in original.infolist():
                        info = zipfile.ZipInfo(entry.filename)
                        info.create_system = 3
                        info.external_attr = entry.external_attr
                        info.compress_type = method if not entry.is_dir() else zipfile.ZIP_STORED
                        z.writestr(info, original.read(entry))
                metadata(file)
                utf = bytearray(file.read_bytes())
                with zipfile.ZipFile(file) as z:
                    cs = struct.unpack_from('<I', utf, len(utf)-6)[0]
                    for entry in z.infolist():
                        struct.pack_into('<H', utf, entry.header_offset+6, 0x800)
                        struct.pack_into('<H', utf, cs+8, 0x800)
                        n,e,c = struct.unpack_from('<HHH',utf,cs+28); cs+=46+n+e+c
                file.write_bytes(utf); metadata(file)
    print(f'Raw production JXA: {count} hostile metadata cases, 6 producer/encoding/method positives')
