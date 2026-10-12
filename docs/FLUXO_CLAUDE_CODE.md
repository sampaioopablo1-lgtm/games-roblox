# Fluxo: GitHub + Claude Code + Roblox Studio

Como este repositório vira um jogo rodando no Roblox Studio, e como continuar
desenvolvendo com IA.

## Opção A — Rojo (recomendada, é o que este repo usa)

[Rojo](https://rojo.space) sincroniza a pasta `src/` com o Roblox Studio em tempo real.
Cada arquivo `.luau` vira um Script/ModuleScript conforme o `default.project.json`.

1. Instale o Rojo (via [Aftman](https://github.com/LPGhatguy/aftman) / [Rokit](https://github.com/rojo-rbx/rokit)):
   ```sh
   rokit install      # lê rokit.toml deste repo
   ```
2. Instale o plugin do Rojo no Studio: `rojo plugin install`.
3. Na raiz do repo: `rojo serve`.
4. No Studio: abra um **Baseplate vazio** → aba *Plugins* → *Rojo* → *Connect*.
5. Aperte **Play**. O mapa é gerado por código, não precisa de `.rbxl`.

Alternativa sem sincronização ao vivo: `rojo build -o PegaBichos.rbxl` e abra o arquivo.

## Opção B — MCP: Claude Code controlando o Studio

Servidores MCP deixam o Claude inspecionar e editar a cena aberta no Studio:

- **Oficial da Roblox:** [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server)
  (plugin do Studio + servidor Rust). Para o Claude Code:
  ```sh
  claude mcp add --transport stdio Roblox_Studio -- <caminho>/rbx-studio-mcp --stdio
  ```
  No Studio, habilite *Game Settings → Security → Allow HTTP Requests* e *Enable Studio Access to API Services*.
- Comunidade: [ZubeidHendricks/roblox-studio-mcp-claude-code](https://github.com/ZubeidHendricks/roblox-studio-mcp-claude-code),
  [CyanoTex/bloxus](https://github.com/CyanoTex/bloxus) (knowledge engine da API Roblox),
  [Claudeblox](https://github.com/search?q=Claudeblox) (geração autônoma de jogo).

## Opção C — Skills de Roblox para o Claude Code

Skills dão ao Claude conhecimento de Luau/Roblox sem precisar de MCP:

- [brockmartin/roblox-game-skill](https://github.com/brockmartin/roblox-game-skill) — ciclo completo de dev Roblox.
  ```sh
  git clone https://github.com/brockmartin/roblox-game-skill ~/.claude/skills/roblox-game
  ```
- [greedychipmunk/agent-skills → roblox-game-development](https://claudemarketplaces.com/skills/greedychipmunk/agent-skills/roblox-game-development)
- [sentinelcore/roblox-skills](https://claudemarketplaces.com/skills/sentinelcore/roblox-skills) (GUI, DataStore, etc.)

## Ciclo de trabalho sugerido

```
GitHub (este repo)  ⇄  Claude Code (edita src/)  ⇄  Rojo serve  ⇄  Roblox Studio (testa)
                                                                        ↓
                                                                  Publish to Roblox
```

1. Peça ao Claude Code uma feature ("adicione um bicho de evento de Halloween").
2. Ele edita `src/`, roda `luau-lsp analyze` (ver `scripts/check.sh`), abre PR.
3. Você revisa, `rojo serve`, testa no Studio, publica (*File → Publish to Roblox*).

## Fontes

- [Roblox Studio Rust MCP Server (repo oficial)](https://github.com/Roblox/studio-rust-mcp-server)
- [Setup do MCP para Claude Code — Claude Marketplaces](https://claudemarketplaces.com/mcp/roblox/studio-rust-mcp-server)
- [brockmartin/roblox-game-skill — instalação](https://mintlify.wiki/brockmartin/roblox-game-skill/installation)
- [Roblox skills — Claude Marketplaces](https://claudemarketplaces.com/skills/sentinelcore/roblox-skills)
