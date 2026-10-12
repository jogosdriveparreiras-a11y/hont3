// One-shot: migra tools/ragnar_invocacoes.html + tools/balance_score.html para entities.json (bloco "design").
const fs=require('fs'),P='addons/hotn3_entities/entities.json';
const ent=JSON.parse(fs.readFileSync(P,'utf8'));
const rs=fs.readFileSync('tools/ragnar_invocacoes.html','utf8').split('\n')[35];
const code=rs.slice(rs.indexOf('DEF=')+4,rs.indexOf(';let D='));
let {DEF,SUG}=eval('(()=>{const DEF='+code.replace(/,SUG=/,';const SUG=')+';return {DEF,SUG}})()');
const F=x=>JSON.parse(JSON.stringify(x).replace(/Corrente/g,'Sequência').replace(/Vulnerável/g,'Frágil').replace(/Cegos? (\d)/g,'Fracos $1').replace(/Cego/g,'Fraco'));
DEF=F(DEF);SUG=F(SUG);
const bs=fs.readFileSync('tools/balance_score.html','utf8');
const SEED=eval(bs.match(/const SEED=(\[.*?\]);\n/s)[1]);
const W={};for(const k of ['PR','DP','WP','MP'])W[k]=eval('('+bs.match(new RegExp('(?:const |,)'+k+'=(\\{.*?\\})[,;]'))[1]+')');
const slug=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'_');
const KM={attr:'attributes',ap:'aprimoramento',des:'desvantagem',arma:'arma',transf:'transformar',deck:'deck',notas:'notes'};
const MM={attrM:'attributes',apm:'aprimoramento',desm:'desvantagem',man:'manobras',monstro:'name'};
function mapPath(rest){const [k,...r]=rest;if(MM[k])return ['monster',MM[k],...r].join('.');return [KM[k]||k,...r].join('.')}
const seedBy=Object.fromEntries(SEED.map(s=>[s.id,s]));
const ap=(o,s)=>({nome:o.nome,efeito:o.efeito,...(s&&s.ap?{vr:s.ap.vr??'',rod:s.ap.rod??''}:{})});
const dv=o=>({nome:o.nome,efeito:o.efeito,instantanea:!/^Nenhuma/.test(o.nome)});
const design={format:1,note:'Bloco de design (editor). Ignorado pelo jogo. Personagens só-design ficam em design.characters; heróis do jogo guardam o seu em heroes.<id>.design.',
 weights:W,glossary:DEF.gloss.map((g,i)=>({termo:g[0],definicao:g[1],...(SUG['gloss.'+i+'.1']?{sugestao:SUG['gloss.'+i+'.1']}:{})})),
 open_questions:DEF.open,characters:{}};
const summonKeys=[];
DEF.chars.forEach((c,i)=>{
 const hs=seedBy[c.id], ms=SEED.find(s=>s.id.startsWith(c.id+' (')) ;
 const d={draft:true,name:c.id,tipo:c.tipo,ordem:c.ordem||'',attributes:c.attr,moral:c.moral??'',
  aprimoramento:ap(c.ap,hs),desvantagem:dv(c.des),deck:c.deck||[],arma:c.arma||null,transformar:c.transf||null,
  monster:c.monstro?{name:c.monstro,attributes:c.attrM||null,aprimoramento:ap(c.apm,ms),desvantagem:dv(c.desm),manobras:c.man||[]}:null,
  notes:c.notas||'',flag:(hs&&hs.flag)||'',suggestions:{}};
 for(const [p,v] of Object.entries(SUG)){const s=p.split('.');if(s[0]=='chars'&&+s[1]===i)d.suggestions[mapPath(s.slice(2))]=v}
 if(c.id==='Ragnar'){d.summons=[];d.hero_id='ent_ragnar_kaiju';ent.heroes.ent_ragnar_kaiju.design=d;}
 else{const k=slug(c.id);d.summoned_by='ent_ragnar_kaiju';summonKeys.push(k);design.characters[k]=d}
});
ent.heroes.ent_ragnar_kaiju.design.summons=summonKeys;
for(const [sid,hid] of [['Alyssa Wine','ent_alyssa_wine'],['Marcell Wine','ent_marcell_wine']]){const s=seedBy[sid];
 ent.heroes[hid].design={draft:false,name:sid,tipo:'Herói',attributes:Object.fromEntries(['VID','IMP','POD','ARM','ESC'].map(a=>[a,s[a]])),moral:s.moral??'',
  aprimoramento:{nome:s.ap.nome,efeito:s.ap.texto,vr:s.ap.vr??'',rod:s.ap.rod??''},desvantagem:{nome:s.des.nome,efeito:s.des.texto,instantanea:true},
  deck:s.man.map(m=>({nome:m.nome,base:m.texto,mais:''})),monster:null,notes:'',flag:s.flag||'',suggestions:{}}}
ent.design=design;
fs.writeFileSync(P,JSON.stringify(ent,null,2)+'\n');
console.log('ok',summonKeys,Object.keys(SUG).length);
