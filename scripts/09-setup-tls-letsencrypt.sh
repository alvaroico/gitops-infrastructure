#!/usr/bin/env bash
# ==============================================================================
# Script: 09-setup-tls-letsencrypt.sh
# Finalidade: Configurar Let's Encrypt com desafio HTTP-01 no Traefik (k3s)
# Execução: ./scripts/09-setup-tls-letsencrypt.sh <seu-email@dominio.com.br>
# ==============================================================================
set -euo pipefail

EMAIL="${1:-}"

if [ -z "${EMAIL}" ]; then
  echo "❌ Erro: Informe o e-mail de contato para o Let's Encrypt."
  echo "Uso: ./scripts/09-setup-tls-letsencrypt.sh <seu-email@dominio.com.br>"
  exit 1
fi

echo "=== 1. CONFIGURANDO RESOLVER LET'S ENCRYPT NO TRAEFIK (K3S) ==="
echo "📧 E-mail cadastrado: ${EMAIL}"

cat <<EOF | kubectl apply -f -
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      web:
        redirectTo:
          port: websecure
      websecure:
        tls:
          enabled: true
    additionalArguments:
      - "--certificatesresolvers.letsencrypt.acme.email=${EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    persistence:
      enabled: true
      path: /data
      size: 128Mi
EOF

echo "=== 2. REINICIANDO TRAEFIK PARA APLICAR AS CONFIGURAÇÕES ==="
kubectl rollout restart deployment traefik -n kube-system
kubectl rollout status deployment traefik -n kube-system --timeout=90s

echo "=============================================================================="
echo "✅ Let's Encrypt ACME configurado com sucesso no Traefik!"
echo "   Os certificados serão emitidos automaticamente para os domínios"
echo "   configurados com 'tls.certResolver: letsencrypt' no IngressRoute."
echo "=============================================================================="
