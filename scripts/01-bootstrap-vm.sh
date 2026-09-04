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

echo "=== 3. CONFIGURANDO KUBECONFIG EM ~/.kube/config E PERMISSÕES ==="
sudo mkdir -p /etc/rancher/k3s
if ! grep -q "write-kubeconfig-mode" /etc/rancher/k3s/config.yaml 2>/dev/null; then
    echo 'write-kubeconfig-mode: "0644"' | sudo tee -a /etc/rancher/k3s/config.yaml >/dev/null
fi

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER":"$USER" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# Adicionar export KUBECONFIG no ~/.bashrc do usuário caso ainda não exista
if ! grep -q 'KUBECONFIG=~/.kube/config' ~/.bashrc 2>/dev/null; then
    echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
    echo "Adicionado 'export KUBECONFIG=~/.kube/config' no ~/.bashrc"
fi
sudo chmod 644 /etc/rancher/k3s/k3s.yaml 2>/dev/null || true

echo "=== 4. INSTALANDO A CLI DO KUBESEAL (SEALED SECRETS) ==="
if command -v kubeseal &>/dev/null; then
    echo "kubeseal CLI já está instalada."
else
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        KUBESEAL_ARCH="arm64"
    else
        KUBESEAL_ARCH="amd64"
    fi

    KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r .tag_name 2>/dev/null | sed 's/^v//' || echo "0.26.0")
    if [[ "$KUBESEAL_VERSION" == "null" || -z "$KUBESEAL_VERSION" ]]; then
        KUBESEAL_VERSION="0.26.0"
    fi

    echo "Versão selecionada do kubeseal: $KUBESEAL_VERSION (Arquitetura: $KUBESEAL_ARCH)"
    curl -sL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-${KUBESEAL_ARCH}.tar.gz" | tar -xvz kubeseal
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal
    rm -f kubeseal
fi

echo ""
echo "=== BOOTSTRAP DA VM CONCLUÍDO COM SUCESSO! ==="
echo "Dica: Para atualizar a variável na sessão atual, rode: export KUBECONFIG=~/.kube/config"
