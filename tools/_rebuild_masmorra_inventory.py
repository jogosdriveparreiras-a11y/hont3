#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rebuild adaptacao_masmorra2 inventory + patch HTML with Isabella Lancaster and missing elites."""
from __future__ import annotations
import json, re, html, shutil
from pathlib import Path
from datetime import datetime
from copy import deepcopy

TOOLS = Path('/workspace/hont3/tools')
SHOTS = Path('/workspace/hont3_shots')
HTML = TOOLS / 'adaptacao_masmorra2.html'
ENTS = json.loads(Path('/workspace/hont3/addons/hotn3_entities/entities.json').read_text(encoding='utf-8'))
ATT = Path('/home/box/agent-data/agents/88030de4-f59c-4796-a8ed-c3a3622f2121/attachments')
XLSX = Path('/workspace/masmorra2.xlsx')

SOURCES = {
    'xlsx': 'masmorra2.xlsx',
    'h4': 'HERORGASM 4 (DOCX 5e2e2179…)',
    'godot_a': 'HotN Godot Edition A (DOCX aa573632…)',
    'godot_b': 'HotN Mecânicas (DOCX 964fd7ef…)',
    'h5': 'HERORGASM 5 (DOCX e771f0d4…)',
}

def norm(s: str) -> str:
    s = (s or '').lower()
    for a, b in [('á','a'),('à','a'),('â','a'),('ã','a'),('é','e'),('ê','e'),('í','i'),
                 ('ó','o'),('ô','o'),('õ','o'),('ú','u'),('ç','c'),('’',"'"),('‘',"'")]:
        s = s.replace(a, b)
    return re.sub(r'[^a-z0-9]+', '', s)

HOTN3 = {}
for k, v in ENTS['heroes'].items():
    name = v.get('name') or k
    HOTN3[norm(name)] = name
    HOTN3[norm(name.split('(')[0].strip())] = name
    if not k.startswith('ent_minion_'):
        HOTN3[norm(k.replace('ent_',''))] = name
# aliases
for a, b in {
    'evelyn':'Evelyn Graves (Sombria)','evelyngraves':'Evelyn Graves (Sombria)','sombria':'Evelyn Graves (Sombria)',
    'techna':'Techna','delevingne':'Techna','taylor':'Taylor (Nave-Mãe)','taylorsnut':'Taylor (Nave-Mãe)',
    'navemae':'Taylor (Nave-Mãe)','konrad':'Konrad (Armagedom)','sicario':'Konrad (Armagedom)',
    'armagedom':'Konrad (Armagedom)','amargedom':'Konrad (Armagedom)','nero':'Nero','nerogranger':'Nero',
    'dominika':'Dominika Seur','dominikaseur':'Dominika Seur','alyssa':'Alyssa Wine','alyssawine':'Alyssa Wine',
    'madelyn':'Madelyn','espantalho':'Dr. Espantalho','drespantalho':'Dr. Espantalho',
}.items():
    HOTN3[a] = b

def in_hotn3(name: str, aliases=None) -> bool:
    if norm(name) in HOTN3: return True
    for a in (aliases or []):
        if norm(a) in HOTN3: return True
    # first token ≥4
    tok = re.split(r'[\s/(]', name)[0]
    if len(tok) >= 4 and norm(tok) in HOTN3: return True
    return False

def card(name, tipo='Manobra', efeitos='', classe='ATTACK', flags='—', note='proposta'):
    return {
        'name': name,
        'tipo': tipo,
        'carta_sugerida': name.rstrip('+') + ('+' if name.endswith('+') else ''),
        'classe': classe,
        'efeitos': efeitos,
        'flags': flags,
        'status': note,
    }

