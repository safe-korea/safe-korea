import 'dart:convert';
import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _read(JSString key);
@JS('window.localStorage.setItem')
external void _write(JSString key, JSString value);
@JS('window.localStorage.removeItem')
external void _remove(JSString key);

const _prefix = 'safekor.local.v1.';
Object? readBrowserRecord(String table) {
  final raw = _read('$_prefix$table'.toJS)?.toDart;
  return raw == null ? null : jsonDecode(raw);
}

// A single localStorage write is atomic. Quota/access failures propagate so the
// existing UI retains its last saved state and never reports false success.
void writeBrowserRecord(String table, Object value) =>
    _write('$_prefix$table'.toJS, jsonEncode(value).toJS);
void removeBrowserRecord(String table) => _remove('$_prefix$table'.toJS);
