#!/usr/bin/env sh
# Checagem de tipos/lint do projeto. Requer rojo + luau-lsp (rokit install)
# e o arquivo de tipos da Roblox:
#   curl -sSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
set -eu
cd "$(dirname "$0")/.."
DEFS="${ROBLOX_DEFS:-globalTypes.d.luau}"
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src
echo "OK: sem erros de tipo."
