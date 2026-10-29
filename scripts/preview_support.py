"""Build/test-side helpers; never downloaded by the stock-shell installer."""
import hashlib
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import tempfile

INSTALLER = Path(__file__).with_name('install-preview.sh')
FILES = ['Contents/Info.plist', 'Contents/MacOS/Relay', 'Contents/MacOS/relay-bridge', 'Contents/_CodeSignature/CodeResources']
DIRS = ['', 'Contents', 'Contents/MacOS', 'Contents/_CodeSignature']


def version(tag):
    match = re.fullmatch(r'v((?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8}))-preview\.([1-9][0-9]{0,8})', tag)
    if not match or len(tag) > 60:
        raise ValueError('invalid preview version')
    return match.groups()


def run(argv, **kwargs):
    return subprocess.run([str(a) for a in argv], check=True, timeout=120, **kwargs)


def embedded(marker):
    return INSTALLER.read_text().split("<<'" + marker + "'\n", 1)[1].split('\n' + marker, 1)[0]


def metadata(archive):
    with tempfile.TemporaryDirectory(prefix='relay-header-') as private:
        js = Path(private) / 'zip.js'
        js.write_text(embedded('ZIP_VALIDATOR'))
        run(['/usr/bin/osascript', '-l', 'JavaScript', js, archive], capture_output=True)


def hashes(app):
    return {name: hashlib.sha256((app / name).read_bytes()).hexdigest() for name in FILES}


def bundle(app, tag, architecture=True):
    core, counter = version(tag)
    if app.name != 'Relay.app' or app.is_symlink():
        raise ValueError('app identity')
    paths = [app, *app.rglob('*')]
    if {str(p.relative_to(app)) for p in paths} != {'.', *FILES, *DIRS[1:]}:
        raise ValueError('bundle inventory')
    for path in paths:
        info = path.lstat()
        relative = str(path.relative_to(app))
        directory = relative == '.' or relative in DIRS
        if not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)):
            raise ValueError('bundle member type')
        if info.st_mode & 0o7022 or (not directory and (info.st_nlink != 1 or info.st_size > 268435456)):
            raise ValueError('bundle member permissions/size/links')
    with (app / FILES[0]).open('rb') as file:
        info = plistlib.load(file)
    for key, expected in dict(CFBundleIdentifier='org.relay.monitor', CFBundleExecutable='Relay', CFBundlePackageType='APPL', CFBundleShortVersionString=core, CFBundleVersion=counter, LSMinimumSystemVersion='14.0', LSUIElement=True).items():
        if type(info.get(key)) is not type(expected) or info[key] != expected:
            raise ValueError('plist mismatch: ' + key)
    if architecture and subprocess.check_output(['/usr/bin/uname', '-m'], text=True).strip() != 'arm64':
        raise ValueError('Apple Silicon build host required')
    for binary in [app / FILES[1], app / FILES[2]]:
        if not binary.stat().st_mode & 0o111:
            raise ValueError('nonexecutable')
        if architecture and subprocess.check_output(['/usr/bin/lipo', '-archs', binary], text=True).strip() != 'arm64':
            raise ValueError('arm64-only executable required')
    for signed in [app / FILES[1], app / FILES[2], app]:
        run(['/usr/bin/codesign', '--verify', '--strict', signed], capture_output=True)
        signature = subprocess.check_output(['/usr/bin/codesign', '-d', '-vv', signed], stderr=subprocess.STDOUT, text=True)
        if '\nSignature=adhoc\n' not in signature or '\nTeamIdentifier=not set\n' not in signature:
            raise ValueError('ad-hoc signature required')
        identity = r'Identifier=relay-bridge-[a-fA-F0-9]+' if signed.name == 'relay-bridge' else 'Identifier=org.relay.monitor'
        if not re.search('^' + identity + '$', signature, re.MULTILINE):
            raise ValueError('signature identity mismatch')
    return hashes(app)
