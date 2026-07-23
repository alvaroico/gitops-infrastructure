#!/usr/bin/env bash
# ==============================================================================
# 03-setup-sealed-secrets.sh - Instalação do Controller Bitnami Sealed Secrets
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== 1. INSTALANDO O CONTROLLER DO SEALED SECRETS NO CLUSTER ==="
# Usando o manifesto oficial controller.yaml da versão estável v0.38.4
SEALED_SECRETS_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.38.4/controller.yaml"

echo "Aplicando manifesto de: $SEALED_SECRETS_URL"
kubectl apply -f "$SEALED_SECRETS_URL"

echo "=== 2. AGUARDANDO DEPLOYMENT DO CONTROLLER ==="
kubectl -n kube-system rollout status deployment sealed-secrets-controller --timeout=300s

echo ""
echo "=== SEALED SECRETS INSTALADO COM SUCESSO! ==="
echo "O controller está pronto para descriptografar recursos do tipo SealedSecret."
