# Passo a passo para leigos — do zero até ganhar Robux

Tempo total: ~1 hora. Você só precisa de um PC (Windows ou Mac) e uma conta Roblox.

## Parte 1 — Abrir o jogo no seu computador (10 min)

1. **Instale o Roblox Studio** (grátis): <https://create.roblox.com> → botão **Start Creating** → instale e entre com sua conta Roblox.
2. **Baixe o jogo**: neste repositório, abra a pasta `build`, clique em `RoubaBichos.rbxl` e depois no botão **Download raw file** (ícone de download, canto superior direito).
3. **Dê dois cliques** no arquivo baixado. Ele abre no Roblox Studio.
4. **Ligue o salvamento de dados**: no Studio, menu **Home → Game Settings → Security** → ative **Enable Studio Access to API Services** → **Save**.
5. Clique em **Play** (botão ▶ no topo). Você deve ver a esteira com bichos, as bases e o HUD. Ande até um bicho e aperte **E** para comprar.

> Se aparecer uma pergunta sobre "publicar antes", pode publicar (Parte 2) e voltar.

## Parte 2 — Publicar (5 min)

1. **File → Publish to Roblox**.
2. Nome: `Rouba Bichos!` · Descrição: "Compre bichos, roube dos outros e proteja sua base!" · Gênero: *Adventure* · Dispositivos: marque **todos** (PC, celular, tablet, console) — celular é mais da metade dos jogadores.
3. Clique em **Create**. Depois, no mesmo painel, mude **Private → Public**.

## Parte 3 — Criar os itens que vendem (20 min)

Vá em <https://create.roblox.com> → **Creations** → clique no seu jogo → menu esquerdo **Monetization**.

### Passes (compra única)
Em **Passes → Create a Pass**, crie um por vez com estes nomes e preços (em Robux):

| Nome | Preço |
|---|---|
| VIP | 399 |
| Coleta Automática | 199 |
| +4 Vagas na Base | 249 |
| Super Cadeado | 149 |
| Sortudo | 299 |
| Ladrão Veloz | 179 |

Depois de criar cada um, clique nele e ative **Item for sale**. Anote o **número do ID** que aparece na URL (ex.: `.../passes/123456789/...`).

### Produtos (compra repetível)
Em **Developer Products → Create**, crie:

| Nome | Preço |
|---|---|
| Saco de Moedas | 29 |
| Cofre de Moedas | 99 |
| Banco de Moedas | 399 |
| Sorte do Servidor | 149 |
| Chuva Mítica | 249 |
| Cadeado Instantâneo | 25 |

Anote o ID de cada um.

### Colar os IDs no jogo
1. No Studio, abra a janela **Explorer** (View → Explorer) e **Properties**.
2. Vá em **ReplicatedStorage → Shared → Config** e dê dois cliques para abrir o script.
3. No topo, troque cada `Id = 0` pelo número que você anotou. Exemplo:
   ```lua
   { Key = "VIP", Id = 123456789, Name = "VIP", ...
   ```
4. **File → Publish to Roblox** de novo (Ctrl+Shift+P / Cmd+Shift+P).

Pronto: o botão **🛒 Loja** dentro do jogo passa a mostrar os itens e você recebe 70 % de cada venda.

## Parte 4 — Ícone e capa (10 min)

No Creator Hub → seu jogo → **Basic Settings**: suba um ícone (512×512) e uma capa (1920×1080). Pode criar no Canva: um bicho colorido grande, texto "ROUBA BICHOS!" e um 😈. Ícone chamativo é o que mais influencia cliques.

## Parte 5 — Trazer jogadores (contínuo)

- Grave clipes de 15–30 s de roubos e defesas (o Studio grava com **F12** ou use o OBS) e poste no TikTok / YouTube Shorts / Instagram Reels com #roblox #stealabrainrot.
- Peça para amigos jogarem juntos — o jogo dá **+10 % de renda por amigo no mesmo servidor**, mostre isso nos vídeos.
- Toda semana mude algo pequeno (um bicho novo em `Config.luau`, um preço) e publique: a Roblox favorece jogos atualizados.
- Quando tiver jogadores constantes, ative **Rewarded Video Ads** em *Monetization → Ads* (renda extra automática).

## Parte 6 — Sacar o dinheiro

Em <https://create.roblox.com/dashboard/devex>: precisa de **30.000 Robux** acumulados, conta com 13+ anos e verificação de identidade. 100.000 Robux ≈ US$ 350 (ver taxa atual lá).

## Problemas comuns

| Sintoma | Solução |
|---|---|
| Dinheiro zera ao reentrar | Parte 1, passo 4 (API Services) ou publique o jogo primeiro |
| Loja vazia | Os `Id = 0` ainda não foram trocados (Parte 3) |
| Nada acontece ao apertar Play | Olhe a janela **Output** (View → Output) e me mande o erro em vermelho |

Qualquer dúvida, cole aqui a mensagem de erro que eu ajusto o código.
