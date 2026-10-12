/*DESIGN_MODULE_BEGIN*/
(function(){"use strict";
const PR={dano:20,Preso:10,Atordoado:25,Lento:8,'Rápido':8,Forte:15,Resistente:12,Fraco:12,'Frágil':15,Marcado:8,Sangramento:8,Ferido:10,Oculto:12,'Provocação':8,'Proteção':20,Barreira:2,Cura:1.2,Empurrar:6,Puxar:6,Voo:10,'Sequência':0.6,'Área':1.2,Alcance:5,'Ágil':6,'Grátis':12,Recompra:4,Comprar:12,Vorpal:25,Invocar:60,Atento:6,Confuso:15,Dreno:0.25,Transformar:30};
const PRN={dano:'Dano (por 1,0 de CartaMult)',Barreira:'Barreira (por ponto)',Cura:'Cura (por % da Vida)','Sequência':'Sequência (× dano, por alvo extra)','Área':'Área (× dano, alvos extras)',Dreno:'Dreno (× dano)',Recompra:'Recompra (por INI gerado)',Comprar:'Comprar (por carta)',Invocar:'Invocar (por invocação)',Transformar:'Transformar (troca de forma)'};
const MULT=['Sequência','Área','Dreno'];
const DP={mult:1.5,alvo:4},WP={w2:0.25,wARM:1,wESC:1,ref:3600,pAttr:100,pMan:1,pAp:1,pDes:1,rodadas:4,compras:1.5,deck:10,sin:10};
const MP={carregamento:0.75,final:0.8,requisito:0.7};
const ST=['Preso','Atordoado','Lento','Rápido','Forte','Resistente','Fraco','Frágil','Marcado','Sangramento','Ferido','Oculto','Provocação','Proteção','Barreira','Voo','Vorpal','Atento','Confuso','Empurrar','Puxar'];
const ALIAS={Sangrando:'Sangramento',Bleed:'Sangramento',Atordoada:'Atordoado',Lenta:'Lento','Rápida':'Rápido',Fortalecido:'Forte',Fraca:'Fraco',Frágeis:'Frágil',Presa:'Preso',Ferida:'Ferido',Voar:'Voo',Provocada:'Provocação',Empurra:'Empurrar',Chain:'Sequência',Fileira:'Área'};
function parse(t){t=String(t||'');const g={},n=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();const T=n(t);
 const num=(re)=>{const m=t.match(re);return m?+(m[1]||1):0};
 if(/\b(impacto|poder)\b/i.test(t)&&!/sem dano/i.test(t)){let m=1;const x=t.match(/[×x]\s*(\d+(?:[.,]\d+)?)/);if(x&&!/×E/.test(x[0]))m=+x[1].replace(',','.');if(/Impacto\+/.test(t))m+=0.2;if(/2×E/.test(t))m=2;g.dano=m}
 const names=ST.concat(Object.keys(ALIAS));for(const w of names){const k=ALIAS[w]||w;if(k=='Sequência')continue;const re=new RegExp('(?:^|[^\\wÀ-ú])'+w+'s?(?![\\wÀ-ú])\\s*(\\d+)?','i');const m=t.match(re);if(m){if(new RegExp('(contra|se (?:o alvo )?(?:estiver )?|consome )'+w,'i').test(t)&&!new RegExp(w+'s?\\s*\\d','i').test(t)){continue}g[k]=Math.max(g[k]||0,+(m[1]||1))}}
 if(/perde (voo|oculto)/i.test(t)){if(/perde voo/i.test(t))delete g.Voo;if(/perde oculto/i.test(t))delete g.Oculto}
 const sq=t.match(/(?:Sequência|Chain|Corrente)\s*(\d+)?/i);if(sq)g['Sequência']=+(sq[1]||1);
 if(/Área|linha inimiga|Fileira|todos (os )?inimigos|todos os outros|toda a equipe/i.test(t))g['Área']=1;
 if(/Alcance/i.test(t)&&!/sem Alcance/i.test(t))g.Alcance=1;if(/(^|[^\wÀ-ú])Ágil/.test(t))g['Ágil']=1;if(/Grátis/i.test(t))g['Grátis']=1;if(/Dreno|cura metade do dano/i.test(t))g.Dreno=1;
 const rc=t.match(/Recompra\s*\+?(\d+)/i);if(rc)g.Recompra=+rc[1];const gi=t.match(/gera\s*(\d+)\s*INI/i);if(gi)g.Recompra=(g.Recompra||0)+ +gi[1];
 const cp=t.match(/Comprar\s*(\d+)?/i);if(cp)g.Comprar=+(cp[1]||1);if(/Compra todas/i.test(t))g.Comprar=2;
 const cu=t.match(/cura\s*(\d+)\s*%/i);if(cu)g.Cura=+cu[1];else if(/\bcura\b|regenera/i.test(t))g.Cura=10;
 if(/\binvoca\b/i.test(t))g.Invocar=1;if(/transforma no monstro/i.test(t))g.Transformar=1;
 const cg=t.match(/Carregamento\s*(\d+)/i);if(cg)g.Carregamento=+cg[1];if(/\bFinal\b/.test(t))g.Final=1;if(/Requer|Escuridão \d\+/i.test(t))g.Requisito=1;
 const ini=t.match(/(?<![+\w]\s?)(\d+)\s*INI(?!\s*\))/);if(ini&&!/gera\s*\d+\s*INI/.test(ini.input.slice(Math.max(0,ini.index-5),ini.index+6)))g.INI=+ini[1];
 const ex=[...t.matchAll(/(?:contra|se (?:o alvo )?(?:estiver )?|consome )(\w+)/gi)].map(m=>ALIAS[m[1]]||m[1]).filter(w=>ST.includes(w));ex.forEach(w=>g['explora:'+w]=1);
 return Object.entries(g).map(([k,v])=>v===1&&!['dano','INI'].includes(k)?k:k+':'+v).join(', ')}
function tags(s){const o={};String(s||'').split(',').map(x=>x.trim()).filter(Boolean).forEach(x=>{const i=x.lastIndexOf(':');let k=x,v=1;if(i>0&&!isNaN(+x.slice(i+1))){k=x.slice(0,i).trim();v=+x.slice(i+1)}o[k]=v});return o}
const AT=['VID','IMP','POD','ARM','ESC'];
const DEFW={DP:{...DP},WP:{...WP},PR:{...PR},MP:{...MP}};
const MORAL={'-2':'maligno','-1':'caótico','0':'neutro','1':'leal','2':'bondoso'};
const DRAFT_KEY='hotn3_entities_draft_v1';
const E=s=>String(s??'').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;');
const f1=x=>(Math.round(x*10)/10).toLocaleString('pt-BR'),f0=x=>Math.round(x).toLocaleString('pt-BR');
const AD=v=>/a definir|a confirmar|^$/.test(String(v??''));
const vida=v=>3*(+v||0)+10;
const slug=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,'');
let dzSel=null;
function root(){if(!catalog.design)catalog.design={format:1,weights:structuredClone(DEFW),glossary:[],open_questions:[],characters:{}};const d=catalog.design;
 d.weights=d.weights||{};for(const k in DEFW)d.weights[k]={...DEFW[k],...(d.weights[k]||{})};d.glossary=d.glossary||[];d.open_questions=d.open_questions||[];d.characters=d.characters||{};return d}
