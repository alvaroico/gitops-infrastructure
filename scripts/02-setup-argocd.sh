#!/usr/bin/env bash
# ==============================================================================
# 02-setup-argocd.sh - Instalação do ArgoCD e Configuração do Traefik Ingress
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== 1. CRIANDO NAMESPACE ARGOCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "=== 2. APLICANDO MANIFESTOS OFICIAIS DO ARGOCD ==="
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Aguardando deployment do argocd-server ser registrado..."
until kubectl -n argocd get deployment argocd-server >/dev/null 2>&1; do sleep 3; done

echo "=== 3. CONFIGURANDO MODO INSECURE (HTTP ATRAVÉS DO TRAEFIK INGRESS) ==="
kubectl -n argocd patch configmap argocd-cmd-params-cm \
  --type merge -p '{"data":{"server.insecure":"true"}}'

echo "Reiniciando argocd-server para aplicar o modo insecure..."
kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout status deployment argocd-server --timeout=300s

echo "=== 4. CRIANDO INGRESSROUTE DO TRAEFIK PARA ARGOCD ==="
cat <<'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server-ingressroute
  namespace: argocd
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`argocd.alvaroico-teste.com.br`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
EOF

echo ""
echo "=== ARGOCD INSTALADO COM SUCESSO! ==="
echo "Acesse a interface no navegador: http://argocd.alvaroico-teste.com.br"
echo "Usuário: admin"
echo -n "Senha de Admin: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
