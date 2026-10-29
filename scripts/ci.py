#!/usr/bin/env python3
"""Run exactly the approved repository manifest, with fail-closed markers."""
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
manifest = json.loads((root / '.opencode/workflow/checks.json').read_text())
for check in manifest['checks']:
    result = subprocess.run(check['argv'], cwd=root / check.get('cwd', '.'),
                            timeout=check.get('timeout_seconds', 1800),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='', flush=True)
    if result.returncode or (check['format'] == 'script' and not re.search(check['success_pattern'], result.stdout, re.M)):
        raise SystemExit('FAIL ' + check['id'])
print('PASS manifest')
