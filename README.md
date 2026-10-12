# Rouba Bichos! 🐾😈

Jogo Roblox no gênero **"steal"** (o mais rentável da plataforma em 2026 — ver
[`docs/PESQUISA_MERCADO.md`](docs/PESQUISA_MERCADO.md)), pronto para publicar e monetizar.

**Loop:** bichos passam numa esteira → você compra e coloca na sua base → eles
geram dinheiro por segundo → **roube** bichos das bases dos outros (segure **E**)
e corra para a sua → defenda a sua com **tapa** e **cadeado** → renasça para
multiplicar a renda.

## Monetização incluída (6 passes + 6 produtos)

| Game Pass (compra única) | Developer Product (repetível) |
|---|---|
| VIP — 2x dinheiro | Saco/Cofre/Banco de moedas (escalam com a renda do jogador) |
| Coleta Automática | 🍀 Sorte do Servidor — raros 2x para **todos** por 15 min |
| +4 Vagas na Base | 🌠 Chuva Mítica — ganha um Mítico + solta outro na esteira |
| Super Cadeado (120 s) | Cadeado Instantâneo |
| Sortudo — 2x mutações Ouro/Diamante | |
| Ladrão Veloz | |

Mais: prêmio diário com sequência, ganho offline (2 h a 25 %), bônus por amigos no
servidor (+10 % cada, até +50 %), placar global de renascimentos, 16 bichos em 6
raridades, mutações Ouro (2x) e Diamante (5x).

Toda compra é validada **no servidor**; `ProcessReceipt` é idempotente (cada recibo
só concede uma vez) e os dados usam DataStore com trava de sessão e autosave.

## Jeito mais fácil (sem instalar nada além do Studio)

1. Baixe [`build/RoubaBichos.rbxl`](build/RoubaBichos.rbxl) (botão **Download raw file**).
2. Dê dois cliques no arquivo → abre no Roblox Studio.
3. *Game Settings → Security → Enable Studio Access to API Services* → **Play**.

Veja o passo a passo completo para leigos em [`docs/PASSO_A_PASSO.md`](docs/PASSO_A_PASSO.md).

## Rodar com Rojo (para desenvolver)

1. `rokit install` (instala Rojo + luau-lsp) e `rojo plugin install`.
2. `rojo serve` → no Studio (Baseplate vazio) → Plugins → Rojo → **Connect**.
3. Ative *Game Settings → Security → Enable Studio Access to API Services* (DataStore).
4. **Play**. O mapa inteiro (esteira, 8 bases, placar) é gerado por código.

Sem sincronização ao vivo: `rojo build -o RoubaBichos.rbxl`.

## Publicar e começar a ganhar

1. *File → Publish to Roblox* (experiência pública).
2. No [Creator Hub](https://create.roblox.com) → sua experiência → **Monetização**:
   crie os 6 Game Passes e os 6 Developer Products com os nomes/preços sugeridos
   em [`src/shared/Config.luau`](src/shared/Config.luau) e cole os **IDs** lá
   (itens com `Id = 0` ficam ocultos na loja).
3. Ative **Rewarded Video Ads** quando a experiência for elegível (receita extra sem código).
4. Faça um ícone/thumbnail chamativo e poste clipes de roubo no TikTok/YouTube Shorts
   — é assim que os jogos "steal" viralizam.
5. Atualize toda semana (bicho novo, evento). Edite só `Config.luau`.
6. Saque via **DevEx** (100k Robux ≈ US$ 350, mínimo 30k).

## Estrutura

```
default.project.json      mapeamento Rojo
src/shared/Config.luau    bichos, raridades, preços, IDs de monetização
src/shared/*.luau         Format, Remotes, CritterMath (servidor + cliente)
src/server/Main.server    inicialização
src/server/Services/      Data, Monetization, World, Economy, Base, Conveyor, Steal, CritterFactory
src/client/Main.client    HUD, loja, notificações
docs/                     pesquisa de mercado e fluxo Claude Code ↔ Studio
scripts/check.sh          análise de tipos (luau-lsp)
```

Desenvolvido com Claude Code — veja [`docs/FLUXO_CLAUDE_CODE.md`](docs/FLUXO_CLAUDE_CODE.md).
