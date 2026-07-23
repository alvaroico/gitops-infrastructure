#!/usr/bin/env bash
# ==============================================================================
# 03-setup-sealed-secrets.sh - Instalação do Controller Bitnami Sealed Secrets
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== 1. INSTALANDO O CONTROLLER DO SEALED SECRETS NO CLUSTER ==="
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/sealed-secret-manifest.yaml

echo "=== 2. AGUARDANDO DEPLOYMENT DO CONTROLLER ==="
kubectl -n kube-system rollout status deployment sealed-secrets-controller --timeout=300s

echo ""
echo "=== SEALED SECRETS INSTALADO COM SUCESSO! ==="
echo "O controller está pronto para descriptografar recursos do tipo SealedSecret."
