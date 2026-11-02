"""Local, opt-in review ledger. Stores hashes, never delivers alerts."""
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat


class ReviewStoreError(Exception):
    pass


def record_batch(path, rows):
    """Atomically classify a batch across restarts; no source text is persisted.

    Hashes are comparison identifiers, NOT a guarantee of anonymization.
    Different SQLite files do not share deduplication state.
    """
    pairs = []
    for row in rows:
        serial = row.get('SN') if isinstance(row, dict) else None
        if isinstance(serial, bool) or not isinstance(serial, (str, int)) or not str(serial).strip():
            raise ReviewStoreError('invalid_record')
        identity = hashlib.sha256(str(serial).strip().encode()).hexdigest()
        try:
            payload = json.dumps(row, sort_keys=True, ensure_ascii=False, allow_nan=False)
        except (TypeError, ValueError):
            raise ReviewStoreError('invalid_record') from None
        pairs.append((identity, hashlib.sha256(payload.encode()).hexdigest()))
    connection = None
    try:
        path = Path(path)
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            os.close(fd)
        except FileExistsError:
            pass
        mode = path.lstat().st_mode
        if not stat.S_ISREG(mode) or mode & 0o077:
            raise ReviewStoreError('private_regular_file_required')
        connection = sqlite3.connect(path, timeout=5)
        connection.execute('BEGIN IMMEDIATE')
        version = connection.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0, 1):
            raise ReviewStoreError('unsupported_store_version')
        tables = {r[0] for r in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if version == 0:
            if tables:
                raise ReviewStoreError('unrecognized_store')
            connection.execute('CREATE TABLE reviewed_versions (identity TEXT NOT NULL, fingerprint TEXT NOT NULL, PRIMARY KEY(identity, fingerprint))')
            connection.execute('PRAGMA user_version = 1')
        elif tables != {'reviewed_versions'}:
            raise ReviewStoreError('unrecognized_store')
        counts = Counter()
        for identity, fingerprint in pairs:
            duplicate = connection.execute('SELECT 1 FROM reviewed_versions WHERE identity=? AND fingerprint=?',
                                           (identity, fingerprint)).fetchone()
            known = connection.execute('SELECT 1 FROM reviewed_versions WHERE identity=? LIMIT 1', (identity,)).fetchone()
            counts['duplicate' if duplicate else 'revision_review' if known else 'first_seen_review'] += 1
            connection.execute('INSERT OR IGNORE INTO reviewed_versions VALUES (?, ?)', (identity, fingerprint))
        connection.commit()
        return {'mode': 'persistent_local_review_only', 'record_counts': dict(sorted(counts.items())),
                'notification_eligible_count': 0}
    except (OSError, sqlite3.Error):
        raise ReviewStoreError('store_unavailable') from None
    finally:
        if connection is not None:
            connection.close()  # Rolls back any incomplete transaction.
