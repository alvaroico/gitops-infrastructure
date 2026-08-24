# Guia Passo a Passo de Replicação do Zero

> Roteiro completo e testado em produção para provisionar do zero um cluster **k3s + ArgoCD + Bitnami Sealed Secrets + Traefik HTTPS + PostgreSQL** em uma nova máquina virtual limpa (Google Cloud, AWS, Hetzner, etc.).

---

## 1. Pré-requisitos e Sizing Recomendado da VM

- **Sistema Operacional**: Ubuntu 22.04 LTS ou 24.04 LTS Minimal (x86_64).
- **Recursos Recomendados (FinOps Ideal)**:
  - **Instância**: 2 vCPUs dedicadas, 8 GB de RAM (ex: `e2-standard-2` no GCP ou equivalente).
  - **Disco**: 50 GB SSD / Disco Balanceado (`pd-balanced`).
  - **IP Público**: Estático / Reservado.
  - **Firewall de Nuvem**: Portas liberadas: `22` (SSH), `80` (HTTP) e `443` (HTTPS).
- **Proteção de Disco**: Agendamento de Snapshots diários de disco no console do provedor de nuvem (03:00 - 04:00 AM).

---

## 2. Sequência de Execução Automatizada (Scripts 01 a 10)

### Passo 1: Conectar na VM e Clonar o Repositório
```bash
git clone https://github.com/alvaroico/gitops-infrastructure.git
cd gitops-infrastructure
```

### Passo 2: Executar o Bootstrap do Cluster K3s
Instala o k3s, kubectl, jq, git, Traefik Ingress e o CLI `kubeseal`:
```bash
./scripts/01-bootstrap-vm.sh
export KUBECONFIG=~/.kube/config
```

### Passo 3: Instalar o ArgoCD
Instala os controllers oficiais do ArgoCD, configura modo insecure para proxy Traefik e cria o IngressRoute:
```bash
./scripts/02-setup-argocd.sh
```
*(Anote o usuário `admin` e a senha gerada exibida ao final do script).*

### Passo 4: Instalar o Bitnami Sealed Secrets Controller
Provisiona o controller do cofre e exporta a chave pública do cluster (`sealed-secrets-public-cert.pem`):
```bash
./scripts/03-setup-sealed-secrets.sh
```

### Passo 5: Configurar o Firewall (UFW)
Aplica regras restritas de segurança:
```bash
./scripts/04-configure-firewall.sh
```

### Passo 6: Cadastrar Repositório Privado e Credenciais GHCR no ArgoCD
```bash
export GITHUB_TOKEN="ghp_seu_token_aqui"
./scripts/05-add-private-repo-to-argocd.sh
```

### Passo 7: Configurar e Criptografar os Segredos dos Ambientes (Vault)
```bash
# 1. Banco de Dados Dev
cp secrets-raw/dev-postgres.env.example secrets-raw/dev-postgres.env
./scripts/06-encrypt-secrets-vault.sh postgres dev

# 2. Banco de Dados Prod
cp secrets-raw/prod-postgres.env.example secrets-raw/prod-postgres.env
./scripts/06-encrypt-secrets-vault.sh postgres prod
```

### Passo 8: Realizar o Deploy no ArgoCD
```bash
# Deploy Dev / Homologação
./scripts/07-deploy-homolog.sh

# Deploy Produção
./scripts/08-deploy-prod.sh
```

### Passo 9: Ativar Certificados HTTPS Automáticos (Let's Encrypt)
```bash
./scripts/09-setup-tls-letsencrypt.sh seu-email@empresa.com.br
```

### Passo 10: Validar e Agendar Rotina de Backup do Banco
```bash
./scripts/10-backup-postgres-database.sh dev
./scripts/10-backup-postgres-database.sh prod
```

---

## 3. Validação de Funcionamento

1. **Checar Status dos Pods:**
   ```bash
   kubectl get pods -A
   ```
2. **Checar Sincronização no ArgoCD:**
   ```bash
   kubectl get applications -n argocd
   ```
3. **Acessar Interfaces Web:**
   - **ArgoCD**: `https://argocd.<IP>.sslip.io` (ou `https://argocd.dominio.com.br`)
   - **Aplicações**: `https://app.<IP>.sslip.io` (ou `https://app.dominio.com.br`)
