"""Render the recorded native app walkthrough with Korean captions and local narration.
Requires ffmpeg, Pillow, macOS Yuna voice; no cloud TTS or uploaded user data.
Missing narration takes are generated locally with the built-in Yuna voice.
"""
import json, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
SCENARIO='--scenario' in sys.argv
WORK=ROOT/('.tools/full-demo-edit/scenario' if SCENARIO else '.tools/full-demo-edit');WORK.mkdir(parents=True,exist_ok=True)
DEMO=ROOT/'artifacts/demo'
MARKS=json.loads((DEMO/'full-demo-markers.json').read_text())
RAW=DEMO/'safeKor_full_raw.mp4'
FONT=ROOT/'assets/fonts/NanumGothic-Regular.ttf'
SCENES=[
('home',4,'갑작스러운 경보,\n무엇부터 해야 할까요?','모의 경보·사이렌이 포함된 시연'),
('drill',6,'지금 해야 할 행동부터\n크게, 명확하게','훈련 / 테스트 · 실제 정부 경보 수신 아님'),
('actions',6,'실내·실외·이동 중\n내 상황에 맞게 바로 행동','훈련 / 테스트'),
('save',6,'대피소를 미리 확인하고\n내 휴대폰에 저장하세요','공식 시설 조회 자료 · 개방 여부는 현장 확인'),
('saved',3,'주변 지도도\n함께 저장됩니다','선택한 시설 주변 도로 자료만 다운로드'),
('offline',4,'통신이 끊겨도\n미리 저장한 정보는 그대로','통신 끊김 상황 재현 · 신규 네트워크 연결 차단'),
('map',5,'저장한 대피소와\n주변 도로를 확인하세요','저장한 참고 지도 · 현재 위치·길찾기 없음'),
('zoom',3,'연결 없이 확대해서\n주변 도로 확인','저장한 참고 지도 · 현재 위치·길찾기 없음'),
('family',5,'연락이 될 때\n가족과 만날 장소를 정하세요','통신 복구 후 · 시연용 가족 약속'),
('share',4,'만날 장소와 약속을\n가족에게 미리 공유하세요','공유할 내용 확인'),
('sheet',3,'카카오톡 등\n원하는 앱으로 공유','공유 창 시연 · 실제 전송하지 않음'),
('closing',4,'미리 준비해 두세요.\n필요할 때 바로 꺼내 보세요.','safeKor · 대피 준비와 행동요령'),
]
VOICE={
'home':'갑작스러운 경보. 무엇부터 해야 할까요?',
'drill':'모의 경보입니다. 지금 해야 할 행동부터 확인하세요.',
'actions':'내가 있는 상황을 선택하고, 바로 행동하세요.',
'save':'평소에는 가까운 대피소를 확인하고 저장하세요.',
'saved':'주변 지도도 함께 저장됩니다.',
'offline':'통신이 끊겨도, 저장한 정보는 남습니다.',
'map':'저장한 대피소와 주변 도로를 확인하세요.',
'family':'연락이 될 때, 가족과 만날 장소를 정해 두세요.',
'share':'만날 장소와 약속을 함께 공유할 수 있습니다.',
'closing':'미리 준비해 두세요. 필요할 때 바로 꺼내 보세요.'}

if SCENARIO:
    SCENES=[
      ('arrival',5,'경보가 울린 순간,\n무엇을 해야 할까요?','경보 상황 재현 · 실제 정부 경보 수신 영상 아님'),
      ('open',3,'safeKor를 열고\n지금 할 행동을 확인하세요','경보를 들은 뒤 사용자가 앱을 여는 상황'),
      ('kind',6,'들은 경보를 선택하고,\n내 상황을 확인하세요','경보·현재 상황 직접 선택'),
      ('actions',7,'실내라면 계단으로.\n물품을 찾느라 지체하지 마세요.','행정안전부 행동요령 요약 · 현장 지시 우선'),
      ('offline',5,'미리 저장해 둔\n대피소를 확인하세요','사전에 저장을 마친 시설 · 신규 네트워크 연결 차단'),
      ('map',6,'통신이 끊겨도\n저장한 지도는 내 폰에.','저장한 참고 지도 · 현재 위치·길찾기 없음'),
      ('zoom',3,'확대해서\n주변 도로를 확인하세요','개방 여부·안전한 이동 경로는 현장 확인'),
      ('family',5,'연락이 될 때\n가족과 만날 장소를 정하세요','통신 복구 후 · 시연용 가족 약속'),
      ('share',4,'만날 장소와 약속을\n가족에게 미리 공유하세요','공유할 내용 확인'),
      ('sheet',3,'카카오톡 등\n원하는 앱으로 공유','공유 창 시연 · 실제 전송하지 않음'),
      ('closing',4,'미리 준비해 두세요.\n필요할 때 바로 꺼내 보세요.','safeKor · 대피 준비와 행동요령'),
    ]
    VOICE.update({
      'arrival':'경보가 울렸다면, 무엇부터 해야 할까요?',
      'open':'앱을 열고, 지금 할 행동을 확인하세요.',
      'kind':'들은 경보를 선택하고, 지금 있는 상황을 확인하세요.',
      'actions':'실내라면 계단으로 이동하세요. 물품을 찾느라 지체하지 마세요.',
      'offline':'미리 저장해 둔 대피소를 확인하세요.',
      'map':'통신이 끊겨도, 저장한 주변 지도는 확인할 수 있습니다.',
    })

