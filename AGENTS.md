# Diretrizes para Agentes de IA — GitOps Infrastructure Hub

> Guia de operação, arquitetura e infraestrutura declarativa para agentes trabalhando no `gitops-infrastructure`.

---

## 1. Stack e Ferramentas

- **Orquestrador**: Kubernetes (k3s) em nós Linux ARM64 / AMD64.
- **GitOps Engine**: ArgoCD v2.x monitorando a branch `main`.
- **Progressive Delivery & Promoção**: Kargo para promoção automatizada entre estágios (`dev` -> `prod`).
- **Ingress Controller**: Traefik IngressRoute com suporte a TLS/HTTPS e Let's Encrypt.
- **Gerenciamento de Segredos (Cofre)**: Bitnami Sealed Secrets (`kubeseal`).
- **Gerenciamento de Manifestos**: Kustomize (`kubectl kustomize`).

---

## 2. Estrutura de Diretórios

```text
gitops-infrastructure/
├── apps/
│   ├── eos/                    # API Backend EOS
│   │   ├── base/               # Deployment, Service (3000), ConfigMap base
│   │   └── overlays/
│   │       ├── dev/            # Namespace: eos-dev | Ingress: eos-dev.alvaroico-teste.com.br
│   │       └── prod/           # Namespace: eos-prod | Ingress: eos.alvaroico-teste.com.br
│   └── postgres/               # Banco de Dados PostgreSQL
│       ├── base/               # StatefulSet, Service (5432), ConfigMap base
│       └── overlays/
│           ├── dev/            # Namespace: eos-dev
│           └── prod/           # Namespace: eos-prod
├── argocd-apps/                # Applications declarativas e AppProjects do ArgoCD
│   ├── 00-projects.yaml        # Segmentação de AppProject (dev e prod)
│   ├── eos-dev-application.yaml
│   └── eos-prod-application.yaml
├── kargo/                      # Pipelines de promoção multi-estágio declarativos
├── secrets-raw/                # Gabaritos de variáveis (.env.example - ignorados no Git)
├── scripts/                    # Automações de setup, deploy, kargo, backup e manutenção (01 a 11)
└── docs/                       # Documentações técnicas de arquitetura, replicação e DNS
```

---

## 3. Invariantes de Operação e Segurança

1. **Zero Trust com Segredos**:
   - **NUNCA** comite arquivos `.env` ou senhas em texto puro.
   - Qualquer variável sensível (`POSTGRES_PASSWORD`, `JWT_SECRET`, tokens) DEVE ser encriptada usando `./scripts/06-encrypt-secrets-vault.sh` para gerar a `SealedSecret`.
   - O certificado público [`scripts/sealed-secrets-public-cert.pem`](./scripts/sealed-secrets-public-cert.pem) permite criptografia offline na máquina local (desbloqueado no `.gitignore`).
2. **ConfigMap vs Secrets**:
   - Variáveis não sensíveis (`POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `UPLOAD_DIR`) ficam em `ConfigMap` gerenciadas pelo `configMapGenerator` nos overlays.
   - Variáveis sensíveis e strings de conexão ficam em `SealedSecret` consumidas via `envFrom.secretRef`.
3. **Organização de Aplicações no ArgoCD (Projetos & Labels)**:
   - As aplicações são segmentadas nos `AppProject` declarativos em [`argocd-apps/00-projects.yaml`](./argocd-apps/00-projects.yaml): `dev` e `prod`.
   - Cada `Application` contém labels declarativas (`env: dev|prod`, `tier: backend|database`, `app.kubernetes.io/part-of: eos`).
4. **Promoção de Código (Kargo vs ArgoCD)**:
   - Alterações de imagem e versões de release seguem promoção controlada via Kargo (`./scripts/08-promote-kargo-stage.sh`).
5. **Estratégia de Backup**:
   - Rotina automatizada de dump do PostgreSQL com compressão e retenção via `./scripts/10-backup-postgres-database.sh`.
6. **Otimização e Limpeza do Cluster**:
   - Manutenção de pods concluídos/falhos, limpeza de imagens órfãs (`crictl rmi --prune`) e economia de RAM no ArgoCD via `./scripts/11-cluster-maintenance.sh`.

---

## 4. Checklist de Validação Obrigatória

Antes de commitar qualquer alteração de infraestrutura:

```bash
# Validar overlays de desenvolvimento
kubectl kustomize apps/eos/overlays/dev
kubectl kustomize apps/postgres/overlays/dev

# Validar overlays de produção
kubectl kustomize apps/eos/overlays/prod
kubectl kustomize apps/postgres/overlays/prod
```
