#!/usr/bin/env bash
# ==============================================================================
# 07-deploy-kargo-pipelines.sh - Aplica Projetos, Warehouses e Estágios no Kargo
# ==============================================================================
set -euo pipefail

export KUBECONFIG=~/.kube/config

echo "=== 1. APLICANDO KARGO PROJECT ==="
kubectl apply -f kargo/project.yaml

echo "=== 2. APLICANDO KARGO WAREHOUSE ==="
kubectl apply -f kargo/warehouse.yaml

echo "=== 3. APLICANDO PIPELINES DE ESTÁGIOS (DEV / PROD) ==="
kubectl apply -f kargo/stages/eos-pipeline.yaml
kubectl apply -f kargo/stages/postgres-pipeline.yaml

echo ""
echo "=== STATUS ATUAL DOS ESTÁGIOS NO KARGO ==="
kubectl get projects,warehouses,stages -n eos-platform
echo ""
echo "🚀 Pipelines ativados com sucesso no Kargo!"
