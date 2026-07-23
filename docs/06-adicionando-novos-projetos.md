# Como Adicionar Novos Projetos e Aplicações no Cluster (Exemplo: Web)

Este guia explica a função do diretório `k8s/` nas aplicações e fornece o passo a passo exato para adicionar novos projetos (como uma aplicação frontend `web.alvaroico-teste.com.br`) ao ecossistema GitOps com ArgoCD e Traefik.

---

## 1. Por que todo projeto precisa das configurações `k8s/`?

No Kubernetes, o cluster não sabe sozinho como rodar sua aplicação. Ele precisa de **manifestos declarativos em YAML** que informam:
- **Deployment**: Quantas cópias (réplicas) rodar, qual imagem Docker baixar (ex: `ghcr.io/alvaroico/web:latest`), limites de memória/CPU e variáveis de ambiente.
- **Service**: Como os pods da aplicação se comunicam dentro da rede interna do cluster.
- **IngressRoute (Traefik)**: Qual domínio externo (`web.alvaroico-teste.com.br`) deve ser direcionado para o Service interno da aplicação.
- **ConfigMap / SealedSecret**: Onde buscar configurações e senhas.

No **GitOps com ArgoCD**, o ArgoCD lê exatamente esses arquivos YAML do Git e os sincroniza com o cluster. **Se não houver manifestos no Git, o ArgoCD não sabe o que implantar.**

---

## 2. Passo a Passo Completo para Adicionar um Novo Projeto (`web`)

Imagine que você quer criar um novo projeto de Frontend Web e acessá-lo por `http://web.alvaroico-teste.com.br`. Veja o procedimento passo a passo:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PASSO 1: Repositório da App (web)                                                      │
│  - Código fonte (React / Vue / HTML)                                                   │
│  - Dockerfile                                                                          │
│  - Workflow de CI (.github/workflows/ci.yaml) -> gera imagem ghcr.io/alvaroico/web:latest│
│  - Pasta k8s/ (Deployment, Service, IngressRoute)                                      │
└───────────────────────────┬────────────────────────────────────────────────────────────┘
                            │ Push no GitHub
                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PASSO 2: ArgoCD Application                                                            │
│  - Criar manifesto web-application.yaml em gitops-infrastructure/argocd-apps/          │
│  - Aplicar: kubectl apply -f argocd-apps/web-application.yaml                         │
└───────────────────────────┬────────────────────────────────────────────────────────────┘
                            │ Sync Automático
                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PASSO 3: Traefik & DNS /etc/hosts                                                      │
│  - Adicionar 192.168.64.9 web.alvaroico-teste.com.br no /etc/hosts                     │
│  - Traefik recebe requisição no domínio 'web' -> envia para o Service web:80           │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Passo 1: No Repositório do Novo Projeto (`/home/alvaroico/projects/web`)

Criar a estrutura do novo projeto `web`:

```
web/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── ci.yaml             # CI para gerar ghcr.io/alvaroico/web:latest
└── k8s/
    ├── base/
    │   ├── deployment.yaml     # Deployment da Web
    │   └── service.yaml        # Service porta 80
    └── overlays/
        └── dev/
            ├── kustomization.yaml
            └── ingressroute-web.yaml # Host: web.alvaroico-teste.com.br
```

#### Exemplo do `k8s/base/deployment.yaml` da Web:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: web
          image: ghcr.io/alvaroico/web:latest
          ports:
            - containerPort: 80
```

#### Exemplo do `k8s/overlays/dev/ingressroute-web.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: web-ingress
  namespace: web
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`web.alvaroico-teste.com.br`)
      kind: Rule
      services:
        - name: web-app
          port: 80
```

---

### Passo 2: Cadastrar a nova Application no ArgoCD

No repositório de infraestrutura (`gitops-infrastructure/argocd-apps/`), crie o arquivo `web-application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/alvaroico/web.git"
    targetRevision: main
    path: k8s/overlays/dev
  destination:
    server: "https://kubernetes.default.svc"
    namespace: web
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Aplique no cluster:
```bash
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/web-application.yaml
```

---

### Passo 3: Atualizar o Mapeamento DNS no `/etc/hosts`

1. **Na VM Linux**:
   Editar `/etc/hosts` e adicionar:
   ```text
   127.0.0.1 web.alvaroico-teste.com.br
   ```

2. **Na Máquina Host Externa**:
   Editar `/etc/hosts` e adicionar:
   ```text
   192.168.64.9 web.alvaroico-teste.com.br
   ```

---

## 3. Opcional: Centralizado vs Descentralizado

Existem dois padrões para organizar os arquivos `k8s/`:

1. **Descentralizado (Junto com a App)** *(Padrão adotado no EOS)*:
   - A pasta `k8s/` fica dentro do próprio repositório da aplicação (`eos/k8s/` ou `web/k8s/`).
   - **Vantagem**: O desenvolvedor da aplicação ajusta a infraestrutura da app no mesmo commit em que altera o código.

2. **Centralizado (No Repositório de Infraestrutura)**:
   - Os arquivos de `k8s/` de TODAS as apps ficam centralizados na pasta `gitops-infrastructure/apps/web/` e `gitops-infrastructure/apps/eos/`.
   - **Vantagem**: Separação total de responsabilidades entre código-fonte da aplicação e configurações do Kubernetes.
