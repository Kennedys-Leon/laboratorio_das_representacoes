const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
 const source = fs.readFileSync('scripts/accessibility_web.js','utf8');
 const server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end(req.url==='/game' ? '<!doctype html><html lang="pt-BR"><body><script>'+source+'</script></body></html>' : '<!doctype html><html lang="pt-BR"><body><iframe src="/game" title="Jogo"></iframe></body></html>');}).listen(0,'127.0.0.1');
 await new Promise(r=>server.once('listening',r));
 const browser=await chromium.launch({headless:true});
 try {
  const page=await browser.newPage({viewport:{width:390,height:844}});
  await page.goto('http://127.0.0.1:'+server.address().port);
  const frame=page.frames().find(f=>f.url().endsWith('/game'));
  await frame.waitForFunction(()=>!!window.gaussAccess);
  await page.evaluate(()=>document.querySelector('iframe').contentWindow.postMessage({type:'gauss-accessibility-profile',version:1,profile:{version:1,textScale:2}},location.origin));
  await frame.waitForFunction(()=>window.gaussAccess.queue.length===1);
  await frame.evaluate(()=>window.dispatchEvent(new MessageEvent('message',{origin:'https://wrong.invalid',source:parent,data:{type:'gauss-accessibility-profile',version:1,profile:{}}})));
  assert.equal(await frame.evaluate(()=>window.gaussAccess.queue.length),1);
  await frame.getByRole('button',{name:'Abrir atividade em texto'}).focus();
  await page.keyboard.press('Enter');
  const state={title:'Frações',question:'Escolha uma parte do círculo.',status:'Escolha uma resposta.',scale:2,high:true,preferText:false,controls:[{text:'Parte 1',action:'part',index:0,disabled:false,toggle:true,selected:false},{text:'Conferir',action:'check',index:0,disabled:true}]};
  await frame.evaluate(s=>window.gaussAccess.render(s),state);
  await frame.getByRole('button',{name:'Parte 1'}).focus();
  await page.keyboard.press('Enter');
  assert.deepEqual(await frame.evaluate(()=>window.gaussAccess.actions.at(-1)),['part',0]);
  state.controls[0].selected=true;
  await frame.evaluate(s=>window.gaussAccess.render(s),state);
  assert.equal(await frame.getByRole('button',{name:'Parte 1'}).getAttribute('aria-pressed'),'true');
  assert.equal(await frame.evaluate(()=>document.activeElement.textContent),'Parte 1');
  assert.equal(await frame.getByRole('button',{name:'Conferir'}).isDisabled(),true);
  console.log('PASS: same-origin parent bridge, rejected foreign origin, HTML buttons via Enter, selected state, focus preservation, disabled controls');
 } finally {await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exit(1)});
