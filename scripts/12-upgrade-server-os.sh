#!/usr/bin/env bash
# ==============================================================================
# 12-upgrade-server-os.sh - Atualização Segura do Sistema Operacional e Host K3s
# ==============================================================================
# Executa em sequência:
#   1. Verificação de privilégios e espaço livre em disco (mínimo 2 GB)
#   2. Persistência de permissões do K3s (write-kubeconfig-mode 0644)
#   3. Backup lógico do PostgreSQL (estágios dev e prod, se ativos)
#   4. Otimização do cluster e limpeza de imagens de containers
#   5. Atualização de pacotes do sistema (apt update && apt upgrade)
#   6. Detecção de necessidade de reboot (/var/run/reboot-required)
#   7. Parada graciosa do K3s e reinicialização controlada
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTO_REBOOT=false
FORCE_REBOOT=false
ASSUME_YES=false
SKIP_BACKUP=false

# ------------------------------------------------------------------------------
# Processamento de Argumentos
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --reboot)
            AUTO_REBOOT=true
            shift
            ;;
        --force-reboot)
            FORCE_REBOOT=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [OPÇÕES]"
            echo ""
            echo "Opções:"
            echo "  --reboot        Reinicia automaticamente se houver pacotes exigindo reboot"
            echo "  --force-reboot  Força o reboot ao final da atualização independente de exigência"
            echo "  -y, --yes       Assume 'sim' em todas as confirmações interativas"
            echo "  --skip-backup   Pula o backup do banco de dados (NÃO RECOMENDADO)"
            echo "  -h, --help      Exibe esta ajuda"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            echo "Execute '$0 --help' para ver as opções disponíveis."
            exit 1
            ;;
    esac
done

echo "=============================================================================="
echo "   INICIANDO ROTINA DE ATUALIZAÇÃO SEGURA DO SERVIDOR (HUB GITOPS / K3S)"
echo "=============================================================================="
echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host:      $(hostname) ($(uname -m))"
echo "------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# 1. Validação de Pré-requisitos, Permissões e Espaço em Disco
# ------------------------------------------------------------------------------
echo "=== [1/5] VERIFICANDO PRÉ-REQUISITOS E ESPAÇO EM DISCO ==="

# Validar sudo sem senha pendente
sudo -v

# Configurar KUBECONFIG
if [ -z "${KUBECONFIG:-}" ]; then
    if [ -f "${HOME}/.kube/config" ]; then
        export KUBECONFIG="${HOME}/.kube/config"
    elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
        export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
    fi
fi

# Garantir persistência de permissões 0644 no K3s para futuros reboots
sudo mkdir -p /etc/rancher/k3s
if ! grep -q "write-kubeconfig-mode" /etc/rancher/k3s/config.yaml 2>/dev/null; then
    echo 'write-kubeconfig-mode: "0644"' | sudo tee -a /etc/rancher/k3s/config.yaml >/dev/null
fi
sudo chmod 644 /etc/rancher/k3s/k3s.yaml 2>/dev/null || true

# Validar espaço mínimo livre em disco (2 GB)
FREE_KB=$(df -k / | awk 'NR==2 {print $4}')
if [ "${FREE_KB}" -lt 2097152 ]; then
    echo "ERRO CRÍTICO: Menos de 2 GB de espaço livre em disco (${FREE_KB} KB)."
    echo "Libere espaço antes de prosseguir para evitar falhas durante o download dos pacotes."
    exit 1
fi
echo "Espaço livre em disco: $(df -h / | awk 'NR==2 {print $4}') (OK)"

# ------------------------------------------------------------------------------
# 2. Backup Lógico dos Bancos de Dados
# ------------------------------------------------------------------------------
echo ""
echo "=== [2/5] BACKUP LÓGICO DO POSTGRESQL ==="

if [ "${SKIP_BACKUP}" = true ]; then
    echo "AVISO: Backup pulado (--skip-backup ativado)."
