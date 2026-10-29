#!/usr/bin/env python3
"""Execute the real installer with a private transport boundary, never a live release."""
import argparse
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import zipfile

from preview_support import FILES, INSTALLER, bundle, hashes, run
from preview_test_support import Harness, metadata_suite, mutations, private
from test_preview_publisher import suite as publisher_suite


def extracted(calls):
    return any(c[0]=='ditto' and '-x' in c for c in calls)


def fixtures(data):
    with zipfile.ZipFile(io.BytesIO(data)) as source:
        entries=[(x,source.read(x)) for x in source.infolist()]
    for name in ['absolute','traversal','backslash','control','duplicate','symlink','special','extra','harness','AppleDouble','plist-mismatch']:
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as z:
            for index,(entry,content) in enumerate(entries):
                info=zipfile.ZipInfo(entry.filename);info.create_system=3;info.external_attr=entry.external_attr;info.compress_type=entry.compress_type
                if index==len(entries)-1:
                    rename={'absolute':'/Relay.app/Contents/Info.plist','traversal':'Relay.app/../outside','backslash':'Relay.app\\outside','control':'Relay.app/\x01outside'}
                    info.filename=rename.get(name,info.filename)
                    if name=='symlink': info.external_attr=0xa1ff0000
                    if name=='special': info.external_attr=0x21ff0000
                    if name=='plist-mismatch': content=b'not plist'
                z.writestr(info,content)
            if name in ['extra','harness','AppleDouble','duplicate']:
                z.writestr({'extra':'extra','harness':'Relay.app/NativeHarness','AppleDouble':'__MACOSX/._Relay','duplicate':entries[0][0].filename}[name],b'extra')
        yield name,stream.getvalue()
    # Corrupt compressed payload without changing otherwise valid header metadata.
    b=bytearray(data)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        entry=next(x for x in z.infolist() if x.filename.endswith('Info.plist'))
    import struct
    n,e=struct.unpack_from('<HH',b,entry.header_offset+26)
    b[entry.header_offset+30+n+e+2]^=255
    yield 'payload-crc',bytes(b)


