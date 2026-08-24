#!/usr/bin/env bash
# ==============================================================================
# 08-deploy-prod.sh - Aplicar Applications de Produção no ArgoCD
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== 1. CRIANDO NAMESPACES DE PRODUÇÃO ==="
kubectl create namespace eos-prod --dry-run=client -o yaml | kubectl apply -f - || true
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f - || true

echo "=== 2. APLICANDO APPLICATIONS DE PRODUÇÃO DO ARGOCD ==="
if [ -f "${ROOT_DIR}/argocd-apps/eos-prod-application.yaml" ]; then
    kubectl apply -f "${ROOT_DIR}/argocd-apps/eos-prod-application.yaml"
fi

for app in "${ROOT_DIR}"/argocd-apps/*-prod*.yaml; do
    if [ -f "${app}" ]; then
        echo "Aplicando: $(basename "${app}")"
        kubectl apply -f "${app}"
    fi
done

echo ""
echo "=== APPLICATIONS DE PRODUÇÃO APLICADAS! ==="
echo "Acompanhe o status e a sincronização no ArgoCD Dashboard."
