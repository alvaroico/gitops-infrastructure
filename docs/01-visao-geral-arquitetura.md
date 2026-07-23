# Visão Geral da Arquitetura GitOps Multiambiente

## Conceito Fundamental

Este ambiente utiliza a filosofia **GitOps**, onde o **repositório Git é a única fonte da verdade** para o estado desejado da infraestrutura e das aplicações no cluster Kubernetes (k3s).

```
┌─────────────────┐       git push       ┌────────────────────────┐
│ Desenvolvedor   │ ───────────────────▶ │ GitHub                 │
│ (Código / K8s)  │                      │ (alvaroico/eos)        │
└─────────────────┘                      └───────────┬────────────┘
                                                     │
                                                     │ Polling / Sync Auto
                                                     ▼
┌──────────────────────── VM Local (IP 192.168.64.9) ─────────────────────────┐
│                                                                            │
│  ┌─────────────────┐    Sincroniza Manifests    ┌───────────────────────┐  │
│  │ ArgoCD          │◀───────────────────────────│ ArgoCD Applications   │  │
│  │ Controller      │                            │ - eos-dev-application │  │
│  └────────┬────────┘                            │ - eos-prod-application│  │
│           │                                     └───────────────────────┘  │
│           │ Aplica recursos no cluster                                     │
│           ▼                                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Cluster k3s                                                          │  │
│  │                                                                      │  │
│  │  ┌───────────────────────┐         ┌──────────────────────────────┐  │  │
│  │  │ Traefik Ingress       │────────▶│ argocd.alvaroico-teste.com.br│  │  │
│  │  │ (Roteador de Domínio) │         │ eos-dev.alvaroico-teste.com.br│  │  │
│  │  │                       │         │ eos.alvaroico-teste.com.br   │  │  │
│  │  └───────────────────────┘         └──────────────────────────────┘  │  │
│  │                                                                      │  │
│  │  ┌───────────────────────┐         ┌──────────────────────────────┐  │  │
│  │  │ SealedSecrets         │────────▶│ Descriptografa segredos em   │  │  │
│  │  │ Controller            │         │ K8s Secrets em eos-dev e     │  │  │
│  │  │                       │         │ eos-prod                     │  │  │
│  │  └───────────────────────┘         └──────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

## Frequência de Sincronização do ArgoCD

- **Intervalo Padrão de Polling**: O ArgoCD verifica por padrão a cada **3 minutos (180 segundos)** se existem novos commits no repositório Git.
- **Sincronização Instantânea Manual**: Pode ser acionada na Web UI (`http://argocd.alvaroico-teste.com.br`) clicando no botão **Refresh / Sync**, ou via comando:
  ```bash
  kubectl patch application eos-dev -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
  ```
- **Webhooks do GitHub (Instantâneo em Tempo Real)**: Em ambientes de produção, o GitHub envia um Webhook HTTP para o ArgoCD em `http://<IP-DA-VM>/api/webhook`, fazendo a atualização ocorrer em menos de 1 segundo após o `git push`.

1. **k3s**: Distribuição Kubernetes leve perfeita para ambiente local/VM, consumindo pouca memória e CPU. Já inclui o Traefik como Ingress Controller nativo.
2. **Traefik Ingress**: Roteador HTTP/HTTPS que direciona as requisições que chegam na porta 80/443 da VM para os serviços internos com base no cabeçalho `Host` da requisição HTTP (`argocd.alvaroico-teste.com.br`, `eos-dev.alvaroico-teste.com.br` e `eos.alvaroico-teste.com.br`).
3. **ArgoCD**: Ferramenta de CD/GitOps responsável por monitorar os repositórios Git configurados e garantir que o estado real do cluster corresponda ao estado declarado nos manifestos Kubernetes.
4. **Sealed Secrets**: Solução da Bitnami para permitir a inclusão de segredos criptografados (seguros) diretamente no Git.
5. **UFW (Uncomplicated Firewall)**: Firewall no Linux configurado em modo *Zero Trust*, permitindo apenas conexões essenciais (SSH, HTTP, HTTPS e tráfego interno k3s).
