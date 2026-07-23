#!/usr/bin/env bash
# ==============================================================================
# 05-add-private-repo-to-argocd.sh - Registrar Repositório Privado no ArgoCD
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== REGISTRANDO REPOSITÓRIO PRIVADO NO ARGOCD ==="

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo -n "Informe seu GitHub Personal Access Token (PAT): "
    read -r -s GITHUB_TOKEN
    echo ""
fi

if [[ -z "${GITHUB_TOKEN}" ]]; then
    echo "Erro: O token do GitHub não foi fornecido."
    exit 1
fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-gitops-infrastructure
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/alvaroico/gitops-infrastructure.git
  username: alvaroico
  password: "${GITHUB_TOKEN}"
EOF

echo "Forçando sincronização do ArgoCD..."
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout restart deployment argocd-server

echo ""
echo "=== REPOSITÓRIO PRIVADO CADASTRADO COM SUCESSO NO ARGOCD! ==="
