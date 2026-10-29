#!/usr/bin/env python3
"""Real producer/roundtrip proof plus fail-closed build-side negative cases."""
import argparse
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import shutil
import subprocess
from unittest.mock import patch

from preview_support import bundle, hashes, metadata, run, version
from preview_test_support import metadata_suite, private


def rejected(label, operation):
    try:
        operation()
    except (ValueError, subprocess.CalledProcessError, FileExistsError):
        print('Rejected ' + label)
    else:
        raise AssertionError('accepted ' + label)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    for command in [['/usr/bin/sw_vers'], ['/usr/bin/uname', '-m'], ['xcodebuild', '-version']]:
        run(command)
    for binary in ['Relay', 'relay-bridge']:
        run(['/usr/bin/lipo', '-archs', args.app/'Contents/MacOS'/binary])
    spec = importlib.util.spec_from_file_location('packager', Path(__file__).with_name('package-preview.py'))
    packager = importlib.util.module_from_spec(spec); spec.loader.exec_module(packager)
    original = bundle(args.app, args.version)
    with private() as directory:
        root = Path(directory)
        pair = root / 'pair'
        packager.package(args.app, args.version, pair)
        archive = pair / f'Relay-{args.version}-macos-arm64.zip'
        data = archive.read_bytes()
        assert archive.with_suffix('.zip.sha256').read_bytes() == f'{hashlib.sha256(data).hexdigest()}  {archive.name}\n'.encode()
        metadata_suite(data)
        rejected('output collision', lambda: packager.package(args.app,args.version,pair))
        for bad in ['', 'v01.0.0-preview.1', 'v1.0.0-preview.0', 'v1.0.0-preview.01', 'v1.0.0-preview.1/../x', 'v1.0.0-preview.1\n', 'v1.0.0-preview.$(id)', 'v1000000000.0.0-preview.1']:
            rejected('version '+repr(bad), lambda: version(bad))
        app = root/'Relay.app'
        shutil.copytree(args.app,app)
        for key, value in [('CFBundleIdentifier','bad'),('CFBundleShortVersionString','2.0.0'),('CFBundleVersion','2'),('LSUIElement',False)]:
            p=app/'Contents/Info.plist'; saved=p.read_bytes()
            info=plistlib.loads(saved); info[key]=value; p.write_bytes(plistlib.dumps(info))
            rejected('plist '+key, lambda: bundle(app,args.version)); p.write_bytes(saved)
        for name in ['extra','NativeHarness','.__MACOSX']:
            p=app/name; p.write_text('unshipped')
            rejected(name, lambda: bundle(app,args.version)); p.unlink()
        p=app/'Contents/Info.plist'; saved=p.read_bytes();p.unlink();p.symlink_to('/dev/null')
        rejected('linked source',lambda: bundle(app,args.version));p.unlink();p.write_bytes(saved)
        p=app/'Contents/MacOS/Relay'; saved=p.read_bytes();p.write_bytes(b'not a binary')
        rejected('stale/corrupt binary',lambda: bundle(app,args.version));p.write_bytes(saved)
        # Simulate each actual external architecture response, not the runner label.
        real=subprocess.check_output
        for target in ['host','Relay','relay-bridge']:
            def output(argv, **kwargs):
                if target=='host' and argv[:2]==['/usr/bin/uname','-m']: return 'x86_64\n'
                if target!='host' and argv[:2]==['/usr/bin/lipo','-archs'] and Path(argv[-1]).name==target: return 'x86_64\n'
                return real(argv,**kwargs)
            with patch('preview_support.subprocess.check_output',side_effect=output):
                rejected('architecture '+target,lambda: bundle(app,args.version))
        realrun=packager.run
        for mode in ['ditto-error','ditto-corrupt']:
            def command(argv,**kwargs):
                if argv[0]=='/usr/bin/ditto' and '-c' in argv:
                    if mode=='ditto-error': raise subprocess.CalledProcessError(1,argv)
                    Path(argv[-1]).write_bytes(b'bad');return
                return realrun(argv,**kwargs)
            with patch.object(packager,'run',side_effect=command):
                rejected(mode,lambda:packager.package(args.app,args.version,root/mode))
            assert not (root/mode).exists()
        assert not list(root.glob('.relay-package-*'))
    assert hashes(args.app)==original
    # Repeated verification may replace ONLY this check's exact known pair.
    if args.output.exists():
        expected={f'Relay-{args.version}-macos-arm64.zip',f'Relay-{args.version}-macos-arm64.zip.sha256'}
        assert not args.output.is_symlink() and {p.name for p in args.output.iterdir()}==expected
        for p in args.output.iterdir():
            assert p.is_file() and not p.is_symlink()
        metadata(args.output/f'Relay-{args.version}-macos-arm64.zip')
        for p in args.output.iterdir(): p.unlink()
        args.output.rmdir()
    packager.package(args.app,args.version,args.output)
    print('PASS preview-zip')


if __name__=='__main__':
    main()
