"""Install only this user's managed collector schedule; preserve all other jobs."""
from pathlib import Path
import os
import shlex
import subprocess

START = '# BEGIN SAFEKOR ALERT COLLECTOR'
END = '# END SAFEKOR ALERT COLLECTOR'


def managed_cron(existing, folder):
    if existing.count(START) != existing.count(END) or existing.count(START) > 1:
        raise ValueError('invalid_managed_block')
    if START in existing:
        before, rest = existing.split(START)
        _, after = rest.split(END)
        existing = before + after.lstrip('\n')
    command = ('umask 077; /usr/bin/python3 '
               + shlex.quote(str(folder / 'collector.py')) + ' --config '
               + shlex.quote(str(folder / 'gov-probe.local.json')) + ' > '
               + shlex.quote(str(folder / 'last-run.json')) + ' 2>&1')
    return existing.rstrip('\n') + ('\n' if existing.strip() else '') + START + '\n*/2 * * * * ' + command + '\n' + END + '\n'


def main():
    os.umask(0o077)
    folder = Path.home() / '.local/share/safekor-alert-collector'
    if not (folder / 'DEPLOYED_BY_SAFEKOR').is_file():
        raise ValueError('missing_ownership_marker')
    current = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
    if current.returncode and 'no crontab' not in current.stderr.lower():
        raise ValueError('cannot_read_crontab')
    original = current.stdout
    updated = managed_cron(original, folder)
    if original == updated:
        print('collector_schedule_unchanged')
        return
    backup = folder / 'crontab.before-safekor.txt'
    if not backup.exists():
        backup.write_text(original)
        backup.chmod(0o600)
    subprocess.run(['crontab', '-'], input=updated, text=True, check=True, capture_output=True)
    print('collector_schedule_installed')


if __name__ == '__main__':
    main()