def run(args):
    subprocess.run(args,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
def duration(path):
    return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(path)],text=True).strip())
def center(draw,text,y,size,color):
    font=ImageFont.truetype(str(FONT),size)
    box=draw.textbbox((0,0),text,font=font)
    draw.text(((1080-(box[2]-box[0]))/2,y),text,font=font,fill=color)

# Simulator recordings are sparse VFR: materialize held frames before seeking.
cfr=WORK/'raw-cfr.mp4'
run(['ffmpeg','-y','-i',str(RAW),'-vf','fps=30','-an','-c:v','libx264','-preset','fast','-crf','20',str(cfr)])
RAW=cfr
FAMILY=DEMO/'safeKor_family_raw.mp4'
FAMILY_MARKS=json.loads((DEMO/'family-demo-markers.json').read_text()) if FAMILY.exists() else {}
if FAMILY.exists():
    family_cfr=WORK/'family-cfr.mp4'
    run(['ffmpeg','-y','-i',str(FAMILY),'-vf','fps=30','-an','-c:v','libx264','-preset','fast','-crf','20',str(family_cfr)])
    FAMILY=family_cfr

SCENARIO_MARKS={}
if SCENARIO:
    SCENARIO_MARKS=json.loads((DEMO/'scenario-demo-markers.json').read_text())
    scenario_cfr=WORK/'scenario-cfr.mp4'
    run(['ffmpeg','-y','-i',str(DEMO/'safeKor_scenario_raw.mp4'),'-vf','fps=30','-an','-c:v','libx264','-preset','fast','-crf','20',str(scenario_cfr)])

