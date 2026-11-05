// Render the existing HTML brand as iOS launch assets; no new artwork or network.
const {webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const fs=require('node:fs');
const sizes=[[375,667,2],[414,736,3],[375,812,3],[414,896,2],[390,844,3],[393,852,3],[430,932,3],[402,874,3],[440,956,3]];
(async()=>{
 const source=fs.readFileSync('web/app.html','utf8');
 const css=source.match(/<style>([\s\S]*?)<\/style>/)[1];
 const icon=fs.readFileSync('web/icons/icon-192.png').toString('base64');
 const brand=source.match(/<div id="boot-splash"[\s\S]*?<\/div>/)[0].replace('icons/icon-192.png','data:image/png;base64,'+icon);
 const browser=await webkit.launch({headless:true});
 const links=[];
 try{
  for(const[width,height,scale]of sizes){
   const c=await browser.newContext({viewport:{width,height},deviceScaleFactor:scale});
   const page=await c.newPage();
   await page.setContent(`<html><head><style>${css}#boot-splash .boot-spinner{visibility:hidden;animation:none}</style></head><body>${brand}</body></html>`);
   await page.waitForFunction(()=>document.querySelector('img').complete);
   const name=`startup-${width*scale}x${height*scale}.png`;
   await page.screenshot({path:'web/icons/'+name});await c.close();
   links.push(`  <link rel="apple-touch-startup-image" href="PREFIXicons/${name}" media="(device-width: ${width}px) and (device-height: ${height}px) and (-webkit-device-pixel-ratio: ${scale}) and (orientation: portrait)">`);
  }
 }finally{await browser.close();}
 for(const file of ['web/app.html','web/index.html']){
  let html=fs.readFileSync(file,'utf8');
  const block='  <!--IOS_STARTUP_IMAGES-->\n'+links.join('\n').replaceAll('PREFIX',file.endsWith('app.html')?'../':'')+'\n  <!--/IOS_STARTUP_IMAGES-->';
  if(html.includes('<!--IOS_STARTUP_IMAGES-->'))html=html.replace(/  <!--IOS_STARTUP_IMAGES-->[\s\S]*?  <!--\/IOS_STARTUP_IMAGES-->/,block);
  else html=html.replace('  <meta name="apple-mobile-web-app-status-bar-style" content="default">','  <meta name="apple-mobile-web-app-status-bar-style" content="default">\n'+block);
  fs.writeFileSync(file,html);
 }
 console.log(`Rendered ${sizes.length} portrait startup images from the existing brand.`);
})().catch(e=>{console.error(e);process.exit(1)});
