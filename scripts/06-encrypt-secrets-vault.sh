#!/usr/bin/env bash
# ==============================================================================
# 06-encrypt-secrets-vault.sh - Criptografar Variáveis Sensíveis via Kubeseal
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Definir KUBECONFIG caso exista no ambiente ou nos caminhos padrão
if [ -z "${KUBECONFIG:-}" ]; then
    if [ -f "${HOME}/.kube/config" ]; then
        export KUBECONFIG="${HOME}/.kube/config"
    elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
        export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
    fi
fi

RAW_APP="${1:-backend}"
ENV_NAME="${2:-dev}"

# Normalizar apelidos comuns para os nomes oficiais dos diretórios em apps/
case "${RAW_APP}" in
    backend|api|server)
        APP_NAME="backend"
        APP_TYPE="backend"
        ;;
    frontend|front|web|client)
        APP_NAME="frontend"
        APP_TYPE="frontend"
        ;;
    postgres|postgresql|db|database)
        APP_NAME="postgres"
        APP_TYPE="postgres"
        ;;
    *)
        APP_NAME="${RAW_APP}"
        APP_TYPE="${RAW_APP}"
        ;;
esac

SECRET_NAME="${APP_NAME}-secrets"
NAMESPACE="${ENV_NAME}"
OUTPUT_DIR="${ROOT_DIR}/apps/${APP_NAME}/overlays/${ENV_NAME}"
OUTPUT_SEALED="${OUTPUT_DIR}/sealed-secret.yaml"

ENV_FILE="${3:-}"
if [ -z "${ENV_FILE}" ]; then
    if [ -f "${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_NAME}.env" ]; then
        ENV_FILE="${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_NAME}.env"
    elif [ -f "${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_TYPE}.env" ]; then
        ENV_FILE="${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_TYPE}.env"
    elif [ -f "${ROOT_DIR}/secrets-raw/${APP_NAME}.env" ]; then
        ENV_FILE="${ROOT_DIR}/secrets-raw/${APP_NAME}.env"
    elif [ -f "${ROOT_DIR}/secrets-raw/${APP_TYPE}.env" ]; then
        ENV_FILE="${ROOT_DIR}/secrets-raw/${APP_TYPE}.env"
    elif [ -f "${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_NAME}.env.example" ]; then
        echo "Aviso: Arquivo .env real não encontrado. Utilizando gabarito 'secrets-raw/${ENV_NAME}-${APP_NAME}.env.example'..."
        ENV_FILE="${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_NAME}.env.example"
    elif [ -f "${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_TYPE}.env.example" ]; then
        echo "Aviso: Arquivo .env real não encontrado. Utilizando gabarito 'secrets-raw/${ENV_NAME}-${APP_TYPE}.env.example'..."
        ENV_FILE="${ROOT_DIR}/secrets-raw/${ENV_NAME}-${APP_TYPE}.env.example"
    else
        echo "Erro: Nenhum arquivo env encontrado para '${APP_NAME}' em 'secrets-raw/'."
        echo "Copie 'secrets-raw/${ENV_NAME}-${APP_TYPE}.env.example' para 'secrets-raw/${ENV_NAME}-${APP_TYPE}.env' e preencha as variáveis."
        exit 1
    fi
fi

echo "=============================================================================="
echo "CRIPTOGRAFANDO SEGREDOS (${APP_NAME} - ${ENV_NAME}) VIA KUBESEAL"
echo "=============================================================================="
echo "App:        ${APP_NAME}"
echo "Namespace:  ${NAMESPACE}"
echo "Secret:     ${SECRET_NAME}"
echo "Fonte .env: ${ENV_FILE}"
echo "Destino:    ${OUTPUT_SEALED}"
echo "------------------------------------------------------------------------------"

if [ ! -f "${ENV_FILE}" ]; then
    echo "Erro: Arquivo '${ENV_FILE}' não encontrado localmente."
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Erro: kubectl CLI não encontrado no sistema."
    exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
        echo "kubeseal CLI não encontrado. Instalando automaticamente via Homebrew..."
        brew install kubeseal
    else
        echo "Erro: kubeseal CLI não encontrado no sistema."
        echo "Instale no macOS: brew install kubeseal"
        echo "Instale no Linux: https://github.com/bitnami-labs/sealed-secrets/releases"
        exit 1
    fi
fi

TMP_SECRET=$(mktemp)

mkdir -p "${OUTPUT_DIR}"

echo "1. Gerando manifesto Secret temporário em memória..."
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-env-file="${ENV_FILE}" \
  --dry-run=client -o yaml > "${TMP_SECRET}"

echo "2. Criptografando com a chave pública do cluster via kubeseal..."
CERT_FLAG=""
if [ -f "${SCRIPT_DIR}/sealed-secrets-public-cert.pem" ]; then
    CERT_FLAG="--cert ${SCRIPT_DIR}/sealed-secrets-public-cert.pem"
elif [ -f "${ROOT_DIR}/scripts/sealed-secrets-public-cert.pem" ]; then
    CERT_FLAG="--cert ${ROOT_DIR}/scripts/sealed-secrets-public-cert.pem"
fi

kubeseal --format yaml ${CERT_FLAG} < "${TMP_SECRET}" > "${OUTPUT_SEALED}.tmp"
if [ ! -s "${OUTPUT_SEALED}.tmp" ] || ! grep -q "kind: SealedSecret" "${OUTPUT_SEALED}.tmp"; then
    echo "Erro: Falha ao gerar SealedSecret via kubeseal."
    cat "${OUTPUT_SEALED}.tmp"
    rm -f "${OUTPUT_SEALED}.tmp" "${TMP_SECRET}"
    exit 1
fi
mv "${OUTPUT_SEALED}.tmp" "${OUTPUT_SEALED}"
rm -f "${TMP_SECRET}"

echo ""
echo "=== SEALED SECRET GERADO COM SUCESSO! ==="
echo "Arquivo gerado: ${OUTPUT_SEALED}"
echo "Você pode comitar o arquivo '${OUTPUT_SEALED}' com segurança no Git."

