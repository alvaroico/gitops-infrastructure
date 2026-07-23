# Padrão de Repositório Centralizado de Manifestos K8s

## Resposta Direta: A pasta `k8s/` PRECISA ficar dentro do projeto da aplicação?

**NÃO!** Você **não precisa** colocar a pasta `k8s/` dentro de cada aplicação (como `eos` ou `web`).

É perfeitamente possível e muito comum na indústria utilizar o **Padrão de Repositório Centralizado de Infraestrutura** (também chamado de *Centralized GitOps Manifests Repository*).

---

## Comparação dos Dois Modelos

### Modelo A: Manifestos Descentralizados (No Repositório de Cada Aplicação)
- **Como funciona**: O repositório `alvaroico/eos` tem a pasta `eos/k8s/`. O repositório `alvaroico/web` tem a pasta `web/k8s/`.
- **Quem mexe**: O desenvolvedor ajusta o código e a infraestrutura no mesmo repositório.

### Modelo B: Manifestos Centralizados (Em um Único Repositório de Infraestrutura) **[SEU FORMATO DESEJADO]**
- **Como funciona**:
  1. O repositório `alvaroico/eos` tem **APENAS** o código da API, Dockerfile e GitHub Actions (`ci.yaml`). O CI apenas builda e publica a imagem Docker no registry (`ghcr.io/alvaroico/eos:latest`).
  2. O repositório `alvaroico/web` tem **APENAS** o código da WEB, Dockerfile e GitHub Actions. O CI apenas publica a imagem Docker (`ghcr.io/alvaroico/web:latest`).
  3. O repositório **`gitops-infrastructure`** contém a pasta `apps/` com todos os manifestos Kubernetes de todas as aplicações:
     ```
     gitops-infrastructure/
     └── apps/
         ├── eos/
         │   ├── base/ (deployment.yaml, service.yaml, configmap.yaml)
         │   └── overlays/dev/ (ingressroute-eos.yaml)
         ├── web/
         │   ├── base/ (deployment.yaml, service.yaml)
         │   └── overlays/dev/ (ingressroute-web.yaml)
         └── ecommerce/
             └── ...
     ```
- **Vantagem Principal**: O repositório da aplicação fica 100% limpo de YAMLs do Kubernetes! Todos os manifestos k8s de todos os seus projetos ficam concentrados e organizados em um único lugar (`gitops-infrastructure/apps/`).

---

## Fluxo Completo com Repositório Centralizado

```
┌────────────────────────────────┐         ┌────────────────────────────────┐
│ REPO DA APP (alvaroico/eos)    │         │ REPO DA APP (alvaroico/web)    │
│ - Código fonte                 │         │ - Código fonte                 │
│ - Dockerfile                   │         │ - Dockerfile                   │
│ - CI (.github/workflows)       │         │ - CI (.github/workflows)       │
└──────────────┬─────────────────┘         └──────────────┬─────────────────┘
               │ Build & Push                             │ Build & Push
               ▼                                          ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ Container Registry (ghcr.io/alvaroico/eos:latest e web:latest)           │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │ Imagens prontas
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ REPOSITÓRIO CENTRALIZADO (gitops-infrastructure)                          │
│                                                                           │
│  apps/                                                                    │
│  ├── eos/  ──▶ Aponta para ghcr.io/alvaroico/eos:latest                  │
│  └── web/  ──▶ Aponta para ghcr.io/alvaroico/web:latest                  │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │ Sync ArgoCD
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ Cluster Kubernetes (k3s)                                                  │
│ - Namespace eos (api + postgres + ingress eos.alvaroico-teste.com.br)     │
│ - Namespace web (frontend + ingress web.alvaroico-teste.com.br)           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Como Fica o Manifesto da Application no ArgoCD

Quando os manifestos estão no repositório centralizado, a `Application` no ArgoCD aponta diretamente para o repositório de infraestrutura:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: eos
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/alvaroico/gitops-infrastructure.git" # Repositório centralizado
    targetRevision: main
    path: apps/eos/overlays/dev                              # Caminho dentro do repo de infra
  destination:
    server: "https://kubernetes.default.svc"
    namespace: eos
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
