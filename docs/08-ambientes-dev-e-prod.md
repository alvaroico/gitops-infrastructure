# Guia de Arquitetura Multiambiente: Desenvolvimento (dev) e Produção (prod)

Este documento detalha a separação de ambientes de **Desenvolvimento** (`dev`) e **Produção** (`prod`) no ecossistema GitOps com ArgoCD e Traefik.

---

## 1. Mapeamento de Branches, Namespaces e Domínios

| Atributo | Ambiente de Desenvolvimento (`dev`) | Ambiente de Produção (`prod`) |
|---|---|---|
| **Branch do Git (App EOS)** | `dev` | `alvaroico` |
| **Tag da Imagem Docker** | `ghcr.io/alvaroico/eos:dev-latest` | `ghcr.io/alvaroico/eos:latest` |
| **Namespace Kubernetes** | `eos-dev` | `eos-prod` |
| **Domínio HTTP (Host)** | `http://eos-dev.alvaroico-teste.com.br` | `http://eos.alvaroico-teste.com.br` |
| **Kustomize Overlay** | `apps/eos/overlays/dev/` | `apps/eos/overlays/prod/` |
| **Manifesto ArgoCD** | `argocd-apps/eos-dev-application.yaml` | `argocd-apps/eos-prod-application.yaml` |

---

## 2. Como Funciona o Ciclo de Vida do Código

```
1. Alteração na branch 'dev':
   - Push na branch 'dev' -> CI compila a imagem e publica a tag 'dev-latest' no GHCR.
   - ArgoCD sincroniza a Application 'eos-dev' (Overlay 'dev').
   - Aplicação disponível em: http://eos-dev.alvaroico-teste.com.br

2. Alteração ou Merge para a branch 'alvaroico' (PROD):
   - Push na branch 'alvaroico' -> CI compila a imagem e publica a tag 'latest' no GHCR.
   - ArgoCD sincroniza a Application 'eos-prod' (Overlay 'prod').
   - Aplicação disponível em: http://eos.alvaroico-teste.com.br
```

---

## 3. Mapeamento de DNS/Hosts

Para testar ambos os ambientes, adicione as seguintes linhas ao seu arquivo `/etc/hosts`:

```text
192.168.64.9 eos-dev.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

---

## 4. Aplicação das Applications no ArgoCD

Para ativar os dois ambientes no cluster:

```bash
# Aplicar ambiente de Dev
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/eos-dev-application.yaml

# Aplicar ambiente de Prod
kubectl apply -f /home/alvaroico/projects/gitops-infrastructure/argocd-apps/eos-prod-application.yaml
```
