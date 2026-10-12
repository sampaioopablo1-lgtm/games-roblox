#!/usr/bin/env sh
# Publica o jogo direto na Roblox via Open Cloud (sem abrir o Studio).
#
# Variáveis de ambiente necessárias (guarde como segredos, nunca no git):
#   ROBLOX_API_KEY     chave criada em https://create.roblox.com/dashboard/credentials
#                      com a permissão "universe-places:write" para a experiência
#   ROBLOX_UNIVERSE_ID número do universo (Creator Hub → sua experiência → URL/Overview)
#   ROBLOX_PLACE_ID    número do place inicial (o número na URL roblox.com/games/<ID>)
#
# Uso:  scripts/publish.sh            → publica (Published)
#       scripts/publish.sh Saved      → só salva uma versão sem publicar
set -eu
cd "$(dirname "$0")/.."

: "${ROBLOX_API_KEY:?defina ROBLOX_API_KEY}"
: "${ROBLOX_UNIVERSE_ID:?defina ROBLOX_UNIVERSE_ID}"
: "${ROBLOX_PLACE_ID:?defina ROBLOX_PLACE_ID}"
VERSION_TYPE="${1:-Published}"

mkdir -p build
rojo build default.project.json -o build/RoubaBichos.rbxl

curl -sS --fail-with-body -X POST \
  "https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=${VERSION_TYPE}" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/RoubaBichos.rbxl

echo
echo "OK: versão enviada (${VERSION_TYPE})."
