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

echo "=== 3. EXPORTANDO CERTIFICADO PÚBLICO LOCALMENTE ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v kubeseal >/dev/null 2>&1; then
    kubeseal --fetch-cert \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=kube-system > "${SCRIPT_DIR}/sealed-secrets-public-cert.pem"
    echo "Certificado público salvo em: ${SCRIPT_DIR}/sealed-secrets-public-cert.pem"
else
    echo "Aviso: kubeseal CLI não encontrado no PATH imediato."
    echo "Caso precise exportar manualmente: kubeseal --fetch-cert > ${SCRIPT_DIR}/sealed-secrets-public-cert.pem"
fi

echo ""
echo "=== SEALED SECRETS INSTALADO COM SUCESSO! ==="
echo "O controller está pronto para descriptografar recursos do tipo SealedSecret."
