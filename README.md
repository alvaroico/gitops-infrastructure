# Repositório Local de Infraestrutura GitOps & Automação CD

Repositório local de procedimentos, scripts automatizados e documentações de arquitetura para provisionamento do ambiente **GitOps com k3s, Traefik, ArgoCD, Sealed Secrets, Firewall UFW e CI/CD dos Projetos**.

## Estrutura do Repositório

```
gitops-infrastructure/
├── README.md                           # Este documento principal
├── scripts/                            # Scripts executáveis de provisionamento e backup
│   ├── 01-bootstrap-vm.sh              # Instala k3s, kubectl, kubeseal e ferramentas base
│   ├── 02-setup-argocd.sh              # Instala ArgoCD + IngressRoute no Traefik
│   ├── 03-setup-sealed-secrets.sh      # Instala Bitnami Sealed Secrets Controller
│   ├── 04-configure-firewall.sh        # Aplica políticas de firewall UFW (Zero Trust)
│   ├── 05-add-private-repo-to-argocd.sh# Cadastra repositórios privados do GitHub no ArgoCD
│   └── 06-backup-database.sh          # Automação de backup do PostgreSQL e PVCs do k3s
├── docs/                               # Documentação detalhada de arquitetura e operação
│   ├── 01-visao-geral-arquitetura.md   # Arquitetura GitOps e fluxo de dados
│   ├── 02-mapeamento-hosts-dns.md       # Configuração dos domínios em /etc/hosts
│   ├── 03-gerenciamento-segredos.md    # Uso do Sealed Secrets e ConfigMaps
│   ├── 04-reorganizacao-ci-github.md    # Pipelines do GitHub Actions
│   ├── 05-guia-replicacao-do-zero.md   # Roteiro completo para subir uma VM limpa
│   ├── 06-adicionando-novos-projetos.md # Como adicionar novos apps (ex: WEB) no cluster
│   ├── 07-padrao-repositorio-centralizado-k8s.md # Padrão sem K8s no repo da aplicação
│   ├── 08-ambientes-dev-e-prod.md      # Separação multiambiente (Dev vs Prod)
│   └── 09-estrategia-de-backup.md      # Guia de backup/restauração do Postgres e PVCs
├── apps/                               # CENTRAL DE MANIFESTOS K8S DE TODAS AS APPS
│   └── eos/
│       ├── base/                       # Manifestos base (Deployment, Service, ConfigMap)
│       └── overlays/
│           ├── dev/                    # Overlay DEV (eos-dev.alvaroico-teste.com.br)
│           └── prod/                   # Overlay PROD (eos.alvaroico-teste.com.br)
└── argocd-apps/                        # Manifestos de Applications do ArgoCD
    ├── eos-dev-application.yaml        # ArgoCD App de Desenvolvimento (branch 'dev')
    └── eos-prod-application.yaml       # ArgoCD App de Produção (branch 'alvaroico')
```

## Como Usar para Replicar uma VM do Zero

1. Navegue até a pasta de scripts:
   ```bash
   cd scripts
   ```
2. Execute os scripts em ordem sequencial:
   ```bash
   ./01-bootstrap-vm.sh
   ./02-setup-argocd.sh
   ./03-setup-sealed-secrets.sh
   ./04-configure-firewall.sh
   ./05-add-private-repo-to-argocd.sh
   ```
3. Consulte os guias em [`docs/`](docs/) para o passo a passo completo.
