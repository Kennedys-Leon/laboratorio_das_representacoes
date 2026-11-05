(() => {
 if (window.gaussAccess) return;
 const a = window.gaussAccess = {queue: [], actions: [], open: false, signature: ''};
 const entry = document.createElement('button');
 entry.textContent = 'Abrir atividade em texto';
 entry.style.cssText = 'position:fixed;left:8px;top:8px;z-index:10000;padding:12px;font:18px sans-serif';
 document.body.prepend(entry);
 entry.style.transform='translateY(-150%)';
 entry.onfocus=()=>entry.style.transform='none';
 entry.onblur=()=>entry.style.transform='translateY(-150%)';
 const panel = document.createElement('section');
 panel.setAttribute('aria-label','Laboratório das Representações — atividade em texto');
 panel.style.cssText = 'position:fixed;inset:0;overflow:auto;z-index:10001;padding:24px;box-sizing:border-box;background:#fffaf0;color:#211737;font:20px/1.5 sans-serif';
 panel.hidden = true; document.body.append(panel);
 entry.onclick = () => { a.open = true; panel.hidden = false; a.signature = ''; a.actions.push(['open',0]); };
 window.addEventListener('message', e => {
  if (e.origin !== location.origin || e.source !== window.parent || !e.data || e.data.type !== 'gauss-accessibility-profile' || e.data.version !== 1) return;
  a.queue.push(JSON.stringify(e.data.profile));
 });
 window.parent.postMessage({type:'gauss-accessibility-ready'}, location.origin);
 a.render = state => {
  if (state.preferText && !a.open) {a.open = true; panel.hidden = false;}
  if (!a.open) return;
  const signature = JSON.stringify(state); if (a.signature === signature) return;
  a.signature = signature;
  const focusKey = document.activeElement?.dataset?.key;
  panel.replaceChildren();
  panel.style.fontSize = (20 * state.scale) + 'px';
  panel.style.background = state.high ? '#101526' : '#fffaf0'; panel.style.color = state.high ? '#fff' : '#211737';
  const heading = document.createElement('h1'); heading.textContent = state.title; panel.append(heading);
  const question = document.createElement('p'); question.textContent = state.question; panel.append(question);
  const status = document.createElement('p'); status.setAttribute('role','status'); status.textContent = state.status; panel.append(status);
  for (const control of state.controls) {
   const b = document.createElement('button'); b.textContent = control.text; b.disabled = control.disabled;
   b.dataset.key = control.action + ':' + control.index;
   b.style.cssText = 'font:inherit;padding:14px;margin:6px;border:2px solid #72529a;border-radius:10px;min-height:48px;background:#fff;color:#211737';
   if (control.toggle) b.setAttribute('aria-pressed', String(control.selected));
   b.onclick = () => a.actions.push([control.action, control.index]); panel.append(b);
  }
  const close = document.createElement('button'); close.textContent='Voltar ao jogo visual'; close.style.cssText='font:inherit;padding:14px;margin:6px';
  close.onclick=()=>{a.open=false;panel.hidden=true;entry.focus();}; panel.append(close);
  if (focusKey) {const target=Array.from(panel.querySelectorAll('button')).find(b=>b.dataset.key===focusKey && !b.disabled); target?.focus();}
 };
})();
