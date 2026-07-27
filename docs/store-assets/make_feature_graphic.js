const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PW || '/opt/node22/lib/node_modules/playwright');

const APP = '/home/user/baby-reminder/app';
const OUT_PNG = process.argv[2];
const OUT_HTML = process.argv[3];

const b64 = (p) => fs.readFileSync(p).toString('base64');
const baloo = b64(path.join(APP, 'assets/fonts/Baloo2.ttf'));
const nunito = b64(path.join(APP, 'assets/fonts/Nunito.ttf'));
const icon = b64(path.join(APP, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'));

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family:'Baloo 2'; src:url(data:font/ttf;base64,${baloo}) format('truetype'); font-weight:700; }
@font-face { font-family:'Nunito'; src:url(data:font/ttf;base64,${nunito}) format('truetype'); font-weight:600; }
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:1024px;height:500px;overflow:hidden;}
.g{
  position:relative;width:1024px;height:500px;
  background:linear-gradient(120deg,#FCEFE7 0%,#FBE7DA 55%,#F7DFD3 100%);
  font-family:'Nunito',sans-serif;
}
/* soft decorative blobs */
.blob{position:absolute;border-radius:50%;filter:blur(2px);opacity:.35;}
.blob.coral{width:360px;height:360px;background:radial-gradient(circle at 30% 30%,#F0B7A6,#E59C87 70%,transparent 72%);top:-120px;right:-60px;opacity:.45;}
.blob.teal{width:300px;height:300px;background:radial-gradient(circle at 40% 40%,#9FC3CC,#6C97A4 70%,transparent 72%);bottom:-150px;left:-90px;opacity:.30;}
.dot{position:absolute;border-radius:50%;}
.left{position:absolute;left:72px;top:0;height:500px;display:flex;flex-direction:column;justify-content:center;width:560px;}
.word{font-family:'Baloo 2';font-weight:700;font-size:118px;line-height:1;color:#3E332E;letter-spacing:-1px;}
.word .n{color:#D98876;}
.tag{margin-top:18px;font-size:31px;font-weight:600;color:#8C7C74;white-space:nowrap;}
.feats{margin-top:30px;display:flex;gap:14px;}
.pill{font-size:22px;font-weight:600;padding:11px 20px;border-radius:999px;background:#FFFFFF;color:#6E635D;box-shadow:0 6px 16px rgba(120,80,60,.10);}
.pill.c{color:#C9735E;}
.pill.t{color:#4E7E8E;}
/* icon on the right */
.iconwrap{position:absolute;right:88px;top:50%;transform:translateY(-50%);}
.icon{width:262px;height:262px;border-radius:60px;box-shadow:0 26px 60px rgba(150,90,70,.30);display:block;}
.ring{position:absolute;inset:-22px;border-radius:82px;border:3px dashed #E1A996;opacity:.55;}
.mini{position:absolute;border-radius:50%;box-shadow:0 8px 18px rgba(120,80,60,.15);}
</style></head>
<body>
  <div class="g">
    <div class="blob coral"></div>
    <div class="blob teal"></div>
    <div class="dot" style="width:16px;height:16px;background:#E7B26E;top:96px;left:640px;opacity:.7;"></div>
    <div class="dot" style="width:11px;height:11px;background:#7FB0A0;top:150px;left:600px;opacity:.7;"></div>
    <div class="dot" style="width:13px;height:13px;background:#D98876;bottom:120px;left:560px;opacity:.6;"></div>

    <div class="left">
      <div class="word"><span class="n">N</span>estling</div>
      <div class="tag">Baby feeding tracker &amp; reminders</div>
      <div class="feats">
        <div class="pill c">Log feeds</div>
        <div class="pill t">Smart alarms</div>
        <div class="pill">Fully offline</div>
      </div>
    </div>

    <div class="iconwrap">
      <div class="ring"></div>
      <img class="icon" src="data:image/png;base64,${icon}"/>
      <div class="mini" style="width:54px;height:54px;background:#F2D7A0;right:-18px;top:-6px;"></div>
      <div class="mini" style="width:40px;height:40px;background:#BcdcdC;left:-26px;bottom:20px;"></div>
    </div>
  </div>
</body></html>`;

fs.writeFileSync(OUT_HTML, html);

function findChrome() {
  const base = '/opt/pw-browsers';
  for (const d of fs.readdirSync(base)) {
    if (d.startsWith('chromium-')) {
      const p = path.join(base, d, 'chrome-linux', 'chrome');
      if (fs.existsSync(p)) return p;
    }
  }
  return undefined; // let playwright use its default
}

(async () => {
  const browser = await chromium.launch({ executablePath: findChrome() });
  const page = await browser.newPage({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
  await page.goto('file://' + OUT_HTML);
  await page.waitForTimeout(400); // let fonts settle
  await page.screenshot({ path: OUT_PNG, clip: { x: 0, y: 0, width: 1024, height: 500 } });
  await browser.close();
  console.log('wrote', OUT_PNG);
})();
