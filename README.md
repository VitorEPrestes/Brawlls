# Brawlls

AVISO: Este repositório é PROPRIETÁRIO — não é código aberto. Uso e modificações por terceiros não autorizados não são permitidos.

Simulador 2D de batalhas físicas criado em Godot (GDScript).

**Visão rápida**: é um protótipo de arena com entidades que batalham automaticamente usando armas modulares.

**Versão do Godot**: recomendado Godot 4.6 (veja `project.godot`).

## Como abrir e executar
- Instale Godot 4.6 (estável/RC conforme preferir).
- Abra o editor Godot e selecione o arquivo [project.godot](project.godot) para carregar o projeto.
- Ao abrir o projeto, carregue `Main.tscn` e pressione F5 para executar.

Se preferir, via linha de comando (se tiver o `godot` no PATH):

```powershell
godot --path .
```

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

## Nota sobre contribuição
Este repositório é pessoal e NÃO aceita contribuições externas.

---
Arquivo atualizado: [README.md](README.md)