else
    if [ -f "${SCRIPT_DIR}/10-backup-postgres-database.sh" ]; then
        # Verificar se existem pods do postgres no namespace dev
        if kubectl get pods -n dev -l app=postgres >/dev/null 2>&1; then
            echo "Executando backup do PostgreSQL (dev)..."
            bash "${SCRIPT_DIR}/10-backup-postgres-database.sh" dev || true
        fi

        # Verificar se existem pods do postgres no namespace prod
        if kubectl get pods -n prod -l app=postgres >/dev/null 2>&1; then
            echo "Executando backup do PostgreSQL (prod)..."
            bash "${SCRIPT_DIR}/10-backup-postgres-database.sh" prod || true
        fi
    elif [ -f "${SCRIPT_DIR}/06-backup-database.sh" ]; then
        echo "Executando backup via 06-backup-database.sh..."
        bash "${SCRIPT_DIR}/06-backup-database.sh" || true
    else
        echo "AVISO: Nenhum script de backup encontrado em ${SCRIPT_DIR}."
    fi
fi

# ------------------------------------------------------------------------------
# 3. Limpeza de Recursos e Garbage Collection de Imagens
# ------------------------------------------------------------------------------
echo ""
echo "=== [3/5] OTIMIZAÇÃO E LIMPEZA PRÉVIA DO CLUSTER ==="
if [ -f "${SCRIPT_DIR}/11-cluster-maintenance.sh" ]; then
    bash "${SCRIPT_DIR}/11-cluster-maintenance.sh" || true
else
    if command -v k3s >/dev/null 2>&1; then
        echo "Executando limpeza de imagens órfãs via crictl..."
        sudo k3s crictl rmi --prune || true
    fi
fi

# ------------------------------------------------------------------------------
# 4. Atualização de Pacotes do Sistema Operacional (APT)
# ------------------------------------------------------------------------------
echo ""
echo "=== [4/5] ATUALIZANDO PACOTES DO SISTEMA OPERACIONAL (UBUNTU) ==="
sudo apt-get update -y

echo "Instalando atualizações pendentes..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

echo "Removendo pacotes e kernels antigos..."
sudo apt-get autoremove -y
sudo apt-get clean

# ------------------------------------------------------------------------------
# 5. Avaliação e Execução de Reinicialização Segura
# ------------------------------------------------------------------------------
echo ""
echo "=== [5/5] VERIFICAÇÃO DE REINICIALIZAÇÃO ==="

REBOOT_REQUIRED=false
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED=true
    echo "STATUS: Reinicialização NECESSÁRIA pelo sistema operacional (novo kernel ou bibliotecas atualizadas)."
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo "Pacotes causadores:"
        cat /var/run/reboot-required.pkgs | sed 's/^/  - /'
    fi
else
    echo "STATUS: Nenhuma exigência imediata de reinicialização detectada."
fi

EXECUTE_REBOOT=false

if [ "${FORCE_REBOOT}" = true ]; then
    EXECUTE_REBOOT=true
elif [ "${AUTO_REBOOT}" = true ] && [ "${REBOOT_REQUIRED}" = true ]; then
    EXECUTE_REBOOT=true
elif [ "${REBOOT_REQUIRED}" = true ]; then
    if [ "${ASSUME_YES}" = true ]; then
        EXECUTE_REBOOT=true
    else
        read -r -p "Deseja reiniciar o servidor agora de forma graciosa? [s/N]: " RESP
        if [[ "${RESP}" =~ ^[sSyY]$ ]]; then
            EXECUTE_REBOOT=true
        fi
    fi
fi

if [ "${EXECUTE_REBOOT}" = true ]; then
    echo ""
    echo "=============================================================================="
    echo "PARADA GRACIOSA DO K3S E REINICIALIZAÇÃO DO SERVIDOR"
    echo "=============================================================================="
    echo "1. Desligando o serviço do K3s graciosamente (garantindo flush do PostgreSQL)..."
    sudo systemctl stop k3s || true
    sleep 3

    echo "2. Disparando reinicialização do sistema operacional em 3 segundos..."
    sleep 3
    sudo reboot
else
    echo ""
    echo "=============================================================================="
    echo "ATUALIZAÇÃO CONCLUÍDA COM SUCESSO SEM REBOOT!"
    echo "=============================================================================="
    if [ "${REBOOT_REQUIRED}" = true ]; then
        echo "IMPORTANTE: Lembre-se de reiniciar o servidor quando for oportuno executando:"
        echo "  sudo systemctl stop k3s && sudo reboot"
    else
        echo "O cluster e o sistema operacional estão atualizados e operacionais."
    fi
fi