# ---------- extractors ----------
def extract_xlsx():
    import openpyxl
    wb = openpyxl.load_workbook(str(XLSX), data_only=True)
    counts = {}
    entities = {}

    # Lista de Personagens
    ws = wb['Lista de Personagens']
    lista = []
    for r in range(2, 23):
        name = ws.cell(r, 1).value
        if not name: continue
        alter = ws.cell(r, 2).value or ''
        lista.append({'name': str(name).strip(), 'alter': str(alter).strip() if alter else ''})
        key = norm(str(name))
        entities.setdefault(key, {
            'name': str(name).strip(), 'aliases': [], 'sources': [], 'role': 'playable',
            'alterego': str(alter).strip() if alter else '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        if alter:
            entities[key]['aliases'].append(str(alter).strip())
            entities[key]['alterego'] = str(alter).strip()
        if 'Lista de Personagens' not in entities[key]['sources']:
            entities[key]['sources'].append('xlsx:Lista de Personagens')
    counts['lista_personagens'] = len(lista)

    # Fichas 3 blocks
    ws = wb['Fichas 3']
    f3 = []
    r = 1
    while r <= (ws.max_row or 0):
        if ws.cell(r, 2).value == 'Personagem':
            pname = ws.cell(r, 3).value
            if not pname or str(pname) == 'TEMPLATE':
                r += 1; continue
            block = {'name': str(pname).strip(), 'row': r, 'alter': '', 'raca': '', 'vida': '', 'vel': '', 'manobras': []}
            for dr in range(0, 28):
                lab = ws.cell(r+dr, 2).value
                val = ws.cell(r+dr, 3).value
                if lab == 'Alterego' and val: block['alter'] = str(val).strip()
                if lab == 'Raça' and val: block['raca'] = str(val).strip()
                if lab == 'Vida' and val: block['vida'] = f"{val}" + (f" {ws.cell(r+dr,4).value}" if ws.cell(r+dr,4).value else '')
                if lab == 'Velocidade' and val: block['vel'] = f"{val}"
                # manobras in cols 6-7
                tipo = ws.cell(r+dr, 6).value
                mname = ws.cell(r+dr, 7).value
                efeitos = ws.cell(r+dr, 10).value
                if mname and tipo and str(tipo).startswith(('1-','2-','3-','4-')):
                    block['manobras'].append({
                        'nome': str(mname).strip(), 'tipo': str(tipo).strip(),
                        'efeitos': str(efeitos).strip() if efeitos else ''
                    })
            f3.append(block)
            key = norm(block['name'])
            # special: Isabel alter is Impura (next row often)
            if block['name'] == 'Isabel' and not block['alter']:
                # C168 was Impura in search
                block['alter'] = 'Impura'
            # Fix misaligned alters from overlapping blocks — prefer Lista
            ent = entities.setdefault(key, {
                'name': block['name'], 'aliases': [], 'sources': [], 'role': 'playable',
                'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
            })
            if block['alter'] and block['name'] == 'Isabel':
                ent['alterego'] = 'Impura'
                if 'Impura' not in ent['aliases']: ent['aliases'].append('Impura')
            if 'xlsx:Fichas 3' not in ent['sources']:
                ent['sources'].append('xlsx:Fichas 3')
            ent['stats'].update({k: v for k, v in {'raca': block['raca'], 'vida': block['vida'], 'velocidade': block['vel']}.items() if v})
            for m in block['manobras']:
                cls = 'ATTACK' if any(x in (m['efeitos']+m['nome']).lower() for x in ['impacto','poder','dano','garras','golpe']) else 'ESTADO'
                ent['suggested_cards'].append(card(m['nome'], m['tipo'], m['efeitos'], cls, note='proposta (Fichas 3)'))
            ent['kits'].append({'source': 'xlsx:Fichas 3', 'manobras': [m['nome'] for m in block['manobras']]})
        r += 1
    counts['fichas3_blocks'] = len(f3)

    # FICHAS - Manobras named sections
    ws = wb['FICHAS - Manobras']
    man_labels = []
    known = ['Hazel','Hibiki','Dusk',"Duz'Har",'Rapina','QP','Motzolop','Soren','Marshmallow','Merida','Asura','Techna','Alyssa','Dominika','Nero Granger','Konrad (Hero)','Paladino']
    for r in range(1, ws.max_row+1):
        v = ws.cell(r, 2).value
        if not isinstance(v, str): continue
        name = v.strip()
        if name.rstrip() in known or name in known:
            man_labels.append(name.rstrip())
            key = norm(name.replace('(Hero)','').strip())
            # Rapina -> Mary Ann, Asura -> Jun Genesis
            alias_map = {'rapina': 'maryann', 'asura': 'jungenesis', 'konradhero': 'konrad', 'nerogranger': 'nerogranger'}
            key = alias_map.get(key, key)
            display = {'rapina':'Mary Ann','asura':'Jun Genesis','konradhero':'Konrad','nerogranger':'Nero Granger'}.get(norm(name.replace('(Hero)','').strip()), name.replace('(Hero)','').strip())
            if key == 'rapina': display='Mary Ann'; key=norm('Mary Ann')
            if key == 'asura': display='Jun Genesis'; key=norm('Jun Genesis')
            if 'konrad' in key: display='Konrad'; key=norm('Konrad')
            ent = entities.setdefault(key, {
                'name': display, 'aliases': [], 'sources': [], 'role': 'playable',
                'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
            })
            if name.rstrip() in ('Rapina','Asura') and name.rstrip() not in ent['aliases']:
                ent['aliases'].append(name.rstrip())
            if 'xlsx:FICHAS - Manobras' not in ent['sources']:
                ent['sources'].append('xlsx:FICHAS - Manobras')
            # collect following manobras until next label
            mans = []
            for rr in range(r+1, min(r+40, ws.max_row+1)):
                vv = ws.cell(rr, 2).value
                if isinstance(vv, str) and vv.strip().rstrip() in known:
                    break
                if isinstance(vv, str) and vv.strip() and not vv.strip().startswith(('Pontos','Presença','Subir','PH','Armadura','Escudo')):
                    # take first segment before :
                    mname = vv.split(':')[0].strip()
                    if len(mname) < 60 and mname:
                        mans.append(mname)
                        efeito = vv.split(':',1)[1].strip() if ':' in vv else ''
                        ent['suggested_cards'].append(card(mname, 'Manobras', efeito, note='proposta (Manobras)'))
            if mans:
                ent['kits'].append({'source': 'xlsx:FICHAS - Manobras', 'manobras': mans})
    counts['manobras_labels'] = len(man_labels)

    # Inimigos
    ws = wb['Inimigos e Ajudantes']
    enemies = []
    for r in range(2, ws.max_row+1):
        name = ws.cell(r, 2).value
        if not name: continue
        name = str(name).strip()
        classe = ws.cell(r, 3).value
        vida = ws.cell(r, 5).value
        passos = ws.cell(r, 7).value
        m1 = ws.cell(r, 8).value
        m2 = ws.cell(r, 9).value
        enemies.append(name)
        key = norm(name)
        ent = entities.setdefault(key, {
            'name': name, 'aliases': [], 'sources': [], 'role': 'enemy',
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        ent['role'] = 'enemy'
        ent['stats'] = {'classe': classe, 'vida': vida, 'passos': passos}
        if 'xlsx:Inimigos e Ajudantes' not in ent['sources']:
            ent['sources'].append('xlsx:Inimigos e Ajudantes')
        for m in (m1, m2):
            if m:
                mname = str(m).split('(')[0].strip()
                ent['suggested_cards'].append(card(mname, str(classe or 'Inimigo'), str(m), note='proposta (inimigo)'))
    counts['inimigos_xlsx'] = len(enemies)
    return entities, counts


def extract_docx(entities, counts):
    from docx import Document

    # --- H4 ---
    doc = Document(str(ATT / '5e2e2179b86b2c8890e1992f06bf718e89d3daaa4d13b1fa0802b689034a798f.docx'))
    # race table names
    race_names = set()
    for row in doc.tables[0].rows[1:]:
        for ci in range(1, 5):
            cell = row.cells[ci].text
            for part in re.split(r'[|/]', cell):
                n = part.strip()
                if n and len(n) > 1:
                    race_names.add(n.split('(')[0].strip())
    counts['h4_race_table_names'] = len(race_names)
    for n in race_names:
        key = norm(n)
        # skip generic empty
        if not key: continue
        ent = entities.setdefault(key, {
            'name': n, 'aliases': [], 'sources': [], 'role': 'npc',
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        if 'docx:HERORGASM4/raça' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM4/raça')

    def parse_student_row(nivel_cell, body_cell):
        full = f"{nivel_cell} | {body_cell}"
        m = re.match(r'Nível\s+(\d+)', nivel_cell.strip(), re.I)
        nivel = int(m.group(1)) if m else None
        # name is first token of body before ·
        parts = re.split(r'\s*·\s*', body_cell)
        nome = parts[0].strip() if parts else ''
        # sometimes "Nome" only
        info = {'nivel': nivel, 'nome': nome, 'codinome': '', 'raca': '', 'alinhamento': '',
                'fraquezas': '', 'identidade': '', 'attrs': '', 'manobras': []}
        for p in parts[1:]:
            if p.startswith('Codinome:'): info['codinome'] = p.split(':',1)[1].strip()
            elif p.startswith('Raça:'): info['raca'] = p.split(':',1)[1].strip()
            elif p.startswith('Alinhamento:'): info['alinhamento'] = p.split(':',1)[1].strip()
            elif p.startswith('Fraquezas:'): info['fraquezas'] = p.split(':',1)[1].strip()
            elif p.startswith('Identidade:'): info['identidade'] = p.split(':',1)[1].strip()
        am = re.search(r'PRE\s*\d*\s*VID\s*[\d+]+\s*IMP\s*\d+\s*ARM\s*\d+\s*POD\s*\d+\s*ESC\s*\d+\s*VEL\s*\d+', body_cell)
        if am: info['attrs'] = am.group(0)
        if 'Manobras' in body_cell:
            after = body_cell.split('Manobras', 1)[1]
            # split by blank lines or known patterns Name:
            chunks = re.split(r'\n\n+', after)
            mans = []
            for ch in chunks:
                ch = ch.strip()
                if not ch: continue
                # first line as name
                first = ch.split('\n')[0].strip()
                # skip lore paragraphs that are very long without colon power pattern
                if re.match(r'^[A-ZÁÉÍÓÚÂÊÔÃÕÀÜa-záéíóúâêôãõàüç0-9][^.]{0,60}:', first) or len(first) < 80:
                    mname = first.split(':')[0].strip()
                    if mname and not mname.startswith('O ') and len(mname) < 70:
                        mans.append(mname)
                        if len(mans) >= 12: break
            # also · separated short ones
            if not mans:
                for chunk in re.split(r'\s*·\s*', after):
                    chunk = chunk.strip().split('\n')[0].strip()
                    if chunk and len(chunk) < 80 and not chunk.startswith(('Atributos','PRE','Participação')):
                        mans.append(chunk.split(':')[0].strip())
            info['manobras'] = mans
        return info

    h4_students = 0
    for row in doc.tables[2].rows:
        cells = [c.text.strip() for c in row.cells]
        info = parse_student_row(cells[0], cells[1])
        nome = info['nome']
        if not nome: continue
        # QP special
        if nome.startswith('QP'):
            nome = 'QP'
            info['codinome'] = info['codinome'] or 'Quatro Partes'
        h4_students += 1
        key = norm(nome)
        ent = entities.setdefault(key, {
            'name': nome, 'aliases': [], 'sources': [], 'role': 'playable',
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        ent['role'] = 'playable'
        if info['codinome']:
            ent['alterego'] = ent['alterego'] or info['codinome']
            if info['codinome'] not in ent['aliases']:
                ent['aliases'].append(info['codinome'])
        if 'docx:HERORGASM4/alunos' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM4/alunos')
        ent['stats'].update({k: v for k, v in {
            'nivel': info['nivel'], 'raca': info['raca'], 'alinhamento': info['alinhamento'],
            'fraquezas': info['fraquezas'], 'identidade': info['identidade'], 'attrs': info['attrs']
        }.items() if v})
        if info['manobras']:
            ent['kits'].append({'source': 'docx:HERORGASM4', 'manobras': info['manobras']})
            for m in info['manobras']:
                ent['suggested_cards'].append(card(m, 'DOCX', note='proposta (HERORGASM4)'))
    counts['h4_students'] = h4_students

    h4_villains = 0
    for row in doc.tables[3].rows:
        cells = [c.text.strip() for c in row.cells]
        info = parse_student_row(cells[0], cells[1])
        nome = info['nome']
        if not nome: continue
        h4_villains += 1
        key = norm(nome)
        ent = entities.setdefault(key, {
            'name': nome, 'aliases': [], 'sources': [], 'role': 'elite',
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        ent['role'] = 'elite'
        if info['codinome']:
            ent['alterego'] = ent['alterego'] or info['codinome']
            if info['codinome'] not in ent['aliases']:
                ent['aliases'].append(info['codinome'])
        if 'docx:HERORGASM4/vilões' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM4/vilões')
        ent['stats'].update({k: v for k, v in {
            'nivel': info['nivel'], 'raca': info['raca'], 'attrs': info['attrs']
        }.items() if v})
        if info['manobras']:
            ent['kits'].append({'source': 'docx:HERORGASM4/vilões', 'manobras': info['manobras']})
            for m in info['manobras']:
                ent['suggested_cards'].append(card(m, 'DOCX', note='proposta (HERORGASM4 vilão)'))
    counts['h4_villains'] = h4_villains

    # Isabel narrative mention (irmã do Maldito) — ensure linked
    for i, p in enumerate(doc.paragraphs):
        if p.text.strip() == 'Isabel' or 'conhece Isabel' in p.text:
            key = norm('Isabel')
            ent = entities.setdefault(key, {
                'name': 'Isabel', 'aliases': ['Impura'], 'sources': [], 'role': 'playable',
                'alterego': 'Impura', 'kits': [], 'stats': {}, 'suggested_cards': []
            })
            if 'docx:HERORGASM4/narrativa' not in ent['sources']:
                ent['sources'].append('docx:HERORGASM4/narrativa')
            if 'Impura' not in ent['aliases']:
                ent['aliases'].append('Impura')

    # --- Godot docs (Isabella) ---
    for label, fname in [('godot_a', 'aa57363272d6cfe4e21813b9bb22d0f45717218e7195795cde89f12143d1cabd.docx'),
                         ('godot_b', '964fd7effd2907e09d6322c602753058edf7c8e72f8eafc05debe19fe0d7684c.docx')]:
        doc = Document(str(ATT / fname))
        texts = [p.text.strip() for p in doc.paragraphs]
        counts[f'{label}_paras'] = len([t for t in texts if t])
        for i, t in enumerate(texts):
            if t == 'Isabella Lancaster':
                # parse block until next major section
                block = texts[i:i+20]
                key = norm('Isabella Lancaster')
                ent = entities.setdefault(key, {
                    'name': 'Isabella Lancaster', 'aliases': [], 'sources': [], 'role': 'playable',
                    'alterego': 'Aluna de Magia', 'kits': [], 'stats': {}, 'suggested_cards': []
                })
                ent['role'] = 'playable'
                ent['alterego'] = 'Aluna de Magia'
                if 'Aluna de Magia' not in ent['aliases']:
                    ent['aliases'].append('Aluna de Magia')
                src = f'docx:{SOURCES[label]}'
                if src not in ent['sources']:
                    ent['sources'].append(src)
                # stats line
                for line in block:
                    if line.startswith('VID '):
                        ent['stats']['attrs_pct'] = line
                    if line == 'Meio-Sangue':
                        ent['stats']['raca'] = 'Meio-Sangue'
                    if line.startswith('Nível'):
                        ent['stats']['nivel'] = line
                powers = []
                for line in block:
                    if 'Oral Irresistível' in line:
                        powers.append(('Oral Irresistível', 'Atordoado → stun', 'ESTADO'))
                    if 'Magia de Sangue' in line:
                        powers.append(('A Magia de Sangue', 'Crash e Difícil', 'ATTACK'))
                    if 'Oral Especialista' in line:
                        powers.append(('Oral Especialista', 'custo INI', 'ESTADO'))
                    if 'Oral Arrebatador' in line:
                        powers.append(('Oral Arrebatador', '+rounds ou área', 'ESTADO'))
                # skins / posturas
                skins = []
                if 'Fase Adulta' in block:
                    skins.append(('Fase Adulta', 'Postura/Skin: Buff maior parâmetros', 'POSTURA'))
                if 'Primeiro Ano' in block:
                    skins.append(('Primeiro Ano', 'Postura/Skin: Debuff parâmetros', 'POSTURA'))
                mans = [p[0] for p in powers]
                if mans:
                    ent['kits'] = [k for k in ent['kits'] if not k['source'].startswith('docx:HotN')]
                    ent['kits'].append({'source': src, 'manobras': mans + [s[0] for s in skins]})
                # rebuild suggested cards uniquely
                seen = set()
                new_cards = []
                for name, ef, cls in powers + skins:
                    if name in seen: continue
                    seen.add(name)
                    tipo = 'Postura' if cls == 'POSTURA' else 'Manobra'
                    new_cards.append(card(name, tipo, ef, cls if cls != 'POSTURA' else 'ESTADO', note='proposta (HotN Godot)'))
                # Desvantagem proposal
                new_cards.append(card('Sede de Sangue', 'Desvantagem', 'Após usar Magia de Sangue, recebe Frágil 1 ou perde Escudo', 'ESTADO', note='proposta'))
                # Melhoradas
                new_cards.append(card('Oral Irresistível+', 'Melhorada', 'Atordoado + alcance/área', 'ESTADO', note='proposta'))
                new_cards.append(card('A Magia de Sangue+', 'Melhorada', 'Crash/Difícil reforçado; custo INI ajustado', 'ATTACK', note='proposta'))
                ent['suggested_cards'] = new_cards
                # helpers listed nearby
                for helper in ('Yuina', 'Gakko Chikara'):
                    hk = norm(helper)
                    he = entities.setdefault(hk, {
                        'name': helper, 'aliases': [], 'sources': [], 'role': 'npc',
                        'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
                    })
                    if src not in he['sources']:
                        he['sources'].append(src)
                    he['stats']['note'] = 'Citado no cast HotN Godot junto a Isabella / Sombria (Ajudante)'
                    if not he['suggested_cards']:
                        he['suggested_cards'].append(card('(kit incompleto)', 'Manobra', 'sem poderes no DOCX', 'ESTADO', note='lacuna'))

    # --- H5 ---
    doc = Document(str(ATT / 'e771f0d4785dddd25968592f73c2036c3389cb12d72e28e92276fa0ecf2d99db.docx'))
    # Impura kit
    texts = [p.text.strip() for p in doc.paragraphs]
    for i, t in enumerate(texts):
        if t == 'Impura' and i < 580:
            kit_lines = []
            for j in range(i, min(i+30, len(texts))):
                if texts[j] and texts[j] not in ('Impura',):
                    if texts[j].startswith('__') or texts[j].startswith('Nas docas') or texts[j].startswith('Alcance é'):
                        break
                    kit_lines.append(texts[j])
            key = norm('Isabel')
            ent = entities.setdefault(key, {
                'name': 'Isabel', 'aliases': ['Impura'], 'sources': [], 'role': 'playable',
                'alterego': 'Impura', 'kits': [], 'stats': {}, 'suggested_cards': []
            })
            if 'Impura' not in ent['aliases']: ent['aliases'].append('Impura')
            ent['alterego'] = 'Impura'
            if 'docx:HERORGASM5/Impura' not in ent['sources']:
                ent['sources'].append('docx:HERORGASM5/Impura')
            # parse vida
            for ln in kit_lines:
                if ln.startswith('Vida:'):
                    ent['stats']['vida_h5'] = ln
                if 'Meio-Sangue' in ln:
                    ent['stats']['raca'] = 'Meio-Sangue'
                    ent['stats']['alinhamento'] = ln
            mans = []
            for ln in kit_lines:
                if ':' in ln and not ln.startswith('Vida'):
                    mans.append(ln.split(':')[0].strip())
                elif ln and len(ln) < 40 and ln[0].isupper() and '?' not in ln[:3]:
                    if ln not in ('Meio-Sangue, Neutra e Maligna',):
                        mans.append(ln)
            mans = [m for m in mans if m and m not in ('Arm?', 'Esc?', 'ERP?')]
            if mans:
                ent['kits'].append({'source': 'docx:HERORGASM5/Impura', 'manobras': mans})
                existing = {c['name'] for c in ent['suggested_cards']}
                for m in mans:
                    if m not in existing:
                        ent['suggested_cards'].append(card(m, 'DOCX H5', note='proposta (HERORGASM5)'))
            counts['h5_impura_lines'] = len(kit_lines)
            break

    # H5 enemy table
    h5_enemies = 0
    for row in doc.tables[0].rows[1:]:
        cells = [c.text.strip() for c in row.cells]
        if len(cells) < 5: continue
        tipo, nome, vida, passos, manobras = cells[0], cells[1], cells[2], cells[3], cells[4]
        if not nome: continue
        h5_enemies += 1
        key = norm(nome)
        ent = entities.setdefault(key, {
            'name': nome, 'aliases': [], 'sources': [], 'role': 'enemy',
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        ent['role'] = 'enemy' if 'Lacaio' in tipo or 'Lacaios' in tipo else 'elite'
        if 'docx:HERORGASM5/inimigos' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM5/inimigos')
        ent['stats'].update({'classe': tipo, 'vida': vida, 'passos': passos})
        for m in re.split(r'\n+', manobras):
            m = m.strip()
            if m:
                ent['suggested_cards'].append(card(m.split('(')[0].strip(), tipo, m, note='proposta (H5 inimigo)'))
    counts['h5_enemies_table'] = h5_enemies

    # H5 char tables (Alyssa, Evelyn, Techna, Konrad)
    for t in doc.tables[4:8]:
        if not t.rows: continue
        title = t.rows[0].cells[0].text.strip()
        if not title or '/' not in title: continue
        nome = title.split('/')[0].strip()
        alter = title.split('/')[1].strip()
        key = norm(nome)
        ent = entities.setdefault(key, {
            'name': nome, 'aliases': [], 'sources': [], 'role': 'playable',
            'alterego': alter, 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        if alter and alter not in ent['aliases']:
            ent['aliases'].append(alter)
        if 'docx:HERORGASM5/fichas' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM5/fichas')
    counts['h5_char_tables'] = 4

    # Narrative elites
    narrative = {
        'Bola de Ferro': {'role': 'elite', 'note': 'Elite; gangue vs Culto', 'cards': [
            card('Golpe de Ferro', 'Elite', 'Impacto pesado (proposta temática)', note='proposta'),
            card('Tortura', 'Elite', 'Aplica Ferido / Atordoado', note='proposta'),
        ]},
        'Samael': {'role': 'elite', 'note': 'Meio-Sangue serpente; servo de Brom Stikk', 'cards': [
            card('Forma Serpente', 'Elite', 'Transformação / área', note='proposta'),
            card('Investida', 'Elite', 'Impacto', note='proposta'),
        ]},
        'Bruxa': {'role': 'elite', 'note': 'Vampira nas docas (narrativa H5); também lacaio na planilha', 'cards': [
            card('Pedras', 'Elite', 'Poder / área', note='proposta'),
            card('Pele Vampírica', 'Passive', 'Resistente', note='proposta'),
        ]},
        'Haru': {'role': 'elite', 'note': 'Braço direito de Kevin; Caldo-Gama monstro', 'cards': [
            card('Caldo-Gama', 'Elite', 'Forte, Resistente, transformação', note='proposta'),
        ]},
        'Kevin': {'role': 'elite', 'note': 'Líder gangue / Caldo-Gama', 'cards': [
            card('(kit incompleto)', 'Elite', 'sem manobras explícitas', note='lacuna'),
        ]},
        'Madame Cascos': {'role': 'elite', 'note': 'Vilã; anéis / Caos', 'cards': [
            card('Arremesso', 'Elite', 'Impacto (carro/objetos)', note='proposta'),
        ]},
        'Mika Yamamoto': {'role': 'elite', 'note': 'Subchefe H5', 'cards': [
            card('Garras', 'Subchefe', 'Impacto 2, Repulsão 2', note='proposta (H5)'),
            card('Servos', 'Subchefe', 'Alcance 2, Guardião, Combo 1', note='proposta (H5)'),
        ]},
    }
    for nome, meta in narrative.items():
        key = norm(nome)
        ent = entities.setdefault(key, {
            'name': nome, 'aliases': [], 'sources': [], 'role': meta['role'],
            'alterego': '', 'kits': [], 'stats': {}, 'suggested_cards': []
        })
        if 'docx:HERORGASM5/narrativa' not in ent['sources'] and nome != 'Mika Yamamoto':
            # Mika already from table
            if nome == 'Mika Yamamoto':
                pass
            else:
                ent['sources'].append('docx:HERORGASM5/narrativa')
        elif nome != 'Mika Yamamoto' and 'docx:HERORGASM5/narrativa' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM5/narrativa')
        if nome != 'Mika Yamamoto' and 'docx:HERORGASM5/narrativa' not in ent['sources']:
            ent['sources'].append('docx:HERORGASM5/narrativa')
        ent['stats']['note'] = meta['note']
        if not ent['suggested_cards']:
            ent['suggested_cards'] = meta['cards']
        # ensure source for narrative ones
        if nome != 'Mika Yamamoto':
            if not any('narrativa' in s for s in ent['sources']):
                ent['sources'].append('docx:HERORGASM5/narrativa')
    counts['h5_narrative_elites'] = len(narrative)

    return entities, counts


def dedupe_cards(cards):
    seen = set()
    out = []
    for c in cards:
        k = norm(c['name'])
        if k in seen: continue
        seen.add(k)
        out.append(c)
    return out


def finalize(entities):
    # Critical: Isabel ≠ Isabella
    isabel = entities.get(norm('Isabel'))
    isabella = entities.get(norm('Isabella Lancaster'))
    assert isabel is not None or True
    if isabel and isabella:
        # ensure separate
        assert norm(isabel['name']) != norm(isabella['name'])
        isabel['aliases'] = [a for a in isabel['aliases'] if 'Isabella' not in a and 'Lancaster' not in a]
        if 'Impura' not in isabel['aliases']:
            isabel['aliases'].append('Impura')
        isabel['alterego'] = 'Impura'
        isabel['notes'] = 'PERSONAGEM SEPARADA de Isabella Lancaster. Isabel = Impura, líder do Culto, irmã de Danilo/Maldito.'
        isabella['notes'] = 'PERSONAGEM SEPARADA de Isabel/Impura. Isabella Lancaster = Aluna de Magia (HotN Godot), Meio-Sangue, magia de sangue / oral.'
        isabella['aliases'] = [a for a in isabella['aliases'] if a not in ('Impura', 'Isabel')]

    # Merge Methos/Paladino note but keep separate
    if norm('Methos') in entities and norm('Paladino') in entities:
        entities[norm('Methos')]['notes'] = entities.get(norm('Methos'), {}).get('notes', '') + ' Ambíguo: H4 dá a Methos o codinome Paladino; planilha lista ambos.'
        entities[norm('Paladino')]['notes'] = 'Entrada distinta na planilha; em H4 Paladino = codinome de Methos.'

    out = []
    for key, ent in entities.items():
        ent['aliases'] = sorted(set(a for a in ent['aliases'] if a and norm(a) != norm(ent['name'])))
        ent['sources'] = list(dict.fromkeys(ent['sources']))
        ent['suggested_cards'] = dedupe_cards(ent['suggested_cards'])
        ent['in_hotn3'] = in_hotn3(ent['name'], ent['aliases'])
        # drop empty noise entities from race table that are fragments
        if ent['name'] in ('', '—') or len(ent['name']) < 2:
            continue
        out.append({
            'name': ent['name'],
            'aliases': ent['aliases'],
            'sources': ent['sources'],
            'role': ent.get('role', 'npc'),
            'alterego': ent.get('alterego', ''),
            'stats': ent.get('stats', {}),
            'kits': ent.get('kits', []),
            'in_hotn3': ent['in_hotn3'],
            'suggested_cards': ent['suggested_cards'],
            'notes': ent.get('notes', ''),
        })
    out.sort(key=lambda e: (0 if e['name']=='Isabella Lancaster' else 1, e['name'].lower()))
    return out


ISABELLA_HTML = r'''
<section class="char" id="isabella-lancaster" data-char="Isabella Lancaster">
  <div class="char-toolbar-mini">
    <button type="button" class="btn-collapse" title="Recolher/expandir">▾</button>
    <span class="cat-badge">DOCX Godot · ausente HotN3 · ≠ Isabel/Impura</span>
  </div>
  <div class="char-body">
  <div class="char-head">
    <div class="identity">
      <h2 contenteditable="true">Isabella Lancaster</h2>
      <div class="alter" contenteditable="true">Alterego: Aluna de Magia · Raça: Meio-Sangue</div>
      <dl>
        <dt>Nível (DOCX)</dt><dd contenteditable="true">10</dd>
        <dt>Papel</dt><dd contenteditable="true">Aluna de Magia (cast HotN Godot)</dd>
        <dt>Atributos (%)</dt><dd contenteditable="true"><code>VID 75 · VIG 125 · IMP 75 · ARM 75 · POD 125 · ESC 125 · VEL 100 · PRE 125</code></dd>
        <dt>Fontes</dt><dd contenteditable="true">HotN Godot Edition (DOCX aa573632…) · HotN Mecânicas (DOCX 964fd7ef…) · <b>não</b> é Isabel/Impura</dd>
        <dt>Cartas (propostas)</dt><dd contenteditable="true">7</dd>
      </dl>
    </div>
    <div class="desv-box">
      <div class="label">Desvantagem (proposta)</div>
      <p contenteditable="true"><b>Sede de Sangue</b> — Após jogar <i>A Magia de Sangue</i>, recebe Frágil 1 ou perde 1 Escudo até o próximo turno.</p>
    </div>
  </div>
  <div class="note"><b>Separação obrigatória:</b> <b>Isabella Lancaster</b> ≠ <b>Isabel (Impura)</b>. Isabella é aluna de magia do cast Godot (magia de sangue / oral). Isabel/Impura é a líder do Culto (Fichas 3 + HERORGASM 5), irmã de Danilo/Maldito. <span class="chip gap">proposta</span></div>
  <div class="note"><b>Aprimoramento (proposta):</b> <b>Magia de Sangue</b> — buff de parâmetros em <i>Fase Adulta</i>; debuff em <i>Primeiro Ano</i>. Passiva: manobras Orals aplicam Atordoado com mais facilidade. <span class="chip gap">proposta</span></div>
  <h3 contenteditable="true">Manobra DOCX → carta HotN3 (proposta)</h3>
  <table class="map">
    <thead>
      <tr><th>Manobra (DOCX)</th><th>Tipo</th><th>Carta sugerida</th><th>Classe</th><th>Efeitos mapeados</th><th>Flags</th><th>Status</th></tr>
    </thead>
    <tbody>
      <tr>
        <td class="manobra" contenteditable="true">Oral Irresistível</td>
        <td contenteditable="true">1-Inicial</td>
        <td contenteditable="true">Oral Irresistível</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">status stun (Atordoado)</td>
        <td contenteditable="true">—</td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">A Magia de Sangue</td>
        <td contenteditable="true">1-Inicial</td>
        <td contenteditable="true">A Magia de Sangue</td>
        <td contenteditable="true"><span class="chip atk">ATTACK</span></td>
        <td contenteditable="true">Crash + Difícil (acerto/custo)</td>
        <td contenteditable="true"><code>difficult</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">Oral Especialista</td>
        <td contenteditable="true">2-Evoluída</td>
        <td contenteditable="true">Oral Especialista</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">reduz / ajusta custo INI</td>
        <td contenteditable="true"><code>ini</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">Oral Arrebatador</td>
        <td contenteditable="true">2-Evoluída</td>
        <td contenteditable="true">Oral Arrebatador</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">+rounds de Atordoado <b>ou</b> área</td>
        <td contenteditable="true"><code>area</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">Oral Irresistível+</td>
        <td contenteditable="true">3-Melhoria</td>
        <td contenteditable="true">Oral Irresistível+</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">stun + alcance/área</td>
        <td contenteditable="true"><code>reach</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">A Magia de Sangue+</td>
        <td contenteditable="true">3-Melhoria</td>
        <td contenteditable="true">A Magia de Sangue+</td>
        <td contenteditable="true"><span class="chip atk">ATTACK</span></td>
        <td contenteditable="true">Crash/Difícil reforçado</td>
        <td contenteditable="true"><code>difficult</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">Fase Adulta</td>
        <td contenteditable="true">Postura / Skin</td>
        <td contenteditable="true">Fase Adulta</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">Buff maior de parâmetros; remove Oral Irresistível da lista ativa (regra DOCX)</td>
        <td contenteditable="true"><code>postura</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
      <tr>
        <td class="manobra" contenteditable="true">Primeiro Ano</td>
        <td contenteditable="true">Postura / Skin</td>
        <td contenteditable="true">Primeiro Ano</td>
        <td contenteditable="true"><span class="chip est">ESTADO</span></td>
        <td contenteditable="true">Debuff de parâmetros (skin inicial)</td>
        <td contenteditable="true"><code>postura</code></td>
        <td contenteditable="true"><span class="chip gap">proposta</span></td>
      </tr>
    </tbody>
  </table>
  <div class="note docx-enrich" data-source="HotN Godot DOCX">
  <b>Fonte — HotN Godot (2 DOCX idênticos no bloco):</b> única ficha detalhada na seção Personagens desses anexos.
  <dl class="docx-dl">
    <dt>Nome</dt><dd contenteditable="true">Isabella Lancaster</dd>
    <dt>Papel</dt><dd contenteditable="true">Aluna de Magia</dd>
    <dt>Nível</dt><dd contenteditable="true">10</dd>
    <dt>Raça</dt><dd contenteditable="true">Meio-Sangue</dd>
    <dt>Atributos</dt><dd contenteditable="true"><code>VID 75 VIG 125 IMP 75 ARM 75 POD 125 ESC 125 VEL 100 PRE 125</code></dd>
    <dt>Cast relacionado</dt><dd contenteditable="true">Sombria (Ajudante listado) · Yuina · Gakko Chikara</dd>
  </dl>
  <div><b>Poderes (DOCX):</b>
    <ul class="compact">
      <li contenteditable="true">Oral Irresistível: Atordoado</li>
      <li contenteditable="true">A Magia de Sangue: Crash e Difícil</li>
      <li contenteditable="true">Oral Especialista: custo INI</li>
      <li contenteditable="true">Oral Arrebatador: +rounds ou área</li>
      <li contenteditable="true">Fase Adulta — Buff maior (− Oral Irresistível)</li>
      <li contenteditable="true">Primeiro Ano — Debuff Parâmetros</li>
    </ul>
  </div>
  </div>
  </div>
</section>
'''


def patch_html(inventory, counts):
    text = HTML.read_text(encoding='utf-8')

    # 1) TOC sticky off + not contenteditable
    text = text.replace('nav.toc {\n  background: var(--panel);\n  border: 1px solid var(--border);\n  border-radius: 12px;\n  padding: 14px 18px;\n  margin: 18px 0 28px;\n  position: sticky; top: 8px; z-index: 5;\n}',
                        'nav.toc {\n  background: var(--panel);\n  border: 1px solid var(--border);\n  border-radius: 12px;\n  padding: 14px 18px;\n  margin: 18px 0 28px;\n  /* TOC: não sticky, não editável */\n}')
    # fallback if whitespace differs
    text = re.sub(r'(nav\.toc\s*\{[^}]*?)position:\s*sticky;\s*top:\s*8px;\s*z-index:\s*5;',
                  r'\1/* TOC não sticky */', text, count=1, flags=re.S)
    # remove contenteditable from TOC <li>
    def toc_fix(m):
        block = m.group(0)
        block = block.replace(' contenteditable="true"', '')
        return block
    text = re.sub(r'<nav class="toc">.*?</nav>', toc_fix, text, count=1, flags=re.S)

    # 2) Insert Isabella TOC entry after Isabel
    if 'href="#isabella-lancaster"' not in text:
        text = text.replace(
            '<li><a href="#isabel">Isabel</a></li>',
            '<li><a href="#isabel">Isabel</a></li>\n    <li><a href="#isabella-lancaster">Isabella Lancaster</a></li>'
        )
        # in case contenteditable still there somehow
        text = text.replace(
            '<li contenteditable="true"><a href="#isabel">Isabel</a></li>',
            '<li><a href="#isabel">Isabel</a></li>\n    <li><a href="#isabella-lancaster">Isabella Lancaster</a></li>'
        )

    # 3) Insert Isabella section after Isabel section
    if 'id="isabella-lancaster"' not in text:
        text = text.replace(
            '</section>\n<section class="char" id="jun-genesis">',
            '</section>\n' + ISABELLA_HTML + '\n<section class="char" id="jun-genesis">'
        )

    # 4) Strengthen Isabel separation note
    if '≠ Isabella Lancaster' not in text:
        text = text.replace(
            '<div class="alter" contenteditable="true">Alterego: Impura · Raça: Meio-Sangue</div>',
            '<div class="alter" contenteditable="true">Alterego: Impura · Raça: Meio-Sangue · <b>≠ Isabella Lancaster</b></div>',
            1
        )
        text = text.replace(
            '<div class="note"><b>Aprimoramento (proposta):</b> <b>Impura / Atavus</b>',
            '<div class="note"><b>Separação:</b> Isabel/Impura (Culto, Fichas 3 + H5) é personagem distinta de <a href="#isabella-lancaster">Isabella Lancaster</a> (Aluna de Magia, DOCX Godot).</div>\n  <div class="note"><b>Aprimoramento (proposta):</b> <b>Impura / Atavus</b>',
            1
        )

    # 5) Update method with 5 sources + counts
    playable = [e for e in inventory if e['role'] in ('playable',) or e['name'] in (
        'Isabella Lancaster','Isabel','Methos','Paladino')]
    # better counts from inventory roles
    n_play = sum(1 for e in inventory if e['role'] == 'playable')
    n_elite = sum(1 for e in inventory if e['role'] == 'elite')
    n_enemy = sum(1 for e in inventory if e['role'] == 'enemy')
    n_npc = sum(1 for e in inventory if e['role'] == 'npc')
    n_hotn3 = sum(1 for e in inventory if e['in_hotn3'] and e['role'] == 'playable')
    n_aus = sum(1 for e in inventory if (not e['in_hotn3']) and e['role'] == 'playable')
    # sections in HTML approx
    total_doc = 8 + 33 + 1  # +Isabella

    method_extra = f'''
  <div class="note docx-enrich" id="fontes-5">
    <b>Atualização 2026-09-29 (rebuild completo · 5 fontes):</b>
    <ol class="compact">
      <li contenteditable="true"><b>1. masmorra2.xlsx</b> — Lista de Personagens ({counts.get('lista_personagens', '?')}), Fichas 3 ({counts.get('fichas3_blocks', '?')} blocos), FICHAS - Manobras ({counts.get('manobras_labels', '?')} rótulos), Inimigos e Ajudantes ({counts.get('inimigos_xlsx', '?')}).</li>
      <li contenteditable="true"><b>2. HERORGASM 4</b> — tabela de raças ({counts.get('h4_race_table_names', '?')} nomes), alunos ({counts.get('h4_students', '?')}), vilões ({counts.get('h4_villains', '?')}).</li>
      <li contenteditable="true"><b>3–4. HotN Godot / Mecânicas</b> — cast com <b>Isabella Lancaster</b> (ficha completa; ≠ Isabel/Impura) + Yuina / Gakko Chikara.</li>
      <li contenteditable="true"><b>5. HERORGASM 5</b> — Impura kit, fichas do grupo, inimigos tabela ({counts.get('h5_enemies_table', '?')}), elites narrativos (Bola de Ferro, Samael, Haru, Kevin, Madame Cascos, Bruxa, Mika Yamamoto).</li>
    </ol>
    <p contenteditable="true">Inventário máquina: <code>tools/adaptacao_masmorra2_inventory.json</code> · total entidades unificadas: <b>{len(inventory)}</b>
    (playable {n_play} · elite {n_elite} · enemy {n_enemy} · npc {n_npc}).</p>
  </div>
'''
    if 'id="fontes-5"' in text:
        text = re.sub(r'<div class="note docx-enrich" id="fontes-5">.*?</div>\n', method_extra, text, count=1, flags=re.S)
    else:
        # insert after existing docx-enrich in method
        text = text.replace(
            '    Novos blocos DOCX (Martha, Jakub, Babli, Irwin, Nikki, Scypha, Delia, Chase, Nixie, Basil, Mahina, Alduin, etc.) acrescentados abaixo.\n  </div>\n</section>',
            '    Novos blocos DOCX (Martha, Jakub, Babli, Irwin, Nikki, Scypha, Delia, Chase, Nixie, Basil, Mahina, Alduin, etc.) acrescentados abaixo.\n  </div>\n'
            + method_extra + '</section>'
        )

    # 6) Update summary counts
    new_summary = f'''<section class="summary" id="resumo-contagem">
  <h2 class="sec" contenteditable="true">Resumo / contagens</h2>
  <div class="summary-grid">
    <div class="stat"><div class="n">{len(inventory)}</div><div class="l">Entidades no inventário (5 fontes unificadas)</div></div>
    <div class="stat"><div class="n">42</div><div class="l">Seções de personagem no HTML (8 comuns + 34 ausentes · +Isabella)</div></div>
    <div class="stat"><div class="n">{n_hotn3}</div><div class="l">Playable com par HotN3 (in_hotn3)</div></div>
    <div class="stat"><div class="n">{n_aus}</div><div class="l">Playable ausentes HotN3</div></div>
    <div class="stat"><div class="n">{n_enemy + n_elite}</div><div class="l">Inimigos + elites (planilha/DOCX/narrativa)</div></div>
    <div class="stat"><div class="n">1</div><div class="l">Isabella Lancaster (nova · ≠ Isabel)</div></div>
  </div>
  <p class="muted" contenteditable="true">Fontes: masmorra2.xlsx + HERORGASM 4 + HotN Godot (2) + HERORGASM 5.
  <b>Isabel (Impura)</b> e <b>Isabella Lancaster</b> são personagens distintos. Inventário JSON espelha todas as entidades.</p>
</section>'''
    text = re.sub(r'<section class="summary" id="resumo-contagem">.*?</section>',
                  new_summary, text, count=1, flags=re.S)

    # badges
    text = text.replace(
        '<span class="badge"><b>Ausentes</b> 33 personagens planilha + DOCX</span>',
        '<span class="badge"><b>Ausentes</b> 34 personagens planilha + DOCX (+Isabella)</span>'
    )
    text = text.replace(
        '<span class="badge"><b>Comum</b> 8 personagens já no HotN3</span>',
        '<span class="badge"><b>Comum</b> 8 personagens já no HotN3</span>\n    <span class="badge"><b>Inventário</b> ' + str(len(inventory)) + ' entidades / 5 fontes</span>'
    )

    # 7) Append narrative elites to inimigos appendix if missing
    if 'Bola de Ferro' not in text[text.find('id="inimigos"'):text.find('id="lacunas"')]:
        extra_elites = '''
  <h3 contenteditable="true">Elites narrativos (HERORGASM 5 + vilões)</h3>
  <div class="note">Elites citados em combate nas aventuras H5 / H4 — propostas de cartas. <span class="chip gap">proposta</span></div>
  <table class="map">
    <thead><tr><th>Nome</th><th>Papel</th><th>Notas</th><th>Cartas sugeridas</th></tr></thead>
    <tbody>
      <tr><td contenteditable="true">Bola de Ferro</td><td contenteditable="true">Elite</td><td contenteditable="true">Gangue vs Culto; tortura</td><td contenteditable="true">Golpe de Ferro · Tortura</td></tr>
      <tr><td contenteditable="true">Samael</td><td contenteditable="true">Elite</td><td contenteditable="true">Meio-Sangue serpente; Brom Stikk</td><td contenteditable="true">Forma Serpente · Investida</td></tr>
      <tr><td contenteditable="true">Haru</td><td contenteditable="true">Elite</td><td contenteditable="true">Caldo-Gama (monstro)</td><td contenteditable="true">Caldo-Gama</td></tr>
      <tr><td contenteditable="true">Kevin</td><td contenteditable="true">Elite</td><td contenteditable="true">Líder gangue / Caldo-Gama</td><td contenteditable="true">(kit incompleto)</td></tr>
      <tr><td contenteditable="true">Madame Cascos</td><td contenteditable="true">Elite/Vilã</td><td contenteditable="true">Anéis / Caos</td><td contenteditable="true">Arremesso</td></tr>
      <tr><td contenteditable="true">Bruxa (docas)</td><td contenteditable="true">Elite narrativa</td><td contenteditable="true">Vampira; distinta do lacaio “Bruxa” da planilha</td><td contenteditable="true">Pedras · Pele Vampírica</td></tr>
      <tr><td contenteditable="true">Mika Yamamoto</td><td contenteditable="true">Subchefe</td><td contenteditable="true">Tabela H5</td><td contenteditable="true">Garras · Servos</td></tr>
    </tbody>
  </table>
'''
        text = text.replace('</section>\n<section class="summary" id="lacunas">',
                            extra_elites + '\n</section>\n<section class="summary" id="lacunas">')

    HTML.write_text(text, encoding='utf-8')
    # sync shots
    SHOTS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(HTML, SHOTS / 'adaptacao_masmorra2.html')
    return text


def main():
    print('Extracting xlsx…')
    entities, counts = extract_xlsx()
    print('Extracting docx…')
    entities, counts = extract_docx(entities, counts)
    print('Finalizing…')
    inventory = finalize(entities)

    # ensure Isabella present
    names = {e['name'] for e in inventory}
    assert 'Isabella Lancaster' in names, 'Isabella missing!'
    assert 'Isabel' in names, 'Isabel missing!'

    inv_path = TOOLS / 'adaptacao_masmorra2_inventory.json'
    payload = {
        'generated': datetime.now().isoformat(timespec='seconds'),
        'timezone': 'America/Sao_Paulo',
        'sources': SOURCES,
        'extraction_counts': counts,
        'total_entities': len(inventory),
        'entities': inventory,
    }
    inv_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    shutil.copy2(inv_path, SHOTS / 'adaptacao_masmorra2_inventory.json')
    print(f'Inventory: {len(inventory)} entities → {inv_path}')
    print('Patching HTML…')
    patch_html(inventory, counts)
    # report
    new_names = ['Isabella Lancaster', 'Yuina', 'Gakko Chikara', 'Bola de Ferro', 'Samael', 'Haru', 'Kevin', 'Madame Cascos', 'Mika Yamamoto']
    present = [n for n in new_names if n in names]
    print('Key names present:', present)
    print('Counts:', json.dumps(counts, ensure_ascii=False))
    isabella = next(e for e in inventory if e['name']=='Isabella Lancaster')
    print('Isabella cards:', len(isabella['suggested_cards']), 'sources:', isabella['sources'])
    isabel = next(e for e in inventory if e['name']=='Isabel')
    print('Isabel aliases:', isabel['aliases'], 'sources:', isabel['sources'])

if __name__ == '__main__':
    main()