function W(){return root().weights}
function entries(){const r=[];for(const h of Object.values(catalog.heroes||{}))r.push({key:'h:'+h.id,label:(h.name||h.id)+(h.design?(h.design.draft?' · ficha (rascunho)':' · ficha'):''),hero:h,d:h.design||null});
 r.sort((a,b)=>a.label.localeCompare(b.label));
 for(const[k,d]of Object.entries(root().characters))r.push({key:'d:'+k,label:(d.name||k)+' · só design'+(d.summoned_by?' (invocação)':''),hero:null,d});return r}
function entry(key){return entries().find(e=>e.key===key)}
function markDirty(e){if(e&&e.hero&&typeof dirtyHeroIds!=='undefined')dirtyHeroIds.add(e.hero.id);saveDraftSoon()}
let dt=null;function saveDraftSoon(){clearTimeout(dt);dt=setTimeout(saveDraft,600)}
function saveDraft(){try{localStorage.setItem(DRAFT_KEY,JSON.stringify({ts:Date.now(),data:catalog}));showDraftBtn()}catch(e){console.warn('draft',e)}}
function showDraftBtn(){const b=document.getElementById('btnDraft');if(!b)return;let raw=null;try{raw=localStorage.getItem(DRAFT_KEY)}catch(e){}
 if(!raw){b.classList.add('hidden');return}const j=JSON.parse(raw);b.classList.remove('hidden');b.textContent='Rascunho local '+new Date(j.ts).toLocaleString('pt-BR',{dateStyle:'short',timeStyle:'short'})}
window.dzRestoreDraft=function(){const j=JSON.parse(localStorage.getItem(DRAFT_KEY)||'null');if(!j)return;
 const a=prompt('Rascunho local (catálogo inteiro). Digite R para restaurar, A para apagar.','R');if(!a)return;
 if(/^a/i.test(a)){localStorage.removeItem(DRAFT_KEY);showDraftBtn();toast('Rascunho apagado');return}
 applyCatalog(j.data,'rascunho local');toast('Rascunho restaurado — exporte entities.json para gravar')};
function fromStats(h){return{VID:Math.round(((+h.hp||10)-10)/3),IMP:+h.attack||0,POD:+h.power||0,ARM:+h.armor||0,ESC:+h.escudo||0}}
function newDesign(name,h){return{draft:true,name,tipo:h?'Herói':'Invocação',ordem:'',attributes:h?fromStats(h):{VID:30,IMP:30,POD:30,ARM:30,ESC:30},moral:'',
 aprimoramento:{nome:h&&h.aprimoramento||'',efeito:'',vr:'',rod:''},desvantagem:{nome:'',efeito:'',instantanea:true},deck:[],arma:null,transformar:null,monster:null,notes:'',flag:h?'Atributos derivados da escala antiga (VID=(hp−10)/3)':'',suggestions:{}}}
const get=(o,p)=>p.split('.').reduce((x,k)=>x==null?x:x[k],o);
function set(o,p,v){const ks=p.split('.'),l=ks.pop();let x=o;for(const k of ks){if(x[k]==null)x[k]={};x=x[k]}x[l]=v}
// ---------- FICHA ----------
function fld(d,p,lab,ta,extra){const v=get(d,p)??'',sv=(d.suggestions||{})[p],c=(/\.mais$|tags$|ordem$|notes$/.test(p)?/a definir|a confirmar/i.test(String(v)):AD(v))?' ad':'';
 const sh=sv!=null&&String(v)!==String(sv)?`<div class="dz-sug"><button class="btn" data-acc="${E(p)}">Aceitar</button> <b>Sugestão:</b> ${E(sv)}</div>`:'';
 return `<label class="dz-f ${extra||''}"><span>${lab}</span>${ta?`<textarea class="${c}" data-dp="${E(p)}">${E(v)}</textarea>`:`<input class="${c}" data-dp="${E(p)}" value="${E(v)}">`}${sh}</label>`}
