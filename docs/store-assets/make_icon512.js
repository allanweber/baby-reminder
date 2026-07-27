const fs=require('fs'),path=require('path');
const {chromium}=require('/opt/node22/lib/node_modules/playwright');
const APP='/home/user/baby-reminder/app';
const fg=fs.readFileSync(path.join(APP,'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png')).toString('base64');
const OUT=process.argv[2];
const html=`<!doctype html><meta charset=utf-8><style>*{margin:0;padding:0}
html,body{width:512px;height:512px;overflow:hidden}
.i{position:relative;width:512px;height:512px;background:#E39C8B}
.i img{position:absolute;inset:0;width:512px;height:512px}</style>
<div class=i><img src="data:image/png;base64,${fg}"></div>`;
const f='/tmp/claude-0/-home-user-baby-reminder/5d53dfe1-b366-5bc5-86b1-e619f5da9517/scratchpad/icon512.html';
fs.writeFileSync(f,html);
function chrome(){for(const d of fs.readdirSync('/opt/pw-browsers')){if(d.startsWith('chromium-')){const p=`/opt/pw-browsers/${d}/chrome-linux/chrome`;if(fs.existsSync(p))return p;}}}
(async()=>{const b=await chromium.launch({executablePath:chrome()});
const p=await b.newPage({viewport:{width:512,height:512},deviceScaleFactor:1});
await p.goto('file://'+f);await p.waitForTimeout(200);
await p.screenshot({path:OUT,clip:{x:0,y:0,width:512,height:512}});await b.close();console.log('wrote',OUT);})();
