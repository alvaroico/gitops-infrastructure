#!/usr/bin/env bash
# ==============================================================================
# 11-cluster-maintenance.sh - Rotina de Otimização e Limpeza do Cluster K3s
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=========================================================="
echo "🧹 1. OTIMIZAÇÃO DE COMPONENTES DO ARGOCD (ECONOMIA DE RAM)"
echo "=========================================================="
# Desativa componentes não utilizados se não houver SSO/Dex ou Notifications configurados
if kubectl -n argocd get deployment argocd-dex-server >/dev/null 2>&1; then
    echo "→ Reduzindo réplicas do argocd-dex-server para 0..."
    kubectl -n argocd scale deployment argocd-dex-server --replicas=0
fi

if kubectl -n argocd get deployment argocd-notifications-controller >/dev/null 2>&1; then
    echo "→ Reduzindo réplicas do argocd-notifications-controller para 0..."
    kubectl -n argocd scale deployment argocd-notifications-controller --replicas=0
fi

echo ""
echo "=========================================================="
echo "🧽 2. LIMPEZA DE PODS / JOBS CONCLUÍDOS E COM FALHA"
echo "=========================================================="
echo "→ Removendo pods com status Succeeded (Completados)..."
kubectl delete pod --field-selector=status.phase==Succeeded -A --ignore-not-found=true

echo "→ Removendo pods com status Failed (Falhas antigas)..."
kubectl delete pod --field-selector=status.phase==Failed -A --ignore-not-found=true

echo ""
echo "=========================================================="
echo "📦 3. GARBAGE COLLECTION DE IMAGENS DE CONTAINER (CRICTL)"
echo "=========================================================="
if command -v k3s >/dev/null 2>&1; then
    echo "→ Executando limpeza de imagens órfãs/não utilizadas via k3s crictl..."
    sudo k3s crictl rmi --prune || true
elif command -v crictl >/dev/null 2>&1; then
    echo "→ Executando limpeza de imagens órfãs via crictl..."
    sudo crictl rmi --prune || true
fi

echo ""
echo "=========================================================="
echo "📊 4. STATUS ATUAL DOS RECURSOS DO CLUSTER"
echo "=========================================================="
if kubectl top nodes >/dev/null 2>&1; then
    echo "--- Consumo do Nó ---"
    kubectl top nodes || true
    echo ""
    echo "--- Top 10 Pods por Consumo de Memória ---"
    (kubectl top pods -A --sort-by=memory 2>/dev/null | head -n 11) || true
else
    echo "Aviso: metrics-server ainda não está respondendo métricas no momento."
fi

echo ""
echo "=== MANUTENÇÃO E LIMPEZA CONCLUÍDAS COM SUCESSO! ==="