function attrs(d,p,lab){const o=get(d,p)||{};return `<div class="dz-sub">${lab}</div><div class="dz-attrs">${AT.map(a=>`<label><span>${a}</span><input type="number" inputmode="numeric" data-dp="${p}.${a}" data-num="1" value="${E(o[a])}"></label>`).join('')}<div class="dz-hp"><b data-hp="${p}">${vida(o.VID)}</b><small>Vida (3×VID+10)</small></div></div>`}
function manList(d,p,lab){const L=get(d,p)||[];return `<div class="dz-sub">${lab} (${L.length}) <button class="btn" data-add="${p}">+ manobra</button></div>`+L.map((m,j)=>`<div class="dz-card">${fld(d,`${p}.${j}.nome`,'Nome')}${fld(d,`${p}.${j}.base`,'Base',1)}${fld(d,`${p}.${j}.mais`,'Melhorada (+)',1)}${fld(d,`${p}.${j}.tags`,'Tags de balanceamento (vazio = automático do texto)',0,'dz-small')}<button class="btn danger dz-del" data-del="${p}.${j}">Remover</button></div>`).join('')}
function one(d,p,lab){if(!get(d,p))return `<div class="dz-sub">${lab} <button class="btn" data-mk="${p}">Adicionar</button></div>`;return `<div class="dz-sub">${lab}</div><div class="dz-card">${fld(d,p+'.nome','Nome')}${fld(d,p+'.base','Base',1)}${fld(d,p+'.mais','Melhorada (+)',1)}</div>`}
function apdes(d,p,lab,isDes){return `<div class="dz-sub">${lab}</div><div class="dz-card">${fld(d,p+'.nome','Nome')}${fld(d,p+'.efeito','Efeito',1)}${isDes?`<label class="dz-chk"><input type="checkbox" data-dp="${p}.instantanea" data-bool="1" ${get(d,p+'.instantanea')?'checked':''}> Instantânea (dispara ao ser comprada)</label>${fld(d,p+'.tags','Tags de custo (vazio = automático)',0,'dz-small')}`:`<div class="dz-row">${fld(d,p+'.vr','Valor/rodada',0,'dz-small')}${fld(d,p+'.rod','Rodadas (vazio = padrão)',0,'dz-small')}</div>`}</div>`}
function renderFicha(){const box=document.getElementById('dzFicha');const all=entries();const only=document.getElementById('dzOnly')?.checked??true;
 const list=all.filter(e=>!only||e.d);if(!dzSel||!entry(dzSel))dzSel=(list.find(e=>e.hero&&e.hero.id==='ent_ragnar_kaiju'&&e.d)||list.find(e=>e.d)||list[0]||{}).key;const e=entry(dzSel);
 let h=`<div class="dz-bar"><select id="dzPick">${list.map(x=>`<option value="${E(x.key)}" ${x.key===dzSel?'selected':''}>${E(x.label)}</option>`).join('')}</select>
 <label class="dz-chk"><input type="checkbox" id="dzOnly" ${only?'checked':''}> só com ficha</label>
 <button class="btn" id="dzNew">Novo só-design</button></div>`;
 if(!e){box.innerHTML=h;return}
 const d=e.d;
 if(e.hero)h+=`<div class="dz-ref">Jogo (<code>${E(e.hero.id)}</code>): hp ${e.hero.hp} · IMP ${e.hero.attack} · POD ${e.hero.power} · ARM ${e.hero.armor} · ESC ${e.hero.escudo??'—'} · passiva <code>${E(e.hero.passive||'—')}</code> · ${(e.hero.pool||[]).length} cartas no pool. <span class="muted">Esses valores editam-se na aba Personagens; a ficha abaixo é o design (não muda o jogo).</span></div>`;
 if(!d){box.innerHTML=h+`<p>Sem ficha de design. <button class="btn primary" id="dzCreate">Criar ficha a partir dos atributos do jogo</button></p>`;wireFicha(e);return}
 const summ=d.summons&&d.summons.length?`<div class="dz-ref">Invoca: ${d.summons.map(k=>`<a href="#" data-go="d:${E(k)}">${E((root().characters[k]||{}).name||k)}</a>`).join(' · ')}</div>`:'';
 const by=d.summoned_by?`<div class="dz-ref">Invocada por: <a href="#" data-go="h:${E(d.summoned_by)}">${E((catalog.heroes[d.summoned_by]||{}).name||d.summoned_by)}</a></div>`:'';
 h+=`<div class="dz-grid"><section class="dz-col"><h3>${E(d.name)} <span class="dz-tag">${E(d.tipo)}</span>${d.draft?' <span class="dz-tag warn">rascunho — fora do jogo</span>':''}</h3>${summ}${by}
 <div class="dz-row">${fld(d,'name','Nome')}${fld(d,'tipo','Tipo')}<label class="dz-chk"><input type="checkbox" data-dp="draft" data-bool="1" ${d.draft?'checked':''}> Rascunho (não implementado)</label></div>
 ${d.flag?`<div class="dz-flag">⚑ ${E(d.flag)}</div>`:''}${fld(d,'ordem','Ordem dos atributos (maior → menor)')}
 ${attrs(d,'attributes',d.monster?'Atributos — forma humana':'Atributos')}
 <label class="dz-f"><span>Moral</span><select data-dp="moral" data-num="1">${['',-2,-1,0,1,2].map(v=>`<option value="${v}" ${String(d.moral)===String(v)?'selected':''}>${v===''?'— a definir':v+' '+MORAL[v]}</option>`).join('')}</select></label>
 ${apdes(d,'aprimoramento','Aprimoramento (único)')}${apdes(d,'desvantagem','Desvantagem',1)}
 ${fld(d,'notes','Notas',1)}</section><section class="dz-col">${manList(d,'deck','Deck / manobras')}${one(d,'arma','Arma (forma humana)')}${one(d,'transformar','Carta de Transformar')}`;
 if(d.monster){const p='monster';h+=`<h3>Forma monstro: ${E(d.monster.name)}</h3>${fld(d,'monster.name','Nome do monstro')}${attrs(d,'monster.attributes','Atributos — forma monstro')}${apdes(d,'monster.aprimoramento','Aprimoramento do monstro')}${apdes(d,'monster.desvantagem','Desvantagem do monstro',1)}${manList(d,'monster.manobras','Manobras do monstro')}`}
 else h+=`<p><button class="btn" id="dzMkMon">Adicionar forma monstro</button></p>`;
 h+=`<p class="dz-actions"><button class="btn danger" id="dzDelFicha">Apagar ficha</button></p></section></div>`;
 box.innerHTML=h;wireFicha(e)}
function wireFicha(e){const box=document.getElementById('dzFicha');
 box.querySelector('#dzPick').onchange=ev=>{dzSel=ev.target.value;renderFicha()};
 box.querySelector('#dzOnly').onchange=()=>renderFicha();
 box.querySelector('#dzNew').onclick=()=>{const n=prompt('Nome do personagem (só design, não entra no jogo):');if(!n)return;const k=slug(n);root().characters[k]=newDesign(n,null);dzSel='d:'+k;saveDraftSoon();renderFicha()};
 const c=box.querySelector('#dzCreate');if(c)c.onclick=()=>{e.hero.design=newDesign(e.hero.name||e.hero.id,e.hero);e.hero.design.draft=false;markDirty(e);renderFicha()};
 const m=box.querySelector('#dzMkMon');if(m)m.onclick=()=>{e.d.monster={name:'a definir',attributes:{VID:30,IMP:30,POD:30,ARM:30,ESC:30},aprimoramento:{nome:'',efeito:''},desvantagem:{nome:'',efeito:'',instantanea:true},manobras:[]};markDirty(e);renderFicha()};
 const dl=box.querySelector('#dzDelFicha');if(dl)dl.onclick=()=>{if(!confirm('Apagar a ficha de design de '+e.d.name+'?'))return;if(e.hero)delete e.hero.design;else delete root().characters[e.key.slice(2)];markDirty(e);dzSel=null;renderFicha()};
 box.onclick=ev=>{const t=ev.target,d=e.d;if(!d)return;let ch=0;
  if(t.dataset.go){ev.preventDefault();dzSel=t.dataset.go;document.getElementById('dzOnly').checked=false;renderFicha();return}
  if(t.dataset.acc){set(d,t.dataset.acc,d.suggestions[t.dataset.acc]);ch=1}
  if(t.dataset.add){const L=get(d,t.dataset.add)||[];L.push({nome:'Nova manobra',base:'',mais:''});set(d,t.dataset.add,L);ch=1}
  if(t.dataset.del){const p=t.dataset.del.split('.'),j=+p.pop(),L=get(d,p.join('.'));if(confirm('Remover '+(L[j].nome||'manobra')+'?')){L.splice(j,1);ch=1}}
  if(t.dataset.mk){set(d,t.dataset.mk,{nome:'',base:'',mais:''});ch=1}
  if(ch){markDirty(e);const y=scrollY;renderFicha();scrollTo(0,y)}};
 box.oninput=ev=>{const t=ev.target,p=t.dataset.dp;if(!p||!e.d)return;let v=t.dataset.bool?t.checked:t.value;if(t.dataset.num&&v!=='')v=+v;set(e.d,p,v);t.classList.toggle('ad',!t.dataset.bool&&AD(v));
  const hp=p.match(/^(.*)\.VID$/);if(hp){const b=box.querySelector(`[data-hp="${hp[1]}"]`);if(b)b.textContent=vida(v)}markDirty(e)};
 box.onchange=ev=>{if(ev.target.dataset.bool||ev.target.tagName==='SELECT')box.oninput(ev)}}
