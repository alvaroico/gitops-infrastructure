#!/usr/bin/env bash
# ==============================================================================
# 07-deploy-homolog.sh - Aplicar Applications de Homologação/Dev no ArgoCD
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== 1. CRIANDO NAMESPACES DE DEV / HOMOLOGAÇÃO ==="
kubectl create namespace eos-dev --dry-run=client -o yaml | kubectl apply -f - || true
kubectl create namespace homolog --dry-run=client -o yaml | kubectl apply -f - || true

echo "=== 2. APLICANDO APPLICATIONS DO ARGOCD ==="
if [ -f "${ROOT_DIR}/argocd-apps/eos-dev-application.yaml" ]; then
    kubectl apply -f "${ROOT_DIR}/argocd-apps/eos-dev-application.yaml"
fi

for app in "${ROOT_DIR}"/argocd-apps/*-dev*.yaml "${ROOT_DIR}"/argocd-apps/*-homolog*.yaml; do
    if [ -f "${app}" ]; then
        echo "Aplicando: $(basename "${app}")"
        kubectl apply -f "${app}"
    fi
done

echo ""
echo "=== APPLICATIONS DE HOMOLOGAÇÃO / DEV APLICADAS! ==="
echo "Acompanhe o status e a sincronização no ArgoCD Dashboard."
