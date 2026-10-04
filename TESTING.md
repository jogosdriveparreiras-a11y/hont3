# Verificação do HotN3

Execute `python tools/run_checks.py --godot /caminho/para/godot` na raiz do projeto. O comando importa os recursos e executa `EngineSmoke.gd`, `StatusSmoke.gd`, `CampaignSmoke.gd`, `SceneSmoke.gd` e `MergeSmoke.gd` em modo headless. Sem `--godot`, ele procura `godot` ou `godot4` no `PATH`.

Os testes estáticos verificam delimitadores e recuo dos scripts, referências a recursos, os 27 personagens, as 553 cartas mescladas, inimigos, campanha, cinco missões, 77 efeitos auditados, índices dos pacotes visuais, 50 BGM e as oito substituições de arte por hash. Eles não substituem o parser GDScript do Godot.

`EngineSmoke.gd` confirma que o SceneTree inicia. `StatusSmoke.gd` exercita dano, estados, Chain, Soulbound, impacto, prévia e alvos. `CampaignSmoke.gd` conclui as cinco missões e verifica reforços. `SceneSmoke.gd` confere áudio, entrada, acessibilidade, desbloqueios, Essência, coleção automática, atores, cartas 3D e limites da interface em 1366×768 e 1920×1080. `MergeSmoke.gd` confirma 35 personagens totais, 27 jogáveis e 553 cartas após a integração dos pacotes.

A suíte completa foi executada com Godot 4.6.1 em 2026-09-27. Ela cobre importação, regras, campanha, integração dos pacotes e limites básicos da interface. Antes de publicar uma versão, ainda percorra no editor: menu → equipe → coleção → missão → combate → vitória/derrota → repetição; confira entradas, sprites, BGM, efeitos e layout em 1366×768 e 1920×1080. Para exportar, instale os templates 4.6 e execute `python tools/build_web.py --godot /caminho/para/godot`.