// ---------- BALANCEAMENTO ----------
const ST_PT={weak:'Fraco',marked:'Marcado',bleed:'Sangramento',stun:'Atordoado',bind:'Preso',wounded:'Ferido',slow:'Lento',conceal:'Oculto',strengthened:'Forte',resistente:'Resistente',protecao:'Proteção',taunted:'Provocação',fragil:'Frágil',confused:'Confuso',atento:'Atento',barrier:'Barreira',fast:'Rápido',voar:'Voo',flying:'Voo'};
const NEG=['weak','marked','bleed','stun','bind','wounded','slow','fragil','confused','taunted'];
function cardTags(c){const g={};const add=(k,v)=>{if(k)g[k]=(g[k]||0)+(+v||1)};
 for(const a of c.actions||[]){const op=a[0];if(/^hit/.test(op))add('dano',1);else if(op==='status'||op==='self_status')add(ST_PT[a[1]],/^\d+$/.test(a[2])?+a[2]:1);
  else if(op==='heal'||op==='heal_all'||op==='heal_missing_pct')add('Cura',10);else if(op==='full_heal')add('Cura',100);else if(/^draw/.test(op))add('Comprar',/^\d+$/.test(a[1])?+a[1]:1);
  else if(op==='push')add('Empurrar');else if(op==='pull')add('Puxar');else if(op==='chain')add('Sequência',+a[1]||1);else if(/^summon/.test(op))add('Invocar');
  else if(op==='barreira'||op==='barrier')add('Barreira',/^\d+$/.test(a[1])?+a[1]:5);else if(op==='taunt')add('Provocação');else if(op==='protecao')add('Proteção',+a[1]||1);
  else if(op==='resistente')add('Resistente',+a[1]||1);else if(op==='forte')add('Forte',+a[1]||1);else if(op==='rapido')add('Rápido',+a[1]||1);else if(op==='lifesteal'||op==='drain')add('Dreno');
  else if(op==='requires_self_status'||op==='when_stacks')g.Requisito=1;else if(op==='final')g.Final=1;else if(op==='free')g['Grátis']=1;else if(op==='quick')g['Ágil']=1}
 if(c.quick)g['Ágil']=1;if(c.final)g.Final=1;if(c.free)g['Grátis']=1;if(c.reach)g.Alcance=1;if(/ALL_ENEMIES|ROW/.test(c.target||'')&&g.dano)g['Área']=1;if(c.chain)g['Sequência']=Math.max(g['Sequência']||0,+c.chain||1);
 if(+c.cost)g.INI=+c.cost;return Object.entries(g).map(([k,v])=>v===1&&!['dano','INI'].includes(k)?k:k+':'+v).join(', ')}
function forms(){const out=[];for(const e of entries()){const d=e.d;
 if(d){const man=[...(d.deck||[]),...(d.arma?[d.arma]:[]),...(d.transformar?[d.transformar]:[])].map(m=>({nome:m.nome,texto:m.base,tags:m.tags||parse(m.base)}));
  const dsT=x=>x&&!/^Nenhuma/.test(x.nome||'')?(x.tags||parse(x.efeito).split(', ').filter(t=>!/^(Alcance|Grátis|Ágil|Requisito|INI)/.test(t)).join(', ')):'';
  out.push({id:d.name||e.key,key:e.key,forma:d.tipo||'',moral:d.moral??'',flag:d.flag||'',...(d.attributes||{}),man,ap:{vr:get(d,'aprimoramento.vr'),rod:get(d,'aprimoramento.rod')},des:{tags:dsT(d.desvantagem)},hasD:1});
  if(d.monster&&d.monster.attributes){const M=d.monster;out.push({id:(d.name||'')+' ('+M.name+')',key:e.key,forma:'Monstro',moral:d.moral??'',flag:'',...M.attributes,man:(M.manobras||[]).map(m=>({nome:m.nome,texto:m.base,tags:m.tags||parse(m.base)})),ap:{vr:get(M,'aprimoramento.vr'),rod:get(M,'aprimoramento.rod')},des:{tags:dsT(M.desvantagem)},hasD:1})}}
 else if(e.hero){const h=e.hero,cs=(h.pool||h.cards||[]).map(id=>catalog.cards[id]).filter(Boolean);
  out.push({id:h.name||h.id,key:e.key,forma:'Herói (jogo)',moral:'',flag:'escala antiga (derivado do jogo)',...fromStats(h),man:cs.map(c=>({nome:c.name,texto:c.text||'',tags:cardTags(c)})),ap:{vr:'',rod:''},des:{tags:''},hasD:0})}}
 return out}
function best(c){return (+c.IMP||0)>=(+c.POD||0)?['IMP','ARM']:['POD','ESC']}
const dano=(a,d,m)=>{a=+a||0;d=+d||0;return a<=0?0:(m??W().DP.mult)*a*a/(a+d)};
function attrScore(c){const w=W().WP,i=+c.IMP||0,p=+c.POD||0,v=+c.VID||0,atk=Math.max(i,p)**2+w.w2*Math.min(i,p)**2,def=w.wARM*v*(+c.ARM||0)+w.wESC*v*(+c.ESC||0);return{atk,def,tot:atk+def,norm:(atk+def)/w.ref*w.pAttr}}
function manVal(m,c){const g=tags(m.tags),P=W().PR,MPw=W().MP;let dv=(g.dano||0)*P.dano,base=dv;
 for(const[k,v]of Object.entries(g)){if(k=='dano'||k=='INI'||k.startsWith('explora:')||['Carregamento','Final','Requisito'].includes(k))continue;base+=MULT.includes(k)?v*(P[k]||0)*dv:v*(P[k]||0)}
 let val=base/Math.max(1,g.INI||0);if(g.Carregamento)val*=MPw.carregamento**g.Carregamento;if(g.Final)val*=MPw.final;if(g.Requisito)val*=MPw.requisito;
 let sin=0;Object.keys(g).filter(k=>k.startsWith('explora:')).forEach(k=>{const s=k.slice(8);if(c.man.some(o=>o!==m&&tags(o.tags)[s]))sin+=W().WP.sin});return{val:val+sin,sin,dv,ini:g.INI||0}}
