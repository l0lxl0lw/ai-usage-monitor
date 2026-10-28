#!/usr/bin/python3
"""Synthetic wire fixtures only. Never contact a source service."""
import json
import os
import sys
import signal
import time

args = sys.argv[1:]
if args == ['hang-after-eof']:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    os.close(1)
    time.sleep(5)
elif args == ['--version']:
    print('codex-cli 0.154.0')
elif args == ['-s', 'read-only', '-a', 'never', 'app-server']:
    # Apple's /usr/bin/python3 shim adds SDK search paths after Process launch.
    assert set(os.environ) <= {'HOME', 'CODEX_HOME', 'PATH', 'TMPDIR', '__CF_USER_TEXT_ENCODING', 'LC_CTYPE', 'CPATH', 'LIBRARY_PATH', 'MANPATH', 'SDKROOT'}
    expected = iter(['initialize', 'initialized', 'account/read', 'account/rateLimits/read'])
    for line in sys.stdin:
        call = json.loads(line)
        assert call['method'] == next(expected)
        method = call['method']
        if method == 'initialized':
            continue
        if method == 'initialize':
            result = {'userAgent': 'synthetic'}
        elif method == 'account/read':
            assert call['params'] == {'refreshToken': False}
            result = {'account': {'type': 'chatgpt', 'email': 'synthetic@example.invalid'}}
        else:
            assert call['params'] == {'excludeResetCreditDetails': True}
            result = {'rateLimits': {'primary': {'usedPercent': 12.25, 'windowDurationMins': 300, 'resetsAt': 1900000000}}}
        print(json.dumps({'id': call['id'], 'result': result}), flush=True)
elif args[:2] == ['worktree', 'ps']:
    assert not any(k.startswith('ORCA_') for k in os.environ)
    print(json.dumps({'ok': True, 'result': {'worktrees': [], 'hostScope': {'hostIds': ['synthetic-host'], 'omittedHostIds': []}, 'truncated': False}, '_meta': {'runtimeId': 'synthetic-runtime'}}))
elif args[:2] == ['orchestration', 'run-list']:
    assert not any(k.startswith('ORCA_') for k in os.environ)
    print(json.dumps({'ok': True, 'result': {'runs': [{'id': 'synthetic-run', 'objective': 'private-canary'}], 'nextCursor': None}}))
elif args[:2] == ['orchestration', 'worker-list']:
    assert args[args.index('--run') + 1] == 'synthetic-run'
    print(json.dumps({'ok': True, 'result': {'workers': [], 'page': {'limit': 100, 'total': 0, 'hasMore': False, 'nextCursor': None}, 'scope': {'source': 'flag'}}}))
else:
    sys.exit(42)
