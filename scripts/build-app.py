#!/usr/bin/env python3
"""Build a locally ad-hoc-signed bundle; not a distributable/notarized release."""
import argparse
import pathlib
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--configuration', choices=['debug', 'release'], default='release')
p.add_argument('--output', type=pathlib.Path, default=pathlib.Path('build/Relay.app'))
args = p.parse_args()
for product in ['Relay', 'relay-bridge']:
    subprocess.run(['swift', 'build', '-c', args.configuration, '--product', product], check=True)
binary_dir = pathlib.Path(subprocess.check_output(['swift', 'build', '-c', args.configuration, '--show-bin-path'], text=True).strip())
macos = args.output / 'Contents/MacOS'
macos.mkdir(parents=True, exist_ok=True)
shutil.copy2('Resources/Info.plist', args.output / 'Contents/Info.plist')
for name in ['Relay', 'relay-bridge']:
    shutil.copy2(binary_dir / name, macos / name)
    subprocess.run(['codesign', '--force', '--sign', '-', str(macos / name)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(args.output)], check=True)
print('Built local Relay bundle (ad-hoc only)')
