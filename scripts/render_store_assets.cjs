// Deterministic SVG/HTML brand export, not an AI screenshot or edited app capture.
const {chromium}=require('../.tools/pwa-qa/node_modules/playwright');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({headless:true});
 try {
  const page=await browser.newPage({viewport:{width:1024,height:500},deviceScaleFactor:1});
  const font=fs.readFileSync('assets/fonts/NanumGothic-Regular.ttf').toString('base64');
  const mascot=fs.readFileSync('release/branding/mascot-jindo-v1.png').toString('base64');
  const source=fs.readFileSync('release/branding/icon-concepts/c-jindo-minimal-v2.png').toString('base64');
  // Resize the selected artwork only; do not redraw or alter its design.
  const png=await page.evaluate(async source=>{const img=new Image();img.src='data:image/png;base64,'+source;await img.decode();const c=document.createElement('canvas');c.width=c.height=512;c.getContext('2d').drawImage(img,0,0,512,512);return c.toDataURL('image/png').split(',')[1];},source);
  fs.writeFileSync('release/branding/icon-play-512.png',Buffer.from(png,'base64'));
  const html=`<!doctype html><html lang="ko"><meta charset="utf-8"><style>@font-face{font-family:Safe;src:url(data:font/ttf;base64,${font})}*{box-sizing:border-box}body{margin:0;background:#f5f8f6;color:#17352d;font-family:Safe,sans-serif}.art{width:1024px;height:500px;position:relative;padding:44px 56px;overflow:hidden}.eyebrow{font-size:18px;letter-spacing:2px;color:#086b50;margin:0 0 22px}h1{font-size:49px;line-height:1.3;letter-spacing:-2px;margin:0}.tags{display:flex;gap:12px;margin-top:26px}.tags span{font-size:20px;padding:12px 18px;background:white;border:1px solid #cadbd2;border-radius:14px}.note{font-size:17px;margin-top:26px;color:#53665e}.mascot{position:absolute;right:24px;bottom:12px;width:280px;height:420px;object-fit:contain}.line{position:absolute;right:62px;top:58px;width:82px;height:8px;background:#086b50;border-radius:4px}</style><div class="art"><img class="mascot" alt="진돗개 캐릭터 시안" src="data:image/png;base64,${mascot}"><div class="line"></div><p class="eyebrow">SAFE KOREA</p><h1>평소의 준비가<br>비상시의 첫걸음</h1><div class="tags"><span>대피소 확인</span><span>오프라인 행동요령</span><span>가족 만남 계획</span></div><p class="note">비공식 비상 대비 앱 · 실제 정부 경보 수신 기능 없음</p></div></html>`;
  await page.setContent(html);await page.evaluate(()=>document.fonts.ready);await page.locator('.art').screenshot({path:'release/branding/feature-graphic-1024x500.png'});
  for(const name of ['title','short-description','full-description']) {
   const text=fs.readFileSync(`release/store/ko-KR/${name}.txt`,'utf8').trim();const max={title:30,'short-description':80,'full-description':4000}[name];if([...text].length>max)throw Error(name+' exceeds limit');console.log(name,[...text].length+'/'+max);
  }
  for(const f of fs.readdirSync('release/store/ko-KR/screenshots')) {
   const bytes=fs.readFileSync(path.join('release/store/ko-KR/screenshots',f));const w=bytes.readUInt32BE(16),h=bytes.readUInt32BE(20);if(w!==1080||h!==1920)throw Error('Unexpected capture size '+f);console.log(f,w,h,'PNG color type',bytes[25]);
  }
  const icon=fs.readFileSync('release/branding/icon-play-512.png');if(icon.length>1024*1024||icon[25]!==6)throw Error('Icon must be RGBA and <=1MiB');
  const banner=fs.readFileSync('release/branding/feature-graphic-1024x500.png');if(banner[25]!==2)throw Error('Feature graphic must be RGB without alpha');
  console.log('Brand PNG dimensions/format and store text lengths PASS');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
