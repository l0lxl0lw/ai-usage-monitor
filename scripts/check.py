#!/usr/bin/env python3
"""Fail-closed XCTest evidence validation. No marker is emitted for missing proof."""
import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

INVENTORY = pathlib.Path(__file__).with_name('test-inventory.json')


def validate(report, group, expected):
    root = ET.parse(report).getroot()
    cases = list(root.iter('testcase'))
    if not cases:
        raise ValueError('empty XCTest evidence')
    found = []
    for case in cases:
        classname = case.get('classname', '').split('.')[-1]
        name = case.get('name', '')
        if classname != group or not name or case.find('skipped') is not None or case.find('failure') is not None or case.find('error') is not None:
            raise ValueError('foreign, skipped or failed testcase')
        found.append(name)
    if len(found) != len(set(found)) or set(found) != set(expected):
        raise ValueError('duplicate, missing or unexpected testcase inventory')
    for suite in root.iter('testsuite'):
        for field in ['failures', 'errors', 'skipped']:
            if int(suite.get(field, '0')) != 0:
                raise ValueError('suite contains failures or skips')


def main():
    mode = sys.argv[1]
    if mode == 'tests':
        group = sys.argv[2]
        inventory = json.loads(INVENTORY.read_text())
        expected = inventory[group]
        if not expected or len(expected) != len(set(expected)):
            raise ValueError('invalid committed expected inventory')
        with tempfile.TemporaryDirectory(prefix='relay-xctest-') as private:
            report = pathlib.Path(private) / 'results.xml'
            # SwiftPM emits XCTest xUnit only through its parallel test runner.
            # One worker keeps environment-sensitive transport tests isolated.
            subprocess.run(['swift', 'test', '--parallel', '--num-workers', '1', '--filter', group, '--xunit-output', str(report)], check=True)
            validate(report, group, expected)
        print('PASS ' + group)
    elif mode == 'bundle':
        bundle = pathlib.Path(sys.argv[2])
        with (bundle / 'Contents/Info.plist').open('rb') as file:
            info = plistlib.load(file)
        assert info['LSUIElement'] is True and info['LSMinimumSystemVersion'] == '14.0'
        assert info['CFBundleExecutable'] == 'Relay'
        # Positive target/source inventory: fixture and harness targets cannot be
        # dependencies of the shipped executables (even transitively).
        package = json.loads(subprocess.check_output(['swift', 'package', 'describe', '--type', 'json'], text=True))
        targets = {target['name']: target for target in package['targets']}
        expected = {
            'MonitorApp': ('Sources/Relay', ['Relay.swift'], ['MonitorPresentation']),
            'MonitorPresentation': ('Sources/MonitorApp', ['AppServices.swift', 'PopoverController.swift', 'PopoverRoot.swift', 'ScrollMemory.swift', 'SettingsViews.swift'], ['MonitorAdapters', 'MonitorCore']),
            'MonitorBridge': ('Sources/MonitorBridge', ['main.swift'], ['MonitorAdapters']),
            'MonitorCore': ('Sources/MonitorCore', ['Models.swift', 'MonitorStore.swift', 'NavigationState.swift', 'PrivacyProjection.swift'], []),
            'MonitorAdapters': ('Sources/MonitorAdapters', ['ClaudeAdapter.swift', 'CodexAdapter.swift', 'HookBridgeTransport.swift', 'OpenCodeAdapter.swift', 'OrcaAdapter.swift', 'ProfileRegistry.swift', 'TransportPolicy.swift'], ['MonitorCore'])
        }
        for name, (path, sources, dependencies) in expected.items():
            target = targets[name]
            assert target['path'] == path and sorted(target['sources']) == sorted(sources), name
            assert sorted(target.get('target_dependencies', [])) == sorted(dependencies), name
            assert not target.get('product_dependencies'), name
            assert not target.get('resources'), name
        for source in pathlib.Path('Sources').rglob('*.swift'):
            text = source.read_text()
            for forbidden in ['DemoFixtures', 'SyntheticFixtures', 'NativeHarness', 'changeMode', 'Observation mode', '--demo', '--sample', 'Build menu-bar monitor']:
                assert forbidden not in text, (source, forbidden)
        actual = {str(path.relative_to(bundle)) for path in bundle.rglob('*') if path.is_file()}
        assert actual == {'Contents/Info.plist', 'Contents/MacOS/Relay', 'Contents/MacOS/relay-bridge', 'Contents/_CodeSignature/CodeResources'}, actual
        for name in ['Relay', 'relay-bridge']:
            binary = bundle / 'Contents/MacOS' / name
            assert binary.is_file() and binary.stat().st_mode & 0o111
            subprocess.run(['codesign', '--verify', str(binary)], check=True)
            load = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(binary)], text=True)
            assert 'minos 14.0' in load, 'wrong deployment target'
            strings = subprocess.check_output(['strings', str(binary)], text=True)
            for canary in ['SyntheticFixtures', 'NativeHarness', 'Synthetic frozen sample', 'Build menu-bar monitor', 'Observation mode', '--demo', '--sample']:
                assert canary not in strings, (name, canary)
        assert not list(bundle.rglob('*.html'))
        print('PASS bundle')
    elif mode == 'mock':
        for file in ['mock/app.js', 'mock/data.js']:
            subprocess.run(['node', '--check', file], check=True)
        print('PASS mock-static')
    else:
        raise ValueError('unknown check')


if __name__ == '__main__':
    main()
