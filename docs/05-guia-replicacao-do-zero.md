# Guia Passo a Passo de Replicação do Zero

Este guia contém a sequência exata de comandos para replicar toda a infraestrutura GitOps com ArgoCD, k3s, Traefik, Sealed Secrets, Firewall e a API EOS em uma **nova Maquina Virtual limpa**.

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
# Se este repositório estiver local:
# (Os scripts estarão em /home/alvaroico/projects/gitops-infrastructure/scripts)
```

### Passo 2: Executar o Bootstrap da VM
Instala o k3s, kubectl, jq, git e o CLI `kubeseal`.
```bash
cd /home/alvaroico/projects/gitops-infrastructure/scripts
./01-bootstrap-vm.sh
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
Instala o controller do Bitnami Sealed Secrets para gerenciamento de senhas criptografadas.
```bash
./03-setup-sealed-secrets.sh
```
*Verificação:*
```bash
kubectl get pods -n kube-system | grep sealed-secrets
```

### Passo 5: Configurar o Firewall (UFW)
Aplica as regras de segurança Zero Trust (bloqueia tudo e abre portas 22, 80 e 443).
```bash
./04-configure-firewall.sh
```

### Passo 6: Mapeamento de DNS (/etc/hosts)
Edite o arquivo `/etc/hosts` na VM e na sua máquina Host:
```text
192.168.64.9 argocd.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

### Passo 7: Aplicar a Aplicação EOS no ArgoCD
```bash
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/eos-application.yaml
```

---

## Validação Final de Funcionamento

1. **ArgoCD Web UI**: Acesse `http://argocd.alvaroico-teste.com.br` (Usuário: `admin`).
2. **API EOS**: Acesse `http://eos.alvaroico-teste.com.br/Swagger`.
3. **Checar Status no Cluster**:
   ```bash
   kubectl get pods,svc,ingressroute -n eos
   ```
