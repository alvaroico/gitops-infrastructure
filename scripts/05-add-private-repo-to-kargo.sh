#!/usr/bin/env bash
# ==============================================================================
# 05-add-private-repo-to-kargo.sh - Cadastra credenciais do GitHub no Kargo
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

GITHUB_USER="${GITHUB_USER:-alvaroico}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [ -z "${GITHUB_TOKEN}" ]; then
  echo "❌ ERRO: Defina a variável GITHUB_TOKEN antes de executar:"
  echo "   export GITHUB_TOKEN=\"ghp_seu_token_aqui\""
  echo "   $0"
  exit 1
fi

PROJECT_NAMESPACE="eos-platform"

echo "=== GARANTINDO NAMESPACE DO PROJETO: ${PROJECT_NAMESPACE} ==="
kubectl apply -f kargo/project.yaml

echo "=== CRIANDO SECRET DE CREDENCIAIS GIT NO KARGO ==="
kubectl create secret generic github-gitops-creds \
  --namespace "${PROJECT_NAMESPACE}" \
  --from-literal=repoURL="https://github.com/${GITHUB_USER}/*" \
  --from-literal=username="${GITHUB_USER}" \
  --from-literal=password="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Rótulo canônico obrigatório do Kargo
kubectl label secret github-gitops-creds -n "${PROJECT_NAMESPACE}" kargo.akuity.io/cred-type=git --overwrite

echo "✅ Credencial Git registrada no Kargo com sucesso!"
