#!/usr/bin/env bash
# ==============================================================================
# 08-promote-kargo-stage.sh - Promove uma versão de Freight para um Stage no Kargo
# ==============================================================================
set -euo pipefail

STAGE="${1:-}"
FREIGHT_ID="${2:-}"
PROJECT="eos-platform"

if [ -z "${STAGE}" ]; then
  echo "Uso: $0 <stage: dev|prod|postgres-dev|postgres-prod> [freight-id]"
  echo ""
  echo "Exemplo:"
  echo "  $0 dev"
  echo "  $0 prod 9bfbbbffbcbcb07c7b214759aed2f1af301491d3"
  exit 1
fi

if ! command -v kargo >/dev/null 2>&1; then
  echo "⚠️ CLI 'kargo' não encontrada. Instalando via Homebrew ou binário..."
  if command -v brew >/dev/null 2>&1; then
    brew install kargo || true
  fi
fi

if [ -z "${FREIGHT_ID}" ]; then
  echo "⚡ Promovendo Freight mais recente para o estágio '${STAGE}'..."
  kargo promote "${STAGE}" --project "${PROJECT}"
else
  echo "⚡ Promovendo Freight '${FREIGHT_ID}' para o estágio '${STAGE}'..."
  kargo promote "${STAGE}" --freight "${FREIGHT_ID}" --project "${PROJECT}"
fi
