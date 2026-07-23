# Guia Completo de Backup e Restauração no Kubernetes (k3s)

Este documento descreve os procedimentos de backup e restauração do Banco de Dados PostgreSQL e dos Volumes Persistentes (PVCs) no ambiente k3s.

---

## 1. Estratégias de Backup Utilizadas

1. **Backup do Banco de Dados PostgreSQL (`pg_dump`)**:
   - Extrai o dump SQL diretamente do container PostgreSQL rodando no cluster via `kubectl exec`.
   - Gera arquivos `.sql.gz` leves e fáceis de armazenar fora do cluster.
2. **Backup dos Volumes Físicos do k3s (PVCs)**:
   - O k3s armazena os dados dos PVCs de upload e banco em `/var/lib/rancher/k3s/storage/`.
   - O script gera um arquivo comprimido `.tar.gz` contendo todos os dados gravados nos discos virtuais.

---

## 2. Comandos Manuais de Backup

### Backup do Banco de Dados (Produção)
```bash
export KUBECONFIG=~/.kube/config
mkdir -p /home/alvaroico/backups
kubectl exec -n eos-prod deployment/postgres -- pg_dump -U admin eos | gzip > /home/alvaroico/backups/eos-prod-$(date +%F).sql.gz
```

### Backup do Banco de Dados (Desenvolvimento)
```bash
export KUBECONFIG=~/.kube/config
mkdir -p /home/alvaroico/backups
kubectl exec -n eos-dev deployment/postgres -- pg_dump -U admin eos | gzip > /home/alvaroico/backups/eos-dev-$(date +%F).sql.gz
```

### Backup dos Volumes Físicos (PVCs)
```bash
sudo tar -czf /home/alvaroico/backups/k3s-volumes-$(date +%F).tar.gz /var/lib/rancher/k3s/storage
```

---

## 3. Como Restaurar um Backup do Banco de Dados

Caso você precise restaurar um backup SQL em um banco limpo:

```bash
# Restaurar em Produção:
gunzip -c /home/alvaroico/backups/eos-prod-2026-07-23.sql.gz | kubectl exec -i -n eos-prod deployment/postgres -- psql -U admin -d eos

# Restaurar em Desenvolvimento:
gunzip -c /home/alvaroico/backups/eos-dev-2026-07-23.sql.gz | kubectl exec -i -n eos-dev deployment/postgres -- psql -U admin -d eos
```

---

## 4. Script Automatizado (`scripts/06-backup-database.sh`)

Para executar o backup completo automaticamente:

```bash
/home/alvaroico/projects/gitops-infrastructure/scripts/06-backup-database.sh
```

### Opcional: Agendar Backup Diário com Cron no Linux
Adicione a seguinte linha no `crontab -e`:
```text
0 3 * * * /home/alvaroico/projects/gitops-infrastructure/scripts/06-backup-database.sh > /dev/null 2>&1
```
*(Executa o backup automaticamente todos os dias às 03h00 da manhã).*
