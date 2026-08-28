#!/usr/bin/env bash
# ==============================================================================
# 02-setup-kargo.sh - Instalação do Kargo Control Plane e IngressRoute no Traefik
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== 1. VERIFICANDO / INSTALANDO CERT-MANAGER (PRÉ-REQUISITO KARGO) ==="
if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
  echo "Instalando cert-manager v1.16..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
  kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
else
  echo "cert-manager já instalado."
fi

echo "=== 2. INSTALANDO CONTROL PLANE DO KARGO (HELM OCI) ==="
# Hash Bcrypt para senha admin: admin123!
PASSWORD_HASH='$2y$05$u5C0FkdXvvoJdooR13.pWe42T76M/cuyknxfvpYU09aMFYX81LMZy'
SIGNING_KEY='8f3c7a1b9e2d4f5c6a7b8c9d0e1f2a3b'

helm upgrade --install kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set-string api.adminAccount.passwordHash="${PASSWORD_HASH}" \
  --set-string api.adminAccount.tokenSigningKey="${SIGNING_KEY}"

echo "Aguardando pods do Kargo ficarem prontos..."
kubectl wait --for=condition=Ready pods --all -n kargo --timeout=180s

echo "=== 3. CONFIGURANDO INGRESSROUTE DO TRAEFIK (HTTPS) ==="
if kubectl get crd ingressroutes.traefik.io >/dev/null 2>&1; then
  echo "Traefik detectado. Aplicando IngressRoute HTTPS..."
  kubectl apply -f kargo/ingressroute-kargo.yaml
else
  echo "ℹ️ Traefik não instalado neste cluster (modo local/dev). Acesso disponível via port-forward."
fi

echo ""
echo "=========================================================="
echo "🎉 KARGO INSTALADO COM SUCESSO!"
echo "=========================================================="
echo "• Dashboard Web: https://kargo.alvaroico-teste.com.br"
echo "• Usuário: admin"
echo "• Senha:   admin123!"
echo "• Port-forward local (opcional): kubectl port-forward svc/kargo-api 8080:443 -n kargo"
echo ""