def bootstrap_suite():
    readme=Path('README.md').read_text()
    lines=[line for line in readme.splitlines() if line.startswith('/bin/sh -c ')]
    assert len(lines)==1
    line=lines[0]
    assert 'ulimit -f 1024' in line and '--proto-redir =https' in line and '| sh' not in line
    # Execute exactly the documented quoting/control flow with only curl redirected
    # to a private stand-in. Its old-curl mode ignores all size options.
    for mode in ['success','error','oversize']:
        with private() as d:
            root=Path(d); curl=root/'curl'
            curl.write_text('#!'+os.sys.executable+'\n'+r'''
import os,pathlib,sys
root=pathlib.Path(__file__).parent
out=pathlib.Path(sys.argv[sys.argv.index('--output')+1]);(root/'stage').write_text(str(out.parent))
mode=(root/'mode').read_text()
if mode=='oversize':
 try:
  with out.open('wb') as f:
   for i in range(4): f.write(b'x'*1048576);f.flush()
 except OSError:
  (root/'bound').write_text(str(out.stat().st_size));sys.exit(1)
elif mode=='error': out.write_text('touch NEVER');sys.exit(22)
else: out.write_text('test "$1" = v0.1.0-preview.1 || exit 1\n: > "'+str(root/'executed')+'"\n')
''')
            curl.chmod(0o700);(root/'mode').write_text(mode)
            result=subprocess.run(['/bin/sh','-c',line.replace('/usr/bin/curl',str(curl))],capture_output=True,timeout=20)
            stage=Path((root/'stage').read_text());assert not stage.exists()
            assert (root/'executed').exists()==(mode=='success')
            assert (result.returncode==0)==(mode=='success')
            if mode=='oversize': assert 0<int((root/'bound').read_text())<=1048576
    print('Documented bootstrap: full-download success, HTTP failure/nonexecution, old-curl OS bound and cleanup')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--artifacts',type=Path,required=True);parser.add_argument('--version',required=True)
    args=parser.parse_args()
    # Exact stock-tool inventory: this is deliberately not a recipient framework
    # or dependency bootstrap. New executable paths require deliberate review.
    text=INSTALLER.read_text()
    expected={'sh','osascript','id','mkdir','mktemp','rm','curl','wc','shasum','cmp','grep','unzip','ditto','cp','plutil','codesign','stat','uname','sw_vers'}
    assert set(re.findall(r'/(?:usr/bin|bin)/([a-zA-Z0-9_-]+)',text))==expected
    executable_lines='\n'.join(x for x in text.splitlines() if not x.lstrip().startswith('#'))
    assert not re.search(r'\b(?:python[0-9.]*|ruby|swift|xcrun|lipo|brew|sudo|gh|xattr|launchctl|defaults|eval)\b',executable_lines)
    archive=args.artifacts/f'Relay-{args.version}-macos-arm64.zip';data=archive.read_bytes()
    run(['/bin/sh','-n',INSTALLER])
    metadata_suite(data)
    source=hashes(Path('build/Relay.app'))
    # True stock JXA exclusive rename, metacharacters are argv, never JS source.
    with private() as d:
        root=Path(d);h=Harness(root,data,args.version)
        result,calls=h.run();assert result.returncode==0,(result.stdout,result.stderr)
        final=h.parent/'Relay.app';assert bundle(final,args.version)==source
        before=json.loads((root/'pre.json').read_text())
        assert not os.path.lexists(before['source'])
        assert [final.stat().st_dev,final.stat().st_ino]==before['identity']
        print('REAL promotion device/inode: '+json.dumps(before['identity'])+'; four final hashes: '+json.dumps(hashes(final),sort_keys=True))
        inode=final.stat().st_ino
        result,_=h.run();assert result.returncode!=0 and final.stat().st_ino==inode and hashes(final)==source
        print('REAL install: exact four hashes/signatures, same device/inode, source gone, second install refused; no launch')
    count=0
    # Each raw mutation has a VALID outer SHA256 and traverses the actual shell
    # checksum + JXA path. Every one must stop before even invoking extraction.
    for name,hostile in [*mutations(data),*fixtures(data)]:
        with private() as d:
            h=Harness(Path(d),hostile,args.version);result,calls=h.run()
            assert result.returncode!=0,('accepted hostile',name)
            if name not in ['payload-crc','plist-mismatch']:
                assert not extracted(calls),('extracted hostile metadata',name)
            if name=='payload-crc': assert not extracted(calls),'CRC corruption reached extraction'
            assert not (h.parent/'Relay.app').exists()
            count+=1
    for mode in ['host','os','http','timeout','redirect','partial','oversize','extract-fail','extract-extra','signature','plist','reader-output','reader-stderr','reader-short','reader-timeout']:
        with private() as d:
            h=Harness(Path(d),data,args.version);result,calls=h.run(mode,timeout=50)
            assert result.returncode!=0,mode
            assert not (h.parent/'Relay.app').exists(),mode
            if mode in ['host','os','http','timeout','redirect','partial','oversize','reader-output','reader-stderr','reader-short','reader-timeout']: assert not extracted(calls),mode
            if mode=='oversize': assert 0<json.loads((Path(d)/'os-bound.json').read_text())['size']<=268435456
            count+=1
    for malformed in [b'',b'x'*257,b'A'*64+b'  name\n',b'0'*64+b'  ../bad\n',archive.with_suffix('.zip.sha256').read_bytes()*2,archive.with_suffix('.zip.sha256').read_bytes().upper()]:
        with private() as d:
            h=Harness(Path(d),data,args.version);h.checksum.write_bytes(malformed)
            result,calls=h.run();assert result.returncode!=0 and not extracted(calls)
            count+=1
    # Inject ordinary concurrent creations immediately before the REAL syscall.
    for mode in ['race-directory','race-file','race-symlink','interrupt-before','interrupt-after','syscall','binding','fake-rename','postcondition','posthash','postinventory']:
        with private() as d:
            root=Path(d);h=Harness(root,data,args.version);result,calls=h.run(mode)
            assert result.returncode!=0,mode
            final=h.parent/'Relay.app'
            if mode.startswith('race-'):
                st=final.lstat();assert [st.st_dev,st.st_ino]==json.loads((root/'collision.json').read_text())
                if mode=='race-directory': assert list(p.name for p in final.iterdir())==['sentinel'] and (final/'sentinel').read_text()=='keep'
                if mode=='race-file': assert final.read_text()=='keep'
                if mode=='race-symlink': assert final.is_symlink() and os.readlink(final)=='missing-target'
            elif mode in ['interrupt-after','postcondition','posthash','postinventory']:
                assert hashes(final)==source,'complete app must not be deleted after promotion'
            else: assert not os.path.lexists(final),mode
            count+=1
    for kind in ['directory','file','symlink','unsafe-mode','linked-parent','relative','dot-component','wrong-owner']:
        with private() as d:
            root=Path(d);h=Harness(root,data,args.version);final=h.parent/'Relay.app';parent=h.parent
            if kind=='directory': final.mkdir()
            if kind=='file': final.write_text('keep')
            if kind=='symlink': final.symlink_to('missing')
            if kind=='unsafe-mode': parent.chmod(0o777)
            if kind=='linked-parent':
                link=root/'link';link.symlink_to(parent);parent=link
            if kind=='relative': parent=Path('relative')
            if kind=='dot-component': parent=str(parent)+'/../'+parent.name
            if kind=='wrong-owner': parent=Path('/private') # actual root-owned parent
            result,calls=h.run(parent=parent);assert result.returncode!=0 and not extracted(calls),kind
            count+=1
    for bad in ['v01.0.0-preview.1','v1.0.0-preview.0','v1.0.0-preview.1/../x','v1.0.0-preview.1\n','v1.0.0-preview.$(id)']:
        with private() as d:
            h=Harness(Path(d),data,args.version);result,calls=h.run(tag=bad);assert result.returncode!=0 and not calls
            count+=1
    bootstrap_suite()
    publisher_suite(args.artifacts,args.version)
    assert hashes(Path('build/Relay.app'))==source
    assert count==155,'installer negative case inventory changed or became empty'
    print(f'Installer negative cases: {count}; all nonzero, owned cleanup verified')
    print('PASS preview-install')


if __name__=='__main__': main()
