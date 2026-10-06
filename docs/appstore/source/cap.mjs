import { createRequire } from 'module'; const puppeteer = createRequire('/Users/song/Developer/web-builder/tilt/')('puppeteer-core');
const out = process.argv[2];
const b = await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:'new', args:['--use-angle=metal','--enable-gpu']});
const p = await b.newPage();
p.on('console', m => console.log('console:', m.text()));
p.on('pageerror', e => console.log('pageerror:', e.message));
await p.setViewport({width:1440,height:900,deviceScaleFactor:2});
for (const s of (process.argv[3]||"1,2,3,4,5").split(",").map(Number)) {
  await p.goto(`http://localhost:5287/?s=${s}`,{waitUntil:'networkidle0'});
  await p.waitForFunction('window.__ready === true', {timeout: 30000});
  await p.evaluate(() => document.fonts.ready);
  await new Promise(r=>setTimeout(r,800));
  await p.screenshot({path:`${out}/${s}.png`});
}
await b.close();
