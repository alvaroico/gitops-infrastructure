# Guia Passo a Passo de Replicação do Zero

Este guia contém a sequência exata de comandos para replicar toda a infraestrutura GitOps com ArgoCD, k3s, Traefik, Sealed Secrets, Firewall UFW e as aplicações EOS (**Dev** e **Prod**) em uma **nova Maquina Virtual limpa**.

---

## Pré-requisitos
- Uma VM Linux (Ubuntu 22.04 LTS ou Debian 12) recém-criada.
- Acesso SSH com privilégios de `sudo`.

---

## Sequência de Execução

### Passo 1: Clonar o Repositório de Infraestrutura
```bash
mkdir -p /home/alvaroico/projects
cd /home/alvaroico/projects
# Se este repositório estiver local ou no GitHub:
# git clone https://github.com/alvaroico/gitops-infrastructure.git
```

### Passo 2: Executar o Bootstrap da VM
Instala o k3s, kubectl, jq, git e o CLI `kubeseal` (com detecção automática de arquitetura ARM64/AMD64 e inclusão do KUBECONFIG no `~/.bashrc`).
```bash
cd /home/alvaroico/projects/gitops-infrastructure/scripts
./01-bootstrap-vm.sh
export KUBECONFIG=~/.kube/config
```
*Verificação:*
```bash
kubectl get nodes
```

### Passo 3: Instalar o ArgoCD
Instala o ArgoCD no namespace `argocd`, habilita modo HTTP insecure e cria o IngressRoute no Traefik para `argocd.alvaroico-teste.com.br`.
```bash
./02-setup-argocd.sh
```
*Verificação:*
```bash
kubectl get pods -n argocd
```

### Passo 4: Instalar o Sealed Secrets Controller
Instala o controller do Bitnami Sealed Secrets (`v0.38.4/controller.yaml`) para gerenciamento de senhas criptografadas.
```bash
./03-setup-sealed-secrets.sh
```
*Verificação:*
```bash
kubectl get pods -n kube-system | grep sealed-secrets
```

### Passo 5: Configurar o Firewall (UFW)
Aplica as regras de segurança Zero Trust (bloqueia tudo e abre portas 22, 80 e 443 + rede k3s).
```bash
./04-configure-firewall.sh
```

### Passo 6: Criar Segredos e Implantar os Ambientes (Dev e Prod)

#### 1. Criar Namespace e Secret de Desenvolvimento (`eos-dev`):
```bash
kubectl create namespace eos-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic eos-secrets \
  --namespace eos-dev \
  --from-literal=POSTGRES_USER=admin \
  --from-literal=POSTGRES_PASSWORD=eosdevsecretpass \
  --from-literal=JWT_SECRET=superjwtkey123dev \
  --from-literal=MAILTRAP_USERNAME=mailtrapuser \
  --from-literal=MAILTRAP_API_KEY=mailtrapkey \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 2. Criar Namespace e Secret de Produção (`eos-prod`):
```bash
kubectl create namespace eos-prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic eos-secrets \
  --namespace eos-prod \
  --from-literal=POSTGRES_USER=admin \
  --from-literal=POSTGRES_PASSWORD=eosprodsecretpass \
  --from-literal=JWT_SECRET=superjwtkey123prod \
  --from-literal=MAILTRAP_USERNAME=mailtrapuser \
  --from-literal=MAILTRAP_API_KEY=mailtrapkey \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 3. Cadastrar Repositório Privado no ArgoCD (com Token do GitHub):
```bash
./05-add-private-repo-to-argocd.sh
```

#### 4. Aplicar as Applications no ArgoCD:
```bash
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/eos-dev-application.yaml
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/eos-prod-application.yaml
```

### Passo 7: Mapeamento de DNS (/etc/hosts)
Edite o arquivo `/etc/hosts` na VM e na sua máquina Host:
```text
192.168.64.9 argocd.alvaroico-teste.com.br
192.168.64.9 eos-dev.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

---

## Validação Final de Funcionamento

1. **ArgoCD Web UI**: Acesse `http://argocd.alvaroico-teste.com.br` (Usuário: `admin`).
2. **API EOS Dev**: Acesse `http://eos-dev.alvaroico-teste.com.br/Swagger`.
3. **API EOS Prod**: Acesse `http://eos.alvaroico-teste.com.br/Swagger`.
4. **Checar Status no Cluster**:
   ```bash
   kubectl get pods,svc,ingressroute -n eos-dev
   kubectl get pods,svc,ingressroute -n eos-prod
   ```
