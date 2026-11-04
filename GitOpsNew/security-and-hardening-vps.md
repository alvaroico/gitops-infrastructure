# Diretrizes de Segurança e Hardening para Kubernetes em VPS Pública

Este documento define a política de segurança, matriz de portas e procedimentos de blindagem para implantar este cluster em servidores virtuais com endereçamento IP público (ex: Hetzner, AWS, Linode, DigitalOcean, Oracle Cloud).

---

## 1. Modelo de Ameaças em Ambientes Públicos

Ao expor uma máquina diretamente na internet pública (`0.0.0.0/0`), ela se torna alvo imediato de varreduras automatizadas (*port scanners* como Shodan, Censys e masscan) e ataques dirigidos.

### Vetores Críticos de Ataque:
1. **API Server do Kubernetes (`6443`)**: Alvo de tentativas de exploração de vulnerabilidades de autenticação/RBAC e bugs de dia zero no plano de controle.
2. **Kubelet API (`10250`)**: Permite execução de código em contêineres e leitura de logs caso desprotegida.
3. **Plano de Dados da Rede de Pods (Flannel VXLAN `8472`)**: Sem criptografia, pacotes de rede entre pods de diferentes servidores podem ser interceptados se trafegarem pela internet aberta.
4. **SSH (`22`)**: Alvo ininterrupto de ataques de força bruta de senhas.
5. **Endpoints de Debug (`/api`, `/healthz`, `/metrics`)**: Vazamento da topologia de IPs e nós internos.

---

## 2. Matriz de Portas e Firewall (Host Level)

| Porta / Protocolo | Serviço | Exposição Pública | Regra de Firewall Recomendada |
| :--- | :--- | :--- | :--- |
| **`6443/tcp`** | K8s API Server | **PROIBIDA** | Permitir **apenas** o IP público do operador (seu Mac) ou acesso via VPN (Wireguard/Tailscale). |
| **`22/tcp`** | SSH | **RESTRITA** | Restringir por IP sempre que possível; desativar senha e aceitar apenas chave `ed25519`. |
| **`10250/tcp`** | Kubelet API | **PROIBIDA** | Permitir **apenas** na interface de rede privada interna (VPC). Bloquear na interface pública. |
| **`8472/udp`** | Flannel VXLAN | **PROIBIDA** | Permitir **apenas** na rede privada entre os nós. Se usar IP público entre nós, ativar Wireguard nativo no K3s. |
| **`80/tcp`** | Ingress HTTP | **LIBERADA** | Redirecionamento permanente (301) para HTTPS `443`. |
| **`443/tcp`** | Ingress HTTPS | **LIBERADA** | Tráfego web legítimo encriptado com certificados válidos (Let's Encrypt / cert-manager). |

---

## 3. Configuração do Firewall no Sistema Operacional (UFW)

Execute em cada um dos nós da VPS antes de subir o cluster:

```bash
# 1. Definir políticas padrão de bloqueio
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Permitir SSH (se seu IP for dinâmico, limite as tentativas)
sudo ufw limit 22/tcp comment 'SSH com rate-limiting contra forca bruta'

# 3. Permitir tráfego HTTP/HTTPS do Ingress Traefik para o mundo
sudo ufw allow 80/tcp comment 'Traefik HTTP'
sudo ufw allow 443/tcp comment 'Traefik HTTPS'

# 4. Permitir a porta 6443 da API do Kubernetes APENAS do seu IP fixo de casa/escritório
# (Substitua 203.0.113.50 pelo seu IP público retornado por: curl -4 ifconfig.me)
sudo ufw allow from 203.0.113.50 to any port 6443 proto tcp comment 'K8s API Mac Operador'

# 5. Permitir TODA a comunicação interna entre as VMs na rede privada do provedor
# (Exemplo: se a rede privada da Hetzner/AWS for a faixa 10.0.0.0/16)
sudo ufw allow in on eth1 to any comment 'Trafego livre na rede privada interna VPC'

# 6. Habilitar o firewall
sudo ufw enable
```

---

## 4. Hardening do K3s para VPS Pública

### 4.1. Criptografia Nativa entre Nós (Wireguard)
Se as suas VMs não possuírem rede privada e precisarem se comunicar pelos IPs públicos, configure o K3s para encriptar todo o tráfego de Pod para Pod usando Wireguard nativo do kernel:

```bash
# No Master:
curl -sfL https://get.k3s.io | sh -s - server \
  --flannel-backend=wireguard-native \
  --node-ip=<IP_PUBLICO_MASTER>
```

### 4.2. Certificados TLS Automáticos (Let's Encrypt)
Nunca mantenha aplicações em produção na porta 80 sem criptografia. Utilize o `cert-manager` para emitir e renovar certificados SSL gratuitos automaticamente:
* Instalação via Helm: `helm repo add jetstack https://charts.jetstack.io`
* Configurar um `ClusterIssuer` do Let's Encrypt acoplado ao Ingress do Traefik.

### 4.3. Proteção de Endpoints Internos
Endpoints de teste como `traefik/whoami` (que imprimem cabeçalhos, nós e IPs internos) **nunca** devem ser expostos na internet pública sem autenticação. Em produção:
* Proteger rotas sensíveis com middleware do Traefik (BasicAuth, ForwardAuth com OAuth2/Keycloak/Google).
* Utilizar NetworkPolicies para isolar namespaces de desenvolvimento e produção.
