#!/usr/bin/env python3
"""Package an audited existing app. Refuses output reuse; never builds or signs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile

from preview_support import bundle, metadata, run, version


def package(app, tag, output):
    version(tag)
    app = app.absolute()
    output = output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('output already exists')
    original = bundle(app, tag)
    run(['python3', 'scripts/check.py', 'bundle', app])
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.relay-package-', dir=output.parent) as private:
        stage = Path(private)
        pair = stage / 'pair'
        pair.mkdir()
        archive = pair / f'Relay-{tag}-macos-arm64.zip'
        run(['/usr/bin/ditto', '-c', '-k', '--norsrc', '--keepParent', app, archive])
        metadata(archive)
        with zipfile.ZipFile(archive) as inspected:
            for member in inspected.infolist():
                print(f'ZIP member {member.filename}: flags={member.flag_bits} method={member.compress_type} mode={oct(member.external_attr >> 16)} compressed={member.compress_size} size={member.file_size}')
        run(['/usr/bin/unzip', '-t', archive], capture_output=True)
        extracted = stage / 'extracted'
        extracted.mkdir()
        run(['/usr/bin/ditto', '-x', '-k', archive, extracted])
        if bundle(extracted / 'Relay.app', tag) != original:
            raise ValueError('roundtrip bytes changed')
        if bundle(app, tag) != original:
            raise ValueError('source changed')
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
        # Output is developer-owned, not the recipient's exclusive app destination.
        # mkdir claims it without ever replacing another directory or symlink.
        output.mkdir()
        for file in pair.iterdir():
            os.rename(file, output / file.name)
    print(f'Packaged {archive.name}: {digest}')
    print('Roundtrip source/extracted file SHA256: ' + json.dumps(original, sort_keys=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.app, args.version, args.output)
