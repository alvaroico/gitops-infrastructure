# AGENTS.md — GitOps & Kubernetes Local Playground

## 1. Project Context & Purpose
Repositório local de aprendizado, experimentação e implementação de padrões GitOps e arquitetura de cargas de trabalho em Kubernetes (k3s) via Rancher Desktop.

---

## 2. Environment & Runtime Baselines

### Ambiente A: Cluster Local Embutido (Rancher Desktop)
- **Orquestrador**: Kubernetes `v1.36.3+k3s1` embutido via Rancher Desktop.
- **Contexto ativo**: `rancher-desktop` (node único: `lima-rancher-desktop`).
- **VM Host Specs**: 8 vCPUs, ~8 GiB RAM (Alpine Linux kernel 6.18 via Lima).
- **Container Runtime**: Docker CLI / engine `v29.5.3`.

### Ambiente B: Cluster Multi-Nó Real (Debian 13 + UTM)
- **Documentação de Instalação**: [`docs/lab-k3s-debian-utm.md`](docs/lab-k3s-debian-utm.md)
- **Topologia**: 2 VMs no UTM (`k8s-master` e `k8s-worker-1`).
- **Especificação por VM**: 2 vCPUs, 2048 MB RAM, 20 GB Disco (Debian 13 "Trixie" Netinst sem interface gráfica).
- **Kubeconfig**: Gerenciado remotamente via terminal do Mac em `~/.kube/config-utm-k3s`.

---

## 3. Kubernetes & Workload Invariants (eng-infra)

1. **Recursos de Computação (Requests & Limits)**:
   - Todo Pod/Deployment deve declarar `resources.requests` e `resources.limits`.
   - Limite de memória obrigatório (`limits.memory`) para evitar OOM (Out Of Memory) generalizado no Node.
   - CPU `requests` para scheduling garantido; evitar CPU `limits` restritivos a menos que haja necessidade de isolamento rígido contra starvation, para evitar throttling do CFS.

2. **Comunicação e Descoberta de Serviços**:
   - Workloads não conversam via IP efêmero de Pod.
   - Toda comunicação interna ocorre via abstração de `Service` (tipo padrão `ClusterIP`) resolvido pelo CoreDNS interno do cluster (`<service-name>.<namespace>.svc.cluster.local`).

3. **Sondas de Ciclo de Vida (Probes Trio)**:
   - `startupProbe`: Para inicialização lenta se necessário.
   - `readinessProbe`: Controla se o Pod recebe tráfego do `Service`.
   - `livenessProbe`: Reinicia o container se travar; nunca deve apontar para dependências externas (como banco de dados).

4. **Segurança de Containers**:
   - Imagens preferencialmente mínimas/distroless ou debian-slim/alpine.
   - Execução obrigatória com usuário não-root numérico (`runAsNonRoot: true`, `runAsUser: 10001`).
   - Remoção de capabilities desnecessárias (`drop: ["ALL"]`).

---

## 4. Estrutura Padrão de Diretórios

```text
.
├── AGENTS.md                         # Constituição e padrões operacionais do repositório
├── Dockerfile                        # Multi-stage build da aplicação Node.js para o pipeline
├── .github/
│   └── workflows/
│       └── deploy.yml                # Pipeline CI/CD automático via GitHub Actions e Tailscale
├── src/                              # Código-fonte da aplicação de teste (Node.js / Express)
│   ├── package.json
│   └── server.js
├── docs/                             # Guias técnicos e roteiros de laboratório
│   ├── lab-k3s-debian-utm.md         # Guia passo a passo do cluster multi-nó no UTM
│   ├── security-and-hardening-vps.md # Matriz de portas, UFW e segurança para VPS pública
│   └── setup-ci-cd-tailscale.md      # Guia de configuração de CI/CD automático com Tailscale
└── apps/                             # Manifestos declarativos das aplicações
    ├── node-api/                     # Aplicação Node.js com deploy contínuo automático
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── ingress.yaml
    ├── backend/                      # traefik/whoami com probes, limits e Service ClusterIP
    │   ├── deployment.yaml
    │   └── service.yaml
    └── frontend/                     # nginxdemos/hello com Ingress Traefik exposto na porta 80
        ├── deployment.yaml
        ├── service.yaml
        └── ingress.yaml
```
