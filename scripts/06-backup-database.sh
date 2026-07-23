#!/usr/bin/env bash
# ==============================================================================
# 06-backup-database.sh - Automação de Backup do Banco PostgreSQL e Volumes K3s
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/home/alvaroico/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== 1. GERANDO BACKUP DO BANCO POSTGRESQL (EOS-PROD) ==="
if kubectl get ns eos-prod >/dev/null 2>&1; then
    kubectl exec -n eos-prod deployment/postgres -- pg_dump -U admin eos | gzip > "$BACKUP_DIR/eos-prod-db-$TIMESTAMP.sql.gz"
    echo "Backup Prod salvo em: $BACKUP_DIR/eos-prod-db-$TIMESTAMP.sql.gz"
fi

echo "=== 2. GERANDO BACKUP DO BANCO POSTGRESQL (EOS-DEV) ==="
if kubectl get ns eos-dev >/dev/null 2>&1; then
    kubectl exec -n eos-dev deployment/postgres -- pg_dump -U admin eos | gzip > "$BACKUP_DIR/eos-dev-db-$TIMESTAMP.sql.gz"
    echo "Backup Dev salvo em: $BACKUP_DIR/eos-dev-db-$TIMESTAMP.sql.gz"
fi

echo "=== 3. COMPRIMINDO PASTA DE VOLUMES PERSISTENTES DO K3S (PVCs) ==="
if [[ -d /var/lib/rancher/k3s/storage ]]; then
    sudo tar -czf "$BACKUP_DIR/k3s-volumes-$TIMESTAMP.tar.gz" /var/lib/rancher/k3s/storage 2>/dev/null || true
    echo "Backup de Volumes salvo em: $BACKUP_DIR/k3s-volumes-$TIMESTAMP.tar.gz"
fi

echo ""
echo "=== PROCESSO DE BACKUP CONCLUÍDO COM SUCESSO! ==="
ls -lh "$BACKUP_DIR"
