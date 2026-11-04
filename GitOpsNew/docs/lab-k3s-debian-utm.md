# Guia Prático: Cluster Kubernetes Multi-Nó (Debian 13 Trixie + K3s + UTM)

Este guia orienta o provisionamento de um cluster Kubernetes com topologia real de produção (1 Control-Plane + 1 Worker) utilizando máquinas virtuais leves no UTM (macOS Apple Silicon).

---

## 1. Topologia e Dimensionamento

| Máquina | Papel | vCPU | RAM | Disco | SO |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-master`** | Control-Plane (Server) | 2 | 2048 MB | 20 GB | Debian 13 "Trixie" (minimal/headless) |
| **`k8s-worker-1`** | Worker (Agent) | 2 | 2048 MB | 20 GB | Debian 13 "Trixie" (minimal/headless) |

### Por que Debian 13 Minimal?
Uma instalação mínima do Debian 13 sem ambiente gráfico (headless) consome apenas **~80 MB a 120 MB de RAM** em repouso. Isso deixa mais de **1.8 GB de RAM livre por VM** para a execução do plano de controle, Traefik, CoreDNS e os seus workloads de aplicação.

---

## 2. Criação das VMs no UTM

1. Baixe a ISO oficial: **Debian 13 Netinst para ARM64** (`debian-13.x.x-arm64-netinst.iso`).
2. No UTM:
   - Clique em **+** > **Virtualize** > **Linux**.
   - Aponte a ISO do Debian.
   - Configure: **2 vCPUs**, **2048 MB RAM**, **20 GB Disco**.
   - Na aba **Network**, selecione o modo **Bridged (Ponte)** na sua interface de rede (`en0` / Wi-Fi ou Ethernet) para que cada VM receba um IP direto do seu roteador local.
3. Durante a instalação do Debian:
   - Escolha o nome da máquina (`k8s-master` para a primeira, `k8s-worker-1` para a segunda).
   - Na seleção de softwares (*Software selection*), **desmarque** "Debian desktop environment" e **marque** apenas `SSH server` e `standard system utilities`.

Após iniciar, descubra o IP de cada VM executando `ip a` (exemplo: `192.168.1.100` para o master e `192.168.1.101` para o worker).

---

## 3. Preparação do Sistema Operacional (Em Ambas as VMs)

> **Atenção (Comportamento Clássico do Debian)**: Se você definiu uma senha para o `root` durante o instalador do Debian, o utilitário `sudo` não vem instalado por padrão.

### Passo 3.1: Acessar como Root
No terminal da VM, mude para o usuário root:

```bash
su -
```
*(Digite a senha do **root** que você cadastrou na instalação)*

---

### Passo 3.2: Instalar Pacotes e Habilitar o Sudo
Como `root` (o prompt estará terminando em `#`), instale os pacotes básicos e adicione seu usuário comum ao grupo `sudo`:

```bash
# Atualizar repositórios e instalar utilitários essenciais
apt update && apt install -y sudo curl iptables apparmor apparmor-utils

# Dar permissão de sudo para o usuário (substitua pelo seu usuário, ex: k8s-master)
usermod -aG sudo k8s-master

# Desativar swap (essencial para a estabilidade do Kubelet)
swapoff -a
sed -i '/swap/d' /etc/fstab

# Sair do root e voltar para o seu usuário
exit
```

*(Faça logout e login novamente via SSH ou recarregue a sessão para que o grupo `sudo` tenha efeito no usuário comum)*

> **Nota**: Não é necessário instalar Docker nem Containerd manualmente. O K3s já inclui e gerencia um runtime `containerd` embarcado de alta performance e baixo consumo de memória.

---

## 4. Instalação do Control-Plane (`k8s-master`)

No terminal do `k8s-master`:

```bash
# Instalar o K3s Server definindo o IP do nó e backend flannel padrão
curl -sfL https://get.k3s.io | sh -s - server \
  --node-ip=192.168.1.100 \
  --flannel-backend=vxlan \
  --write-kubeconfig-mode 644
```
*(Substitua `192.168.1.100` pelo IP real da sua VM master)*

### Obter o Token de Junção do Cluster
Para que o worker consiga ingressar no cluster, copie o token gerado pelo master:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```
*(Guarde o token exibido; ex: `K108a9c...::server:7b2...`)*

---

## 5. Instalação do Worker (`k8s-worker-1`)

No terminal do `k8s-worker-1`:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 \
  K3S_TOKEN="SEU_TOKEN_COPIADO_DO_MASTER" \
  sh -s - agent \
  --node-ip=192.168.1.101
```
*(Substitua os IPs pelos valores reais das suas VMs)*

---

## 6. Configuração do `kubectl` no seu Mac

Para gerenciar o cluster a partir do terminal do seu Mac (sem precisar ficar logado na VM):

1. No terminal do Mac, copie o arquivo de configuração do master:
   ```bash
   mkdir -p ~/.kube
   scp seu_usuario@192.168.1.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config-utm-k3s
   ```

2. Altere o endereço do servidor no arquivo copiado para o IP da VM master:
   ```bash
   sed -i '' 's/127.0.0.1/192.168.1.100/g' ~/.kube/config-utm-k3s
   ```

3. Exporte a variável ou passe o parâmetro para testar a comunicação:
   ```bash
   export KUBECONFIG=~/.kube/config-utm-k3s
   kubectl get nodes -o wide
   ```

**Saída esperada**:
```text
NAME           STATUS   ROLES                  AGE     VERSION        INTERNAL-IP
k8s-master     Ready    control-plane,master   5m      v1.31.x+k3s1   192.168.1.100
k8s-worker-1   Ready    <none>                 2m      v1.31.x+k3s1   192.168.1.101
```

---

## 7. Deploy das Aplicações (Front + Back)

Com o cluster operacional, aplique os manifestos declarativos deste repositório:

```bash
# 1. Aplicar o Backend (traefik/whoami - 2 réplicas)
kubectl apply -f apps/backend/

# 2. Aplicar o Frontend (nginxdemos/hello - 2 réplicas)
kubectl apply -f apps/frontend/
```

Verifique os pods rodando e observe como o Scheduler espalhou os contêineres entre os nós físicos:

```bash
kubectl get pods -o wide
```

---

## 8. Teste de Balanceamento de Carga e Roteamento

### Teste 1: Frontend via Navegador
Abra o navegador no seu Mac e acesse:
```text
http://192.168.1.100/
```
Pressione **F5** várias vezes. O campo **Server name** no centro da página exibirá o nome do Pod específico que respondeu àquela requisição (ex: `frontend-7d4b689bd-a1b2c` alternando para `frontend-7d4b689bd-x9y8z`), comprovando o balanceamento em ação.

### Teste 2: Backend via Linha de Comando
Execute no terminal do seu Mac:
```bash
for i in {1..8}; do
  curl -s http://192.168.1.100/api | grep "Hostname:"
done
```

**Saída esperada**:
```text
Hostname: backend-5f99bbcd64-t4z8q
Hostname: backend-5f99bbcd64-mn7k2
Hostname: backend-5f99bbcd64-t4z8q
Hostname: backend-5f99bbcd64-mn7k2
```
As respostas alternam automaticamente entre os Pods saudáveis por meio do Service Discovery e do Ingress do Traefik.
