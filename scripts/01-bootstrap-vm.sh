#!/usr/bin/env bash
# ==============================================================================
# 01-bootstrap-vm.sh - Instalação de Ferramentas Base e Cluster K3s
# ==============================================================================
set -euo pipefail

echo "=== 1. ATUALIZANDO PACOTES E INSTALANDO FERRAMENTAS BASE ==="
sudo apt-get update
sudo apt-get install -y curl wget git jq ufw tar

echo "=== 2. INSTALANDO O KUBERNETES K3S (COM TRAEFIK EMBUTIDO) ==="
if command -v k3s &>/dev/null; then
    echo "k3s já está instalado. Pulando download do k3s."
else
    curl -sfL https://get.k3s.io | sh -
fi

echo "=== 3. CONFIGURANDO KUBECONFIG EM ~/.kube/config ==="
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER":"$USER" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "=== 4. INSTALANDO A CLI DO KUBESEAL (SEALED SECRETS) ==="
if command -v kubeseal &>/dev/null; then
    echo "kubeseal CLI já está instalada."
else
    KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r .tag_name | sed 's/^v//')
    echo "Versão mais recente do kubeseal: $KUBESEAL_VERSION"
    curl -sL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" | tar -xvz kubeseal
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal
    rm -f kubeseal
fi

echo ""
echo "=== BOOTSTRAP DA VM CONCLUÍDO COM SUCESSO! ==="
echo "Você pode verificar o cluster com: kubectl get nodes"
