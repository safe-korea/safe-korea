"""Create an atomic offline asset list for a root/subdirectory Flutter web build."""
import hashlib
import json
from pathlib import Path


def prepare(root=Path('build/web')):
    # Exclude build metadata and source template from offline payload.
    ignored = {'safe-worker.js', 'safe-worker.template.js', 'flutter_service_worker.js',
               'version.json', '.last_build_id'}
    files = sorted(p for p in root.rglob('*') if p.is_file() and
                   p.name not in ignored and not p.name.endswith(('.map', '.symbols')) and
                   ('canvaskit' not in p.relative_to(root).parts or
                    p.relative_to(root).as_posix() in ['canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm']))
    digest = hashlib.sha256()
    for p in files:
        digest.update(p.relative_to(root).as_posix().encode())
        digest.update(p.read_bytes())
    template = Path('web/safe-worker.template.js').read_text()
    worker = template.replace('__VERSION__', digest.hexdigest()[:20]).replace(
        '__FILES__', json.dumps({p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}))
    (root / 'safe-worker.js').write_text(worker)
    print(f'Offline allowlist: {len(files)} files, {sum(p.stat().st_size for p in files)/1024/1024:.1f} MiB')


if __name__ == '__main__':
    prepare()
