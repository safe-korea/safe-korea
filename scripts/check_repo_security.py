"""Offline tracked-file/history guard. Report paths only, never secret values.

This complements GitHub secret scanning; it is not a comprehensive secret or
binary/image leak detector. Known local keys are compared only when available.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

PATTERNS = [
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}'),
    re.compile(rb'github_pat_[A-Za-z0-9_]{60,}'),
]


def sensitive_path(name):
    path = Path(name)
    return (path.suffix.lower() in ('.jks', '.keystore', '.p12', '.pfx')
            or path.name in ('.env', 'key.properties')
            or (name.startswith('config/') and path.name.endswith('.local.json')))


def scan(history=False):
    known = []
    for name in ('config/kakao.local.json', 'config/safetydata.local.json'):
        path = Path(name)
        if path.exists():
            for key, value in json.loads(path.read_text()).items():
                if (isinstance(value, str) and len(value) > 12
                        and any(token in key.lower() for token in ('key', 'secret', 'token'))):
                    known.append(value.encode())
    refs = ['--all'] if history else ['HEAD']
    rows = subprocess.check_output(['git', 'rev-list', '--objects', *refs]).decode().splitlines()
    objects = dict(line.split(' ', 1) if ' ' in line else (line, '') for line in rows)
    findings = set()
    count = 0
    with subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE) as process:
        try:
            for oid, name in objects.items():
                process.stdin.write((oid + '\n').encode())
                process.stdin.flush()
                header = process.stdout.readline().decode().split()
                content = process.stdout.read(int(header[-1]))
                process.stdout.read(1)
                if header[1] != 'blob':
                    continue
                count += 1
                if (sensitive_path(name) or any(key in content for key in known)
                        or any(pattern.search(content) for pattern in PATTERNS)):
                    findings.add(name)
        finally:
            process.stdin.close()
            process.stdout.close()
    # Include staged/current files, which may not have reached a commit yet.
    for name in subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0'):
        if not name or not Path(name).is_file():
            continue
        content = Path(name).read_bytes()
        if (sensitive_path(name) or any(key in content for key in known)
                or any(pattern.search(content) for pattern in PATTERNS)):
            findings.add(name)
    print(json.dumps({'history_blobs_scanned': count, 'matching_paths': sorted(findings)}))
    return bool(findings)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true')
    raise SystemExit(scan(parser.parse_args().history))
