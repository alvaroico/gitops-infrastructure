# Guia Passo a Passo: CI/CD com GitHub Actions + Tailscale + K3s

Este guia documenta o provisionamento da esteira de deploy automático contínuo (CD) conectando o GitHub Actions (na nuvem) ao seu cluster K3s local (no UTM) de forma segura através da rede privada mesh do **Tailscale**, sem necessidade de abrir portas no roteador nem expor seu IP doméstico.

---

## 1. Visão Geral da Arquitetura

```text
[Desenvolvedor]
      │
      │ 1. git push origin main
      ▼
[GitHub Actions (Ubuntu Cloud Runner)]
      │
      ├─► 2. Build Docker e Push no GHCR (ghcr.io)
      │
      ├─► 3. Conecta à VPN Tailscale (usando chave efêmera)
      │
      └─► 4. Executa `kubectl set image` através da VPN
                  │
                  ▼ (Túnel Criptografado Wireguard)
[k8s-master no UTM (IP Tailscale 100.x.y.z)]
      │
      └─► 5. Dispara Rolling Update no cluster
            ├─ Sobe novos pods da versão atualizada
            └─ Remove pods antigos sem indisponibilidade (Zero Downtime)
```

---

## 2. Passo 1: Instalar o Tailscale na VM `k8s-master`

1. Conecte via SSH na VM `k8s-master`:
   ```bash
   ssh k8s-master@192.168.15.24
   ```

2. Instale o Tailscale com o comando oficial:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

3. Inicie o Tailscale:
   ```bash
   sudo tailscale up
   ```
   * O terminal exibirá uma URL de autenticação (ex: `https://login.tailscale.com/a/...`).
   * Abra esse link no navegador do seu Mac e clique em **Connect/Log in**.

4. Descubra o IP Tailscale da VM executando:
   ```bash
   tailscale ip -4
   ```
   *(Anote este IP, ele começará com `100.x.y.z`, exemplo: `100.85.120.45`)*.

---

## 3. Passo 2: Gerar a Auth Key no Painel do Tailscale

1. Acesse o painel de administração do Tailscale no navegador:
   **[https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)**
2. Clique no botão **Generate auth key...**.
3. Marque as seguintes opções:
   * **Reusable**: (Permite que o GitHub Actions use a mesma chave em múltiplos builds).
   * **Ephemeral**: (O runner do GitHub se desconecta e é removido da lista assim que o deploy termina).
4. Clique em **Generate token** e copie a chave gerada (começa com `tskey-auth-...`).

---

## 4. Passo 3: Preparar o Kubeconfig para o GitHub Actions

O arquivo `~/.kube/config-utm-k3s` no seu Mac está apontando para o IP local `192.168.15.24`. O GitHub Actions precisa apontar para o **IP Tailscale** (`100.x.y.z` anotado no Passo 1).

No terminal do seu Mac, gere a versão Base64 do Kubeconfig com o IP do Tailscale:

```bash
# Substitua 100.85.120.45 pelo IP Tailscale real da sua VM master
sed 's/192.168.15.24/100.85.120.45/g' ~/.kube/config-utm-k3s | base64 | pbcopy
```
*(O conteúdo já estará copiado para a área de transferência do seu Mac)*.

---

## 5. Passo 4: Configurar os Secrets no Repositório do GitHub

No repositório do seu projeto no GitHub:
1. Vá em **Settings** › **Secrets and variables** › **Actions**.
2. Clique em **New repository secret** e adicione os 2 segredos:

| Nome do Secret | Valor |
| :--- | :--- |
| **`TAILSCALE_AUTHKEY`** | A chave `tskey-auth-...` gerada no Passo 2. |
| **`KUBE_CONFIG_DATA`** | O texto em Base64 copiado no Passo 3. |

---

## 6. Passo 5: Criar o Segredo de Autenticação para Imagens Privadas (`ghcr-secret`)

Para que o Kubernetes consiga puxar as imagens do GitHub Packages (`ghcr.io`), execute no terminal do seu Mac:

```bash
KUBECONFIG=~/.kube/config-utm-k3s kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=SEU_USUARIO_GITHUB \
  --docker-password=SEU_GITHUB_PERSONAL_ACCESS_TOKEN_COM_READ_PACKAGES \
  --namespace=default
```

---

## 7. Passo 6: Testar o Deploy Automático Contínuo

1. Faça uma alteração no código em [`src/server.js`](../src/server.js).
2. Envie para o GitHub:
   ```bash
   git add .
   git commit -m "feat: testando deploy automatico continuo"
   git push origin main
   ```
3. Abra a aba **Actions** no seu GitHub:
   * Você verá o pipeline executando o build da imagem, conectando na sua VPN e rodando o `kubectl set image`.
4. Abra o navegador no Mac e acesse:
   ```text
   http://192.168.15.24/node
   ```
   A nova versão aparecerá atualizada na tela com zero tempo de parada.