function charScore(c){const w=W().WP,a=attrScore(c),mv=c.man.map(m=>manVal(m,c).val),man=mv.length?mv.reduce((x,y)=>x+y)/mv.length:0;
 const rod=c.ap.rod===''||c.ap.rod==null?w.rodadas:+c.ap.rod,ap=(+c.ap.vr||0)*rod;const g=tags(c.des.tags);let dc=0;
 for(const[k,v]of Object.entries(g)){if(k=='INI'||k.startsWith('explora'))continue;dc+=v*(W().PR[k]||0)*(MULT.includes(k)?W().PR.dano:1)}
 const ch=Math.min(1,w.rodadas*w.compras/Math.max(1,w.deck)),des=dc*ch;return{a,man,ap,des,dc,ch,tot:a.norm+w.pMan*man+w.pAp*ap-w.pDes*des}}
function cls(h){const d=Math.abs(h-W().DP.alvo);return d<=1?'h1':d<=2?'h2':'h3'}
function num(path,v,lab){return `<label>${lab}<input class="n" type="number" step="any" inputmode="decimal" data-w="${path}" value="${v}"></label>`}
function renderBal(){const box=document.getElementById('dzBal');const w=W();
 box.innerHTML=`<div class="dz-bar"><label class="dz-chk"><input type="checkbox" id="dzBalOnly" ${box.dataset.only!=='0'?'checked':''}> Matriz/ranking só com ficha de design</label><button class="btn" id="dzCsv">Exportar CSV</button><button class="btn" id="dzWReset">Pesos padrão</button></div>
 <section class="dz-sec"><h3>Ranking</h3><p class="muted">Total = Atributos(normalizado)×peso + média das manobras×peso + Aprimoramento×peso − Desvantagem×peso. Heróis sem ficha usam atributos do jogo (escala antiga) e tags derivadas das ações das cartas.</p><div class="dz-scroll" id="dzRk"></div></section>
 <section class="dz-sec"><h3>Fórmula de dano</h3><p>Código hoje: <code>Dano = carta + Atributo − Defesa</code> (IMP×ARM, POD×ESC). Proposta: <code>Dano = CartaMult × Atk² ÷ (Atk + Def)</code>.</p><div class="dz-params">${num('DP.mult',w.DP.mult,'CartaMult médio')+num('DP.alvo',w.DP.alvo,'Golpes alvo')}</div><div class="dz-scroll" id="dzChk"></div></section>
 <section class="dz-sec"><h3>Golpes para derrubar</h3><p class="muted">Linha = atacante (maior entre IMP/POD), coluna = defensor. Verde ≈ alvo.</p><div class="dz-scroll" id="dzGm"></div></section>
 <section class="dz-sec"><h3>Score de atributos</h3><div class="dz-scroll" id="dzAt"></div></section>
 <section class="dz-sec"><h3>Pesos e preços <span class="muted">(gravados em entities.json → design.weights)</span></h3>
 <div class="dz-params">${[['w2','w₂ (2º ataque)'],['wARM','peso VID×ARM'],['wESC','peso VID×ESC'],['ref','Ref. atributos'],['pAttr','Pontos p/ ref.'],['pMan','Peso manobras'],['pAp','Peso aprimoramento'],['pDes','Peso desvantagem'],['rodadas','Rodadas esperadas'],['compras','Compras/rodada'],['deck','Tamanho do deck'],['sin','Bônus de sinergia']].map(([k,l])=>num('WP.'+k,w.WP[k],l)).join('')}</div>
 <h4>Efeitos</h4><div class="dz-params">${Object.keys(w.PR).map(k=>num('PR.'+k,w.PR[k],PRN[k]||k)).join('')}</div>
 <h4>Modificadores</h4><div class="dz-params">${num('MP.carregamento',w.MP.carregamento,'Carregamento (^N)')+num('MP.final',w.MP.final,'Final')+num('MP.requisito',w.MP.requisito,'Requisito')}</div></section>`;
 box.querySelector('#dzBalOnly').onchange=ev=>{box.dataset.only=ev.target.checked?'1':'0';calcBal()};
 box.querySelector('#dzCsv').onclick=csv;box.querySelector('#dzWReset').onclick=()=>{if(confirm('Voltar todos os pesos ao padrão?')){root().weights=structuredClone(DEFW);saveDraftSoon();renderBal()}};
 box.oninput=ev=>{const p=ev.target.dataset.w;if(!p)return;const[a,b]=p.split('.');W()[a][b]=ev.target.value===''?0:+ev.target.value;saveDraftSoon();calcBal()};calcBal()}
function calcBal(){const box=document.getElementById('dzBal');const only=box.dataset.only!=='0';const all=forms().map(c=>({c,s:charScore(c)}));const S=only?all.filter(x=>x.c.hasD):all;const mx=Math.max(...S.map(x=>x.s.tot),1);
 box.querySelector('#dzRk').innerHTML=`<table class="dz-t"><tr><th>#</th><th class="l">Personagem</th><th>Forma</th><th>Moral</th><th>Atrib.</th><th>Manobras</th><th>Aprim.</th><th>Desv.</th><th>Total</th><th class="l dz-hide-s"></th></tr>`+[...S].sort((x,y)=>y.s.tot-x.s.tot).map((x,i)=>`<tr><td>${i+1}</td><td class="l">${E(x.c.id)}${/antiga/.test(x.c.flag)?' <span class="dz-flag">⚑</span>':''}</td><td>${E(x.c.forma)}</td><td>${x.c.moral===''?'—':x.c.moral}</td><td>${f1(x.s.a.norm)}</td><td>${f1(x.s.man)}</td><td>${f1(x.s.ap)}</td><td>${f1(x.s.des)}</td><td><b>${f1(x.s.tot)}</b></td><td class="l dz-hide-s" style="min-width:80px"><div class="dz-barv" style="width:${Math.max(0,x.s.tot/mx*100)}%"></div></td></tr>`).join('')+'</table><p class="muted">⚑ = escala antiga (VID derivado de (hp−10)÷3).</p>';
 const ck=[[40,40,40],[30,30,30],[60,60,60],[80,80,80],[40,80,40],[80,40,80],[20,20,20]];
 box.querySelector('#dzChk').innerHTML=`<table class="dz-t"><tr><th>Atk</th><th>Def</th><th>VID</th><th>Dano proposto</th><th>Vida</th><th>Golpes</th><th>Código (carta 30)</th><th>Golpes código</th></tr>`+ck.map(([a,d,v])=>{const x=dano(a,d),o=Math.max(1,a+30-d);return`<tr><td>${a}</td><td>${d}</td><td>${v}</td><td>${f1(x)}</td><td>${vida(v)}</td><td class="${cls(vida(v)/x)}">${f1(vida(v)/x)}</td><td>${o}</td><td>${f1(vida(v)/o)}</td></tr>`}).join('')+'</table>';
 const G=S.slice(0,40);box.querySelector('#dzGm').innerHTML=(S.length>40?'<p class="muted">Mostrando 40 primeiros.</p>':'')+`<table class="dz-t"><tr><th class="l">Atk ↓ / Def →</th>${G.map(({c})=>`<th title="${E(c.id)}">${E(c.id.slice(0,10))}</th>`).join('')}</tr>`+G.map(({c:a})=>{const[s,d]=best(a);return`<tr><th class="l">${E(a.id)} <span class="muted">${s}</span></th>`+G.map(({c:b})=>{const x=dano(a[s],b[d]),h=x>0?Math.ceil(vida(b.VID)/x):'∞';return`<td class="${x>0?cls(h):'h3'}" title="${f1(x)} dano">${h}</td>`}).join('')+'</tr>'}).join('')+'</table>';
 box.querySelector('#dzAt').innerHTML=`<table class="dz-t"><tr><th class="l">Personagem</th>${AT.map(a=>`<th>${a}</th>`).join('')}<th>Vida</th><th>Ataque</th><th>Defesa</th><th>Norm.</th></tr>`+S.map(({c,s})=>`<tr><td class="l">${E(c.id)}</td>${AT.map(a=>`<td>${c[a]??''}</td>`).join('')}<td>${vida(c.VID)}</td><td>${f0(s.a.atk)}</td><td>${f0(s.a.def)}</td><td>${f1(s.a.norm)}</td></tr>`).join('')+'</table>'}
