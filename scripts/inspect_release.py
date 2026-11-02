"""Inspect local release outputs; never signs, uploads, or declares store readiness."""
import argparse
import json
import plistlib
import struct
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


def elf_load_alignment(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected ELF64 little-endian shared library')
    offset = struct.unpack_from('<Q', data, 32)[0]
    size, count = struct.unpack_from('<HH', data, 54)
    result = []
    for i in range(count):
        pos = offset + i * size
        if struct.unpack_from('<I', data, pos)[0] != 1:
            continue
        file_offset, virtual = struct.unpack_from('<QQ', data, pos + 8)
        alignment = struct.unpack_from('<Q', data, pos + 48)[0]
        result.append({'alignment': alignment,
                       'compatible_16kb': alignment >= 16384 and
                       file_offset % 16384 == virtual % 16384})
    if not result:
        raise ValueError('No LOAD segments')
    return result


def inspect(aab, ios_app):
    report = {'scope': 'Local artifact inspection; not store approval',
              'aab_present': aab.is_file(), 'ios_app_present': ios_app.is_dir()}
    manifest = Path('build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml')
    if manifest.is_file():
        root = ET.parse(manifest).getroot()
        ns = '{http://schemas.android.com/apk/res/android}'
        sdk, app = root.find('uses-sdk'), root.find('application')
        report['android'] = {
            'package': root.get('package'),
            'min_sdk': sdk.get(ns + 'minSdkVersion'),
            'target_sdk': sdk.get(ns + 'targetSdkVersion'),
            'debuggable': app.get(ns + 'debuggable', 'false'),
            'allow_backup': app.get(ns + 'allowBackup'),
            'permissions': sorted(p.get(ns + 'name') for p in root.findall('uses-permission'))}
    if aab.is_file():
        with zipfile.ZipFile(aab) as bundle:
            report['aab_signature_entries'] = [n for n in bundle.namelist()
                if n.startswith('META-INF/') and n.upper().endswith(('.RSA', '.DSA', '.EC'))]
            report['native_libraries'] = []
            for name in bundle.namelist():
                if not name.endswith('.so') or not any('/' + abi + '/' in name for abi in ['arm64-v8a','x86_64']):
                    continue
                try:
                    segments = elf_load_alignment(bundle.read(name))
                    report['native_libraries'].append({'name': name, 'segments': segments,
                        'compatible_16kb': all(s['compatible_16kb'] for s in segments)})
                except (ValueError, struct.error) as error:
                    report['native_libraries'].append({'name':name, 'error':str(error), 'compatible_16kb':False})
        report['aab_bytes'] = aab.stat().st_size
    if ios_app.is_dir():
        info = plistlib.loads((ios_app / 'Info.plist').read_bytes())
        report['ios'] = {k: info.get(k) for k in ['CFBundleIdentifier','MinimumOSVersion','CFBundleShortVersionString','CFBundleVersion','NSLocationWhenInUseUsageDescription','NSLocationAlwaysAndWhenInUseUsageDescription']}
        report['ios_privacy_manifests'] = []
        for file in sorted(ios_app.rglob('*.xcprivacy')):
            privacy = plistlib.loads(file.read_bytes())
            report['ios_privacy_manifests'].append({'path':str(file.relative_to(ios_app)),
                'tracking':privacy.get('NSPrivacyTracking'),
                'collected_data':privacy.get('NSPrivacyCollectedDataTypes', []),
                'accessed_apis':privacy.get('NSPrivacyAccessedAPITypes', [])})
    report['limitations'] = ['ELF alignment does not prove runtime behavior on a 16KB device.',
        'AAB inspection does not verify generated APK ZIP alignment.',
        'Privacy manifests require a human review of actual SDK behavior and store declarations.',
        'Unsigned builds are not submission-ready.']
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--aab', type=Path, default=Path('build/app/outputs/bundle/release/app-release.aab'))
    parser.add_argument('--ios-app', type=Path, default=Path('build/ios/iphoneos/Runner.app'))
    args = parser.parse_args()
    print(json.dumps(inspect(args.aab, args.ios_app), ensure_ascii=False, indent=2))
