# Inventário e origem dos recursos

## Arte-base compatível com o runtime

Os oito nomes históricos na raiz continuam existindo porque `Content.gd` os referencia. Seus bytes antigos, cuja licença não estava documentada, foram substituídos por cópias de imagens do RPG Maker MZ DLC em `assets/cast_sensitive/`. Assim o jogo mantém as referências sem carregar a arte antiga.

| Destino usado pelo jogo | Fonte versionada | SHA-256 |
| --- | --- | --- |
| `hero_fighter.png` | `assets/cast_sensitive/Actor1_1.png` | `ddfe7ef9c5a71b8271a9f125ec76960dba913b448cdeab4e991b156f9ef2a5cf` |
| `hero_wizard.png` | `assets/cast_sensitive/Actor2_2.png` | `02aae539d86980d587327b1e017232151ad5ddfdf4538bdf245d44fe04680c45` |
| `hero_rogue.png` | `assets/cast_sensitive/Actor2_5.png` | `368d0c8d7542d7e9c19af81cf4de02689c07fb63fe1f21ec88dc938a38f0821f` |
| `hero_cleric.png` | `assets/cast_sensitive/Actor3_1.png` | `693ac07bb4ada507612e94c0a07faa3d88414382f521cbf3f034913eb19eddfb` |
| `hero_paladin.png` | `assets/cast_sensitive/Actor1_4.png` | `fda1510e8978824a23c299d0fbc42c4dbd95006e1f0032ed6158d21347b196f1` |
| `en_dog.png` | `assets/cast_sensitive/Monster_7.png` | `3cd3419d73f29e2ea6181b8a83b3ace6328b8a3ef88fbb7b70a3660d77235818` |
| `en_elite.png` | `assets/cast_sensitive/Monster_4.png` | `8a40c4f7c8596674c2ccf1ca6867eac1e5cda803bf49e2a1854396933ad35af4` |
| `en_sniper.png` | `assets/cast_sensitive/Monster_2.png` | `35938deb350c8f6605568fdf6bf730427f5096d8e068ff4aed8f0636990e447e` |

## Pacotes RPG Maker MZ

O usuário confirmou em 2026-09-27 que possui as licenças dos DLCs usados. Os arquivos permanecem sujeitos aos termos das respectivas licenças RPG Maker; possuir o projeto não transfere direitos de redistribuição isolada dos recursos.

| Destino | Origem declarada | Inventário |
| --- | --- | --- |
| `assets/fx/effekseer/` | `3D Particle Effect Pack/effects` | subconjunto listado em `assets/fx/effekseer/index.json` |
| `assets/fx/particles2d/` | `TRP_ParticleMZ/materials/particles` | arquivos listados em `assets/fx/particles2d/index.json` |
| `assets/audio/bgm/` | `TRP_ParticleMZ/sample_project_en/audio/bgm` e `FantasyResourcePack/bgm/ogg/96kbps` | 50 arquivos OGG |
| `assets/cast_sensitive/` | `BasicResources/pictures` e placeholders próprios preexistentes | imagens alternativas e fontes das oito substituições acima |

O script `tools/copy_mz_dlc_assets.ps1` registra os caminhos locais usados para reconstruir esse conjunto. `tools/verify_assets.py` confere as cópias, índices e quantidades.

## Elenco HotN

As artes em `assets/cast/` pertencem ao conteúdo do projeto HotN e são ligadas aos 27 personagens de `addons/hotn3_entities/entities.json`. As três substituições locais de Alyssa, Dominika e Evelyn permanecem modificações do usuário e não foram descartadas.

## Recursos removidos

As fontes `AppleGaramond.ttf` e `CinzelDecorative-Bold.otf`, a música antiga `battle_music.ogg` e as cenas legadas `Main.tscn` e `Card.tscn` não fazem parte do projeto ativo.
