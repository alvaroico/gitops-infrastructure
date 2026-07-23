#!/usr/bin/env bash
# ==============================================================================
# 04-configure-firewall.sh - Hardening do Firewall UFW (Zero-Trust Security)
# ==============================================================================
set -euo pipefail

echo "=== 1. DESABILITANDO E RESETANDO REGRAS ANTERIORES DO UFW ==="
sudo ufw --force reset

echo "=== 2. DEFININDO POLÍTICAS PADRÃO (BLOQUEAR ENTRADA / PERMITIR SAÍDA) ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "=== 3. PERMITINDO PORTAS DE SERVIÇO ESTRITAS ==="
sudo ufw allow 22/tcp comment 'SSH Access'
sudo ufw allow 80/tcp comment 'HTTP Traefik Ingress'
sudo ufw allow 443/tcp comment 'HTTPS Traefik Ingress'

echo "=== 4. LIBERANDO INTERFACES DE REDE INTERNAS DO K3S E LOOPBACK ==="
sudo ufw allow in on lo comment 'Loopback Interface'
sudo ufw allow in on cni0 comment 'K3s CNI Container Network'
sudo ufw allow in on flannel.1 comment 'K3s Flannel Overlay Network'

echo "=== 5. HABILITANDO O FIREWALL UFW ==="
sudo ufw --force enable

echo ""
echo "=== STATUS FINAL DO FIREWALL UFW ==="
sudo ufw status verbose