function csv(){const q=v=>'"'+String(v??'').replace(/"/g,'""')+'"',L=[['Personagem','Forma','Moral',...AT,'Vida','Atributos','Manobras','Aprimoramento','Desvantagem','Total','Aviso'].map(q).join(';')];
 const F=forms();F.forEach(c=>{const s=charScore(c);L.push([c.id,c.forma,c.moral,...AT.map(a=>c[a]),vida(c.VID),s.a.norm.toFixed(1),s.man.toFixed(1),s.ap.toFixed(1),s.des.toFixed(1),s.tot.toFixed(1),c.flag].map(q).join(';'))});
 L.push('');L.push(['Personagem','Manobra','Texto','Tags','Valor'].map(q).join(';'));F.forEach(c=>c.man.forEach(m=>L.push([c.id,m.nome,m.texto,m.tags,manVal(m,c).val.toFixed(1)].map(q).join(';'))));
 download('balance_score.csv','\ufeff'+L.join('\r\n'),'text/csv')}
// ---------- GLOSSÁRIO ----------
function renderGloss(){const box=document.getElementById('dzGloss'),g=root().glossary;
 box.innerHTML=`<div class="dz-bar"><button class="btn" id="dzGAdd">+ termo</button><span class="muted">Glossário de design (Carregamento, Ágil, Sequência, Vorpal…). As regras de efeitos do código ficam na aba Dicionário.</span></div>
 <div class="dz-gl">${g.map((x,i)=>`<div class="dz-card"><label class="dz-f"><span>Termo</span><input data-g="${i}.termo" class="${AD(x.termo)?'ad':''}" value="${E(x.termo)}"></label><label class="dz-f"><span>Definição</span><textarea data-g="${i}.definicao" class="${AD(x.definicao)?'ad':''}">${E(x.definicao)}</textarea></label>${x.sugestao&&x.sugestao!==x.definicao?`<div class="dz-sug"><button class="btn" data-gacc="${i}">Aceitar</button> <b>Sugestão:</b> ${E(x.sugestao)}</div>`:''}<button class="btn danger dz-del" data-gdel="${i}">Remover</button></div>`).join('')}</div>
 <section class="dz-sec"><h3>Em aberto</h3><p class="muted">Uma pergunta por linha.</p><textarea id="dzOpen" rows="10" style="width:100%">${E(root().open_questions.join('\n'))}</textarea></section>`;
 box.querySelector('#dzGAdd').onclick=()=>{g.push({termo:'',definicao:''});saveDraftSoon();renderGloss()};
 box.onclick=ev=>{const t=ev.target;if(t.dataset.gacc){g[+t.dataset.gacc].definicao=g[+t.dataset.gacc].sugestao;saveDraftSoon();renderGloss()}if(t.dataset.gdel&&confirm('Remover termo?')){g.splice(+t.dataset.gdel,1);saveDraftSoon();renderGloss()}};
 box.oninput=ev=>{const t=ev.target;if(t.id==='dzOpen'){root().open_questions=t.value.split('\n').map(s=>s.trim()).filter(Boolean);saveDraftSoon();return}if(!t.dataset.g)return;const[i,k]=t.dataset.g.split('.');g[+i][k]=t.value;t.classList.toggle('ad',AD(t.value));saveDraftSoon()}}
// ---------- TAGS / EFEITOS ----------
function baseTier(c){if(c.tier!=='melhorada')return c.tier||'?';const o=catalog.cards[c.melhorada_de];return o?o.tier:'inicial'}
function isPlus(c){return c.tier==='melhorada'||!!c.melhorada_de||/\+$/.test(c.name||'')}
function keysOf(c){const k=new Set();for(const a of c.actions||[]){k.add('ação:'+a[0]);if(['status','self_status','bonus_status','requires_self_status','when_stacks'].includes(a[0])&&a[1])k.add('status:'+a[1]);if(a[0]==='when_stacks'&&a[3])k.add('ação:'+a[3])}
 for(const f of ['quick','chain','final','free','instant','exhaust','reach'])if(c[f])k.add('flag:'+f);k.add('alvo:'+c.target);k.add('atributo:'+c.stat);return[...k]}
function renderTags(){const box=document.getElementById('dzTags');const cards=Object.values(catalog.cards||{}).filter(c=>!c._editor_only);const CK=window.CODE_KEYS||{actions:[],statuses:[],literals:[],removed_statuses:[]};const lit=new Set(CK.literals);
 const M={};for(const c of cards)for(const k of keysOf(c)){const r=M[k]=M[k]||{n:0,base:0,plus:0,tiers:{},owners:{},cards:[]};r.n++;isPlus(c)?r.plus++:r.base++;const t=baseTier(c);r.tiers[t]=(r.tiers[t]||0)+1;r.owners[c.owner]=(r.owners[c.owner]||0)+1;r.cards.push(c)}
 const supported=k=>{const[t,v]=k.split(':');if(t==='ação'||t==='status')return lit.has(v)&&!(t==='status'&&CK.removed_statuses.includes(v));return true};
 const usedA=new Set(Object.keys(M).filter(k=>k.startsWith('ação:')).map(k=>k.slice(5))),usedS=new Set(Object.keys(M).filter(k=>k.startsWith('status:')).map(k=>k.slice(7)));
 const unusedA=CK.actions.filter(a=>!usedA.has(a)),unusedS=CK.statuses.filter(s=>!usedS.has(s));
 const filt=(box.dataset.f||'');const rows=Object.entries(M).filter(([k])=>!filt||k.includes(filt)).sort((a,b)=>b[1].n-a[1].n);
 const hn=id=>(catalog.heroes[id]||{}).name||id;
 let h=`<div class="dz-bar"><input id="dzTF" placeholder="filtrar (ex.: status:, ação:hit)" value="${E(filt)}"><span class="muted">${cards.length} cartas · ${Object.keys(M).length} chaves · lista do código: tools/_code_keys.json (grep do runtime)</span></div>
 <section class="dz-sec"><h3>Uso por chave</h3><p class="muted">Clique numa linha para ver as cartas. ⚠ órfã = usada por 0–1 carta; ✖ = usada em carta mas não encontrada no código.</p><div class="dz-scroll"><table class="dz-t" id="dzTT"><tr><th class="l">Chave</th><th>Cartas</th><th>Base</th><th>+</th><th>Inicial</th><th>Evoluída</th><th>Desvant.</th><th>Especial</th><th>Personagens</th><th class="l">Aviso</th></tr>${rows.map(([k,r])=>`<tr data-k="${E(k)}" class="dz-click"><td class="l"><code>${E(k)}</code></td><td>${r.n}</td><td>${r.base}</td><td>${r.plus}</td><td>${r.tiers.inicial||0}</td><td>${r.tiers.evoluida||0}</td><td>${r.tiers.desvantagem||0}</td><td>${r.tiers.especial||0}</td><td>${Object.keys(r.owners).length}</td><td class="l">${r.n<=1?'<span class="dz-flag">⚠ órfã</span> ':''}${supported(k)?'':'<span class="dz-bad">✖ sem suporte no código</span>'}</td></tr>`).join('')}</table></div><div id="dzTList"></div></section>
 <section class="dz-sec"><h3>No código, sem uso em cartas</h3><p><b>Ações (${unusedA.length}):</b> ${unusedA.map(x=>`<code>${E(x)}</code>`).join(' ')}</p><p><b>Status (${unusedS.length}):</b> ${unusedS.map(x=>`<code>${E(x)}</code>`).join(' ')}</p><p class="muted">Heurístico: inclui chaves de descrição/aliases internos.</p></section>`;
 h+=helpers(cards,hn);box.innerHTML=h;
 box.querySelector('#dzTF').onchange=ev=>{box.dataset.f=ev.target.value.trim();renderTags()};
 box.querySelector('#dzTT').onclick=ev=>{const tr=ev.target.closest('tr[data-k]');if(!tr)return;const r=M[tr.dataset.k];box.querySelector('#dzTList').innerHTML=`<h4>${E(tr.dataset.k)} — ${r.n} cartas</h4><ul class="dz-ul">${r.cards.map(c=>`<li><a href="#" data-card="${E(c.id)}">${E(c.name)}</a> <span class="muted">${E(hn(c.owner))} · ${E(c.tier)}</span></li>`).join('')}</ul>`;box.querySelector('#dzTList').scrollIntoView({block:'nearest'})};
 box.onclick=ev=>{const id=ev.target.dataset&&ev.target.dataset.card;if(id){ev.preventDefault();setMode('cards');loadCard(id)}}}
function helpers(cards,hn){const by={};for(const c of cards){(by[c.owner]=by[c.owner]||[]).push(c)}const P=W().PR;let h='';
 // INI
 h+=`<section class="dz-sec"><h3>INI por personagem</h3><div class="dz-scroll"><table class="dz-t"><tr><th class="l">Personagem</th><th>Cartas</th><th>Custo médio</th><th>Custo máx</th><th>Gera médio</th><th>Gera 0/1/2+</th></tr>${Object.entries(by).sort().map(([o,L])=>{const cs=L.map(c=>+c.cost||0),gs=L.map(c=>+c.gain||0),av=a=>a.reduce((x,y)=>x+y,0)/Math.max(1,a.length);return`<tr><td class="l">${E(hn(o))}</td><td>${L.length}</td><td>${f1(av(cs))}</td><td>${Math.max(...cs)}</td><td>${f1(av(gs))}</td><td>${gs.filter(g=>!g).length}/${gs.filter(g=>g==1).length}/${gs.filter(g=>g>=2).length}</td></tr>`}).join('')}</table></div></section>`;
 // price per card
 const vals=cards.map(c=>{const g=cardTags(c);const r=manVal({tags:g},{man:[]});return{c,val:r.val,dpi:r.dv/Math.max(1,r.ini)}});
 h+=`<section class="dz-sec"><h3>Valor médio por carta (tabela de preços)</h3><div class="dz-scroll"><table class="dz-t"><tr><th class="l">Personagem</th><th>Média</th><th>Mín</th><th>Máx</th></tr>${Object.entries(by).map(([o])=>{const v=vals.filter(x=>x.c.owner===o).map(x=>x.val);return[o,v]}).sort((a,b)=>b[1].reduce((x,y)=>x+y,0)/b[1].length-a[1].reduce((x,y)=>x+y,0)/a[1].length).map(([o,v])=>`<tr><td class="l">${E(hn(o))}</td><td>${f1(v.reduce((x,y)=>x+y,0)/v.length)}</td><td>${f1(Math.min(...v))}</td><td>${f1(Math.max(...v))}</td></tr>`).join('')}</table></div></section>`;
 const dm=vals.filter(x=>x.dpi>0).sort((a,b)=>b.dpi-a.dpi),n=Math.max(1,Math.round(dm.length*0.1)),li=L=>`<ul class="dz-ul">${L.map(x=>`<li><a href="#" data-card="${E(x.c.id)}">${E(x.c.name)}</a> <span class="muted">${E(hn(x.c.owner))} · ${f1(x.dpi)}/INI · ações ${E((x.c.actions||[]).map(a=>a[0]+(a[1]!=null?' '+a[1]:'')).join(', '))}</span></li>`).join('')}</ul>`;
 h+=`<section class="dz-sec"><h3>Dano por INI — outliers</h3><p class="muted">Dano em unidades de preço (${P.dano}/hit) ÷ máx(1, custo). ${dm.length} cartas com dano.</p><div class="dz-grid"><div><h4>Top 10%</h4>${li(dm.slice(0,n))}</div><div><h4>Base 10%</h4>${li(dm.slice(-n))}</div></div></section>`;
 // apply vs exploit
 const ap={},ex={},cu={};for(const c of cards)for(const a of c.actions||[]){const s=a[1];if(a[0]==='status'||a[0]==='self_status'){(ap[s]=ap[s]||new Set()).add(c.owner)}
  if(['when_stacks','requires_self_status','bonus_status','consume_bleed'].includes(a[0])){const k=a[0]==='consume_bleed'?'bleed':s;(ex[k]=ex[k]||new Set()).add(c.owner)}
  if(a[0]==='cure'||a[0]==='counter_effects'){const t=a.slice(1).filter(x=>NEG.includes(x));(t.length?t:['*']).forEach(k=>cu[k]=(cu[k]||0)+1)}
  if(c.counter_effects){(Array.isArray(c.counter_effects)?c.counter_effects:[c.counter_effects]).forEach(k=>cu[k]=(cu[k]||0)+1)}}
 const st=[...new Set([...Object.keys(ap),...Object.keys(ex)])].sort();const nm=s=>s?(ST_PT[s]?ST_PT[s]+' ('+s+')':s):'?';
 h+=`<section class="dz-sec"><h3>Aplica × explora</h3><div class="dz-scroll"><table class="dz-t"><tr><th class="l">Status</th><th class="l">Quem aplica</th><th class="l">Quem explora</th></tr>${st.map(s=>`<tr><td class="l">${E(nm(s))}</td><td class="l">${[...(ap[s]||[])].map(hn).map(E).join(', ')||'—'}</td><td class="l">${[...(ex[s]||[])].map(hn).map(E).join(', ')||'<span class="muted">ninguém</span>'}</td></tr>`).join('')}</table></div><p class="muted">Explora = when_stacks, requires_self_status, bonus_status, consume_bleed.</p></section>`;
 h+=`<section class="dz-sec"><h3>Cobertura de contra-medidas</h3><table class="dz-t"><tr><th class="l">Status negativo</th><th>Cartas que aplicam</th><th>Cartas que removem/cancelam</th></tr>${NEG.map(s=>{const n=cards.filter(c=>(c.actions||[]).some(a=>a[0]==='status'&&a[1]===s)).length;return`<tr><td class="l">${E(nm(s))}</td><td>${n}</td><td class="${(cu[s]||0)+(cu['*']||0)?'':'h3'}">${cu[s]||0}${cu['*']?' + '+cu['*']+' genéricas':''}</td></tr>`}).join('')}</table><p class="muted">"Genéricas" = cure/counter_effects sem status específico (removem qualquer negativo).</p></section>`;
 // attribute usage
 h+=`<section class="dz-sec"><h3>IMP × POD: cartas vs atributos</h3><div class="dz-scroll"><table class="dz-t"><tr><th class="l">Personagem</th><th>IMP (attack)</th><th>POD (power)</th><th>Cartas IMP</th><th>Cartas POD</th><th class="l">Aviso</th></tr>${Object.entries(by).sort().map(([o,L])=>{const hh=catalog.heroes[o]||{},i=L.filter(c=>c.stat==='attack'&&(c.actions||[]).some(a=>/^hit/.test(a[0]))).length,p=L.filter(c=>c.stat==='power'&&(c.actions||[]).some(a=>/^hit/.test(a[0]))).length,A=+hh.attack||0,B=+hh.power||0;
  let w='';if(B>A+4&&p===0&&i>0)w='POD alto, só cartas IMP';else if(A>B+4&&i===0&&p>0)w='IMP alto, só cartas POD';else if(i+p&&B>A+4&&p<i)w='POD maior mas maioria IMP';else if(i+p&&A>B+4&&i<p)w='IMP maior mas maioria POD';
  return`<tr><td class="l">${E(hn(o))}</td><td>${A||'—'}</td><td>${B||'—'}</td><td>${i}</td><td>${p}</td><td class="l">${w?`<span class="dz-flag">⚑ ${w}</span>`:''}</td></tr>`}).join('')}</table></div><p class="muted">Conta só cartas com ação de dano (hit*), pelo campo <code>stat</code>.</p></section>`;
 return h}
// ---------- LEGADO ----------
function importLegacy(data){if(data.PR&&data.chars){root().weights={DP:{...DEFW.DP,...data.DP},WP:{...DEFW.WP,...data.WP},PR:{...DEFW.PR,...data.PR},MP:{...DEFW.MP,...data.MP}};let n=0;
  for(const c of data.chars){const base=c.id.replace(/ \(.*\)$/,''),mon=/\(/.test(c.id);const e=entries().find(x=>x.d&&(x.d.name===base||(x.hero&&x.hero.name===base)));if(!e||!e.d)continue;const o=mon?e.d.monster:e.d;if(!o)continue;
   o.attributes=Object.fromEntries(AT.map(a=>[a,c[a]]));if(c.moral!==''&&c.moral!=null)e.d.moral=c.moral;o.aprimoramento.vr=c.ap.vr??'';o.aprimoramento.rod=c.ap.rod??'';markDirty(e);n++}
  toast('Balanceamento antigo importado: pesos + '+n+' formas');return true}
 if(data.chars&&data.chars[0]&&data.chars[0].attr){let n=0;for(const c of data.chars){let e=entries().find(x=>x.d&&x.d.name===c.id);if(!e)continue;const d=e.d,ap=x=>({...x}),dv=x=>({nome:x.nome,efeito:x.efeito,instantanea:!/^Nenhuma/.test(x.nome)});
   Object.assign(d,{tipo:c.tipo,ordem:c.ordem||'',attributes:c.attr,moral:c.moral??'',aprimoramento:{...d.aprimoramento,...ap(c.ap)},desvantagem:dv(c.des),deck:c.deck||[],arma:c.arma||null,transformar:c.transf||null,notes:c.notas||''});
   if(c.monstro)d.monster={...(d.monster||{}),name:c.monstro,attributes:c.attrM||null,aprimoramento:{...((d.monster||{}).aprimoramento||{}),...c.apm},desvantagem:dv(c.desm),manobras:c.man||[]};markDirty(e);n++}
  if(data.gloss)root().glossary=data.gloss.map(g=>({termo:g[0],definicao:g[1]}));if(data.open)root().open_questions=data.open;toast('Ragnar antigo importado: '+n+' personagens');return true}
 return false}
window.dzImportLegacy=d=>{const ok=importLegacy(d);if(ok)dzRefresh();return ok};
function dzRefresh(){if(mode==='ficha')renderFicha();if(mode==='bal')renderBal();if(mode==='gloss')renderGloss();if(mode==='tags')renderTags()}
window.dzRender=function(m){if(m==='ficha')renderFicha();if(m==='bal')renderBal();if(m==='gloss')renderGloss();if(m==='tags')renderTags()};
window.dzAfterLoad=function(){root();showDraftBtn();const hm=(location.hash.match(/mode=(\w+)/)||[])[1];if(hm&&hm!==mode){setTimeout(()=>setMode(hm),0)}else dzRefresh()};
window.dzEntry=entry;
window.addEventListener('beforeunload',()=>{if(typeof dirtyHeroIds!=='undefined'&&(dirtyHeroIds.size||dirtyIds.size))saveDraft()});
})();
/*DESIGN_MODULE_END*/
