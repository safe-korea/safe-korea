"""Generate clearly labeled training speech locally on macOS; never play it.
Requires the already installed Yuna Korean voice and afconvert. No downloads.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
MESSAGES = {
    'watch': '훈련입니다. 실제 경보가 아닙니다. 경계경보 연습. 정부 방송을 확인하고 대피를 준비하세요.',
    'cbrn': '훈련입니다. 실제 경보가 아닙니다. 화생방경보 연습. 방송에서 공격 종류를 확인하고 호흡기와 피부를 보호하세요.',
    'chemical': '훈련입니다. 실제 경보가 아닙니다. 화학 공격 대비 연습. 외부 공기를 차단하고 정부 대피 안내를 확인하세요.',
    'biological': '훈련입니다. 실제 경보가 아닙니다. 생물학 공격 대비 연습. 호흡기를 보호하고 보건당국 안내를 따르세요.',
    'release': '훈련입니다. 실제 경보가 아닙니다. 경보해제 연습. 추가 정부 안내와 현장 지시를 계속 확인하세요.',
}


def generate():
    with tempfile.TemporaryDirectory() as directory:
        for kind, message in MESSAGES.items():
            source = Path(directory) / f'{kind}.aiff'
            target = ROOT / f'ios/Runner/drill_{kind}_voice.wav'
            subprocess.run(['/usr/bin/say', '-v', 'Yuna', '-r', '175', '-o', str(source), message], check=True)
            subprocess.run(['/usr/bin/afconvert', '-f', 'WAVE', '-d', 'LEI16@22050', '-c', '1', str(source), str(target)], check=True)
            with wave.open(str(target)) as audio:
                if not 1 < audio.getnframes() / audio.getframerate() < 30:
                    raise ValueError('Notification audio must be shorter than 30 seconds')
            shutil.copyfile(target, ROOT / f'android/app/src/main/res/raw/{target.name}')


if __name__ == '__main__':
    generate()