files=[];timeline=[];elapsed=0
for i,(key,seconds,caption,note) in enumerate(SCENES):
    overlay=Image.new('RGBA',(1080,1920),(0,0,0,0));d=ImageDraw.Draw(overlay)
    d.rectangle((0,1720,1080,1920),fill='#F4F7F4')
    for j,line in enumerate(caption.splitlines()):center(d,line,1740+j*57,46,'#17352D')
    center(d,note,1870,23,'#52665E')
    badge=('상황 재현' if key in ['arrival','open','kind','actions'] else 'safeKor') if SCENARIO else ('모의 경보' if key in ['drill','actions'] else 'safeKor')
    d.rounded_rectangle((12,18,152,68),radius=12,fill='#B42318' if key in ['drill','actions'] else '#086B50')
    d.text((25,31),badge,font=ImageFont.truetype(str(FONT),25),fill='white')
    png=WORK/f'{key}-caption.png';overlay.save(png)
    clip=WORK/f'{i:02d}-{key}.mp4'
    if key=='arrival':
        frame=Image.new('RGB',(1080,1920),'#941F19');fd=ImageDraw.Draw(frame)
        center(fd,'경보를 들은 상황',420,44,'#FFDECE')
        center(fd,'공습경보',610,122,'white')
        center(fd,'지금, 어디에 있나요?',820,57,'white')
        center(fd,'실내 · 실외 · 이동 중',930,38,'#FFDECE')
        center(fd,'사이렌에 당황하지 마세요.',1160,43,'white')
        arrival=WORK/'arrival.png';frame.save(arrival)
        args=['-loop','1','-i',str(arrival)]
        base='[0:v]format=yuv420p[base]'
    elif key=='closing':
        frame=Image.new('RGB',(1080,1920),'#F4F7F4');fd=ImageDraw.Draw(frame)
        icon=Image.open(ROOT/'release/branding/icon-play-512.png').convert('RGBA');icon.thumbnail((340,340))
        frame.paste(icon,((1080-icon.width)//2,560),icon)
        center(fd,'safeKor',960,76,'#17352D')
        center(fd,'대피 준비와 행동요령',1070,39,'#086B50')
        center(fd,'Android 앱 · iPhone은 PWA',1160,25,'#52665E')
        center(fd,'본 영상: iPhone 시뮬레이터의 네이티브 개발 앱',1220,23,'#52665E')
        ending=WORK/'closing.png';frame.save(ending)
        args=['-loop','1','-i',str(ending)]
        base='[0:v]format=yuv420p[base]'
    elif SCENARIO and key in ['map','zoom']:
        # Hold verified native captures, avoiding a source clip crossing into the next screen.
        shot=ROOT/'artifacts/visual-qa'/('saved-facility-map-offline-ios.png' if key=='map' else 'scenario-map-zoom-ios.png')
        args=['-loop','1','-i',str(shot)]
        base='[0:v]scale=-2:1680:flags=lanczos,pad=1080:1920:(ow-iw)/2:20:color=0xF4F7F4,setsar=1[base]'
    else:
        # Begin at the scene marker; the following hold leaves time to read the UI.
        if key in SCENARIO_MARKS:
            source=scenario_cfr;at=SCENARIO_MARKS[key]
        elif key in FAMILY_MARKS:
            source=FAMILY;at=FAMILY_MARKS[key]
        else:
            source=RAW;at=MARKS[key]
        args=['-ss',str(at+.12),'-i',str(source)]
        base='[0:v]scale=-2:1680:flags=lanczos,pad=1080:1920:(ow-iw)/2:20:color=0xF4F7F4,setsar=1[base]'
    run(['ffmpeg','-y',*args,'-loop','1','-i',str(png),'-filter_complex',base+';[base][1:v]overlay=0:0,format=yuv420p[v]','-map','[v]','-an','-t',str(seconds),'-r','30','-c:v','libx264','-preset','fast','-crf','20',str(clip)])
    files.append(clip);timeline.append({'scene':key,'start':elapsed,'duration':seconds,'caption':caption,'note':note});elapsed+=seconds

concat=WORK/'clips.txt';concat.write_text(''.join(f"file '{p}'\n" for p in files))
silent=WORK/'silent.mp4';run(['ffmpeg','-y','-f','concat','-safe','0','-i',str(concat),'-c','copy',str(silent)])
inputs=[];filters=[];labels=[]
for entry in timeline:
    key=entry['scene']
    if key not in VOICE:continue
    speech=WORK/f'{key}.aiff'
    if not speech.exists():run(['say','-v','Yuna','-r','190','-o',str(speech),VOICE[key]])
    index=len(inputs)//2;inputs+=['-i',str(speech)]
    offset=1.5 if key in ['drill','arrival'] else .1
    maximum=entry['duration']-offset-.15
    speed=max(1.0,duration(speech)/maximum)
    delay=int((entry['start']+offset)*1000)
    filters.append(f'[{index}:a]atempo={speed:.4f},volume=0.95,afade=t=out:st={maximum-.12}:d=0.12,adelay={delay}|{delay}[a{index}]')
    labels.append(f'[a{index}]')
index=len(inputs)//2;inputs+=['-i',str(ROOT/'ios/Runner/drill_siren.wav')]
siren_delay=0 if SCENARIO else 4000
filters.append(f'[{index}:a]atrim=0:1.5,asetpts=PTS-STARTPTS,volume=0.12,afade=t=in:d=0.1,afade=t=out:st=1.2:d=0.3,adelay={siren_delay}|{siren_delay}[siren]');labels.append('[siren]')
filters.append(''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,apad,atrim=0:{elapsed},alimiter=limit=0.9,loudnorm=I=-16:TP=-1.5:LRA=9[mix]')
audio=WORK/'mixed.wav';run(['ffmpeg','-y',*inputs,'-filter_complex',';'.join(filters),'-map','[mix]','-ar','48000','-ac','2',str(audio)])
output=DEMO/('safeKor_경보상황_스토리시연_자막음성.mp4' if SCENARIO else 'safeKor_전체시연_자막음성_60초이내.mp4')
run(['ffmpeg','-y','-i',str(silent),'-i',str(audio),'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','192k','-t',str(elapsed),'-movflags','+faststart',str(output)])
(DEMO/('scenario-demo-timeline.json' if SCENARIO else 'full-demo-timeline.json')).write_text(json.dumps(timeline,ensure_ascii=False,indent=2)+'\n')
assert duration(output)<60
print(output, duration(output))

def stamp(t):
    return f'{int(t)//3600:02d}:{int(t)//60%60:02d}:{int(t)%60:02d},000'
(DEMO/('safeKor_경보상황_자막.srt' if SCENARIO else 'safeKor_전체시연_자막.srt')).write_text('\n'.join(f"{i+1}\n{stamp(e['start'])} --> {stamp(e['start']+e['duration'])}\n{e['caption']}\n" for i,e in enumerate(timeline)))
