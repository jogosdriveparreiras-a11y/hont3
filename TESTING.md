# Verificação do HotN3

Execute `python3 tools/run_checks.py` na raiz do projeto. Com Godot 4.6 instalado no `PATH`, o comando também importa os recursos e executa `StatusSmoke.gd` e `SceneSmoke.gd` em modo headless. Caso o binário tenha outro nome, use `python3 tools/run_checks.py --godot /caminho/para/godot`.

Os testes estáticos verificam delimitadores e recuo dos scripts, referências a recursos, integridade do catálogo de cartas, heróis, inimigos, campanha e missões, a lista de 77 efeitos, os hashes registrados das oito imagens e a ausência dos arquivos legados removidos. Eles não substituem o parser GDScript do Godot.

`StatusSmoke.gd` exercita dano e estados, Chain obrigatório, Soulbound, eliminação por impacto com Marcado, KO por dano próprio sem recompensa, prévia sem efeitos colaterais e novos alvos. `CampaignSmoke.gd` verifica a conclusão das quatro missões e a barreira dos reforços. `SceneSmoke.gd` importa a cena principal, confere áudio, entrada, acessibilidade, desbloqueios, Essência, deck, atores e cartas 3D, e verifica limites da interface em 1366×768 e 1920×1080. Os três dependem do Godot e só são declarados aprovados quando retornam código zero.

Neste ambiente, o Godot 4.6 não está instalado. As verificações estáticas podem passar, mas a importação, os três testes headless e o teste visual continuam pendentes. Antes de classificar uma versão como jogável, percorra no editor: menu → equipe → decks → missão → combate → vitória/derrota → repetição; confira console, entradas, sprites, áudio e layout em 1366×768 e 1920×1080. Para exportar após o gate, instale os templates 4.6 e execute `python3 tools/build_web.py --godot /caminho/para/godot`.
