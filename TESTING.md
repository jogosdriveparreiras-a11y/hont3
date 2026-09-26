# Verificação do HotN3

Execute `python3 tools/run_checks.py` na raiz do projeto. Com Godot 4.6 instalado no `PATH`, o comando também importa os recursos e executa `StatusSmoke.gd` e `SceneSmoke.gd` em modo headless. Caso o binário tenha outro nome, use `python3 tools/run_checks.py --godot /caminho/para/godot`.

Os testes estáticos verificam delimitadores e recuo dos scripts, referências a recursos, integridade do catálogo de cartas, heróis, inimigos e missões, e a lista de 77 efeitos. Eles não substituem o parser GDScript do Godot.

`StatusSmoke.gd` exercita dano e estados, Chain obrigatório, Soulbound, eliminação por impacto com Marcado e outros casos. `SceneSmoke.gd` importa a cena principal, cria o menu, inicia uma missão, confere a mão e as cartas 3D e avança um turno. Ambos dependem do Godot e só são declarados aprovados quando retornam código zero.

Neste ambiente, o Godot 4.6 não está instalado. As verificações estáticas podem passar, mas a importação, os dois testes headless e o teste visual continuam pendentes. Antes de classificar uma versão como jogável, percorra no editor: menu → equipe → decks → missão → combate → vitória/derrota → repetição; confira console, entradas, sprites, fontes, áudio e layout em 1366×768 e 1920×1080.
