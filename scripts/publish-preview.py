#!/usr/bin/env python3
"""Future protected-tag publisher. No application or installer execution here."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from preview_support import version

REPO = 'l0lxl0lw/ai-usage-monitor'


class GitHub:
    def command(self, args, **kwargs):
        return subprocess.run(args, check=True, timeout=120, capture_output=True, **kwargs).stdout

    def api(self, path, missing=False):
        try:
            return json.loads(self.command(['gh', 'api', path]))
        except subprocess.CalledProcessError as error:
            if missing and b'HTTP 404' in error.stderr:
                return None
            raise

    def identity(self, tag, commit, tag_object):
        # Refetch on EVERY guard; checking an old local ref is not a race check.
        self.command(['git', 'fetch', '--no-tags', 'origin', '+refs/heads/main:refs/remotes/origin/main', f'+refs/tags/{tag}:refs/tags/{tag}'])
        actual_object = self.command(['git', 'rev-parse', f'refs/tags/{tag}']).decode().strip()
        peeled = self.command(['git', 'rev-parse', f'refs/tags/{tag}^{{commit}}']).decode().strip()
        if (actual_object, peeled) != (tag_object, commit):
            raise ValueError('tag object/build identity changed')
        self.command(['git', 'merge-base', '--is-ancestor', commit, 'refs/remotes/origin/main'])

    def policies(self):
        # Fetch every inherited ruleset and its FULL detail, never the summary's
        # incomplete enforcement/bypass fields. A full last page terminates only
        # after another page; finite cap fails closed rather than truncating.
        all_rules = []
        seen = set()
        for page in range(1, 11):
            summaries = self.api(f'repos/{REPO}/rulesets?includes_parents=true&per_page=100&page={page}')
            if not isinstance(summaries, list):
                raise ValueError('unreadable inherited rulesets')
            for summary in summaries:
                source, kind, rid = summary.get('source'), summary.get('source_type'), summary.get('id')
                if type(rid) is not int or rid <= 0:
                    raise ValueError('missing policy identity')
                if kind == 'Repository' and source == REPO:
                    endpoint = f'repos/{REPO}/rulesets/{rid}'
                elif kind == 'Organization' and source == REPO.split('/')[0]:
                    endpoint = f'orgs/{source}/rulesets/{rid}'
                else:
                    raise ValueError('unsupported inherited policy source')
                if endpoint in seen:
                    raise ValueError('duplicate/changing inherited policy pages')
                seen.add(endpoint)
                detail = self.api(endpoint)
                if not isinstance(detail, dict) or detail.get('id') != rid:
                    raise ValueError('partial policy detail')
                all_rules.append(detail)
            if len(summaries) < 100:
                return all_rules
        raise ValueError('policy pagination cap')


def protected(rulesets, tag):
    allowed = {'refs/tags/v*-preview.*', f'refs/tags/{tag}', '~ALL'}
    restrictions = set()
    if not isinstance(rulesets, list) or not rulesets:
        raise ValueError('immutable preview-tag policy absent')
    for rule in rulesets:
        if rule.get('target') == 'branch':
            continue
        if rule.get('target') != 'tag':
            raise ValueError('unsupported policy target')
        # Inactive/evaluate rules are not immutable-tag evidence.
        if rule.get('enforcement') != 'active':
            raise ValueError('inactive preview-tag protection')
        if rule.get('bypass_actors') != []:
            raise ValueError('policy bypass/incomplete detail')
        conditions = rule.get('conditions')
        if not isinstance(conditions, dict) or set(conditions) != {'ref_name'}:
            raise ValueError('unsupported policy conditions')
        refs = conditions['ref_name']
        if not isinstance(refs, dict) or set(refs) != {'include', 'exclude'} or refs['exclude'] != []:
            raise ValueError('excluded/incomplete tag protection')
        include = refs['include']
        if not isinstance(include, list) or not include or any(ref not in allowed for ref in include):
            raise ValueError('unsupported tag pattern')
        entries = rule.get('rules')
        if not isinstance(entries, list) or not entries:
            raise ValueError('missing policy rules')
        for entry in entries:
            if not isinstance(entry, dict) or entry.get('type') not in ['update', 'deletion']:
                raise ValueError('unsupported/creation-blocking tag rule')
            # Documented REST update parameter may be present but must not grant
            # an update exception. Missing parameters is the parameterless form.
            if set(entry) != {'type'} and not (entry['type'] == 'update' and set(entry) == {'type', 'parameters'} and entry['parameters'] == {'update_allows_fetch_and_merge': False} and type(entry['parameters']['update_allows_fetch_and_merge']) is bool):
                raise ValueError('unsupported rule parameter/update exception')
            restrictions.add(entry['type'])
    if restrictions != {'update', 'deletion'}:
        raise ValueError('both update and deletion protection required')


def pair(directory, tag):
    name = f'Relay-{tag}-macos-arm64.zip'
    expected = {name, name + '.sha256'}
    if {p.name for p in directory.iterdir()} != expected:
        raise ValueError('exact artifact pair required')
    for file in directory.iterdir():
        if file.is_symlink() or not file.is_file():
            raise ValueError('invalid artifact type')
    archive = directory / name
    if not 22 <= archive.stat().st_size <= 268435456:
        raise ValueError('invalid archive size')
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if (directory / (name+'.sha256')).read_bytes() != f'{digest}  {name}\n'.encode():
        raise ValueError('noncanonical checksum')
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.iterdir()}


def publish(api, tag, commit, tag_object, directory, event, ref):
    version(tag)
    if event != 'push' or ref != 'refs/tags/' + tag:
        raise ValueError('only an explicit preview-tag push may publish')
    if not re.fullmatch('[0-9a-f]{40}', commit) or not re.fullmatch('[0-9a-f]{40}', tag_object):
        raise ValueError('invalid build identity')
    expected = pair(directory, tag)

    def guard():
        api.identity(tag, commit, tag_object)
        protected(api.policies(), tag)

    def verify_release(release):
        if not isinstance(release, dict) or release.get('tag_name') != tag or release.get('target_commitish') != commit or release.get('draft') is not False or release.get('prerelease') is not True:
            raise ValueError('draft/stable/identity mismatch; no overwrite')
        assets = release.get('assets')
        if not isinstance(assets, list) or len(assets) != 2 or {a.get('name') for a in assets} != set(expected):
            raise ValueError('partial/extra assets; no repair or clobber')
        latest = api.api(f'repos/{REPO}/releases/latest', missing=True)
        if latest and latest.get('id') == release.get('id'):
            raise ValueError('preview is latest')
        for asset in assets:
            name = asset['name']
            if type(asset.get('id')) is not int or asset.get('state') != 'uploaded' or asset.get('size') != (directory/name).stat().st_size:
                raise ValueError('incomplete asset')
            content = api.command(['gh', 'api', '-H', 'Accept: application/octet-stream', f'repos/{REPO}/releases/assets/{asset["id"]}'])
            if hashlib.sha256(content).hexdigest() != expected[name]:
                raise ValueError('asset bytes mismatch; rebuilds need not reproduce ZIP bytes')

    guard()
    endpoint = f'repos/{REPO}/releases/tags/{tag}'
    existing = api.api(endpoint, missing=True)
    if existing is not None:
        verify_release(existing)
        guard()  # no-op success is guarded too
        return 'matching complete prerelease; no-op'
    guard()
    # Guard every individual release/asset write, not just the multi-write CLI
    # operation as a whole. Partial results fail closed on the next retry.
    api.command(['gh', 'release', 'create', tag, '--repo', REPO, '--verify-tag', '--prerelease', '--latest=false', '--target', commit, '--title', f'Relay {tag}', '--notes', 'Apple Silicon preview; ad-hoc signed and unnotarized. See README and release gates.'])
    guard()
    for name in sorted(expected):
        guard()
        api.command(['gh', 'release', 'upload', tag, str(directory/name), '--repo', REPO])
        guard()
    verify_release(api.api(endpoint))
    guard()
    return 'created and verified prerelease'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--tag-object', required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    print(publish(GitHub(), args.tag, args.commit, args.tag_object, args.artifacts, os.environ.get('GITHUB_EVENT_NAME'), os.environ.get('GITHUB_REF')))
