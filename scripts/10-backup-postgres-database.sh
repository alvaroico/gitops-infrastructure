#!/usr/bin/env bash
# ==============================================================================
# 10-backup-postgres-database.sh - Backup Lógico Automatizado do PostgreSQL (K3s)
# ==============================================================================
set -euo pipefail

ENV_NAME="${1:-dev}"
NAMESPACE="${ENV_NAME}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_DIR="${HOME}/backups/postgres/${ENV_NAME}"
mkdir -p "${BACKUP_DIR}"

DB_NAME="${2:-}"
if [ -z "${DB_NAME}" ]; then
    case "${ENV_NAME}" in
        dev|homolog)
            DB_NAME="app_dev"
            ;;
        prod|production)
            DB_NAME="app_prod"
            ;;
        *)
            DB_NAME="app_${ENV_NAME}"
            ;;
    esac
fi

BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "=============================================================================="
echo "EXECUTANDO BACKUP LÓGICO DO POSTGRESQL (${ENV_NAME})"
echo "=============================================================================="
echo "Namespace:   ${NAMESPACE}"
echo "Banco:       ${DB_NAME}"
echo "Destino:     ${BACKUP_FILE}"
echo "------------------------------------------------------------------------------"

if [ -z "${KUBECONFIG:-}" ]; then
    if [ -f "${HOME}/.kube/config" ]; then
        export KUBECONFIG="${HOME}/.kube/config"
    elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
        export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
    fi
fi

# Localizar o Pod ativo do Postgres no namespace
POSTGRES_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "${POSTGRES_POD}" ]; then
    echo "Erro: Nenhum pod com label 'app=postgres' encontrado no namespace '${NAMESPACE}'."
    exit 1
fi

echo "Executando pg_dump no pod ${POSTGRES_POD}..."
kubectl exec -i "${POSTGRES_POD}" -n "${NAMESPACE}" -- pg_dump -U postgres "${DB_NAME}" | gzip > "${BACKUP_FILE}"

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo ""
echo "=== BACKUP CONCLUÍDO COM SUCESSO! ==="
echo "Arquivo: ${BACKUP_FILE} (${FILE_SIZE})"
echo "Retenção: Mantendo os últimos 15 backups..."
find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -type f -mtime +15 -delete || true
