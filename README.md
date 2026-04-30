# Brawlls

Simulador 2D de batalhas físicas criado em Godot (GDScript).

**Visão rápida**: protótipo de arena com entidades que batalham automaticamente usando armas modulares.

**Versão do Godot**: recomendado Godot 4.6 (veja `project.godot`).

## Estrutura principal do projeto
- `Main.tscn` / `main.gd`: UI e orquestração da batalha.
- `Arena.tscn` / `arena.gd`: criação dinâmica de paredes e regras da arena.
- `Ball.tscn` / `ball.gd`: entidade básica (HP, movimento, delega para armas).
- `Projectile.tscn` / `projectile.gd`: projéteis e detecção de colisão.
- `weapons/`: implementações das armas (ex.: `colt.gd`, `frank.gd`, `shelly.gd`).
- `preset_catalog.gd`: presets de batalha para testes rápidos.

## Observações e dicas
- Muitos ativos de áudio e imagens já estão incluídos em `sfx/` e `weapons/texturas/`.
- O projeto usa a pipeline GL compatibility (veja `project.godot`) para maximizar compatibilidade.
- Se aparecer aviso de conversão de fim-de-linha ao commitar (`CRLF -> LF`), é normal no Windows; verifique `.gitattributes`.

## Nota
Repositório pessoal.

