# 03 — Gerenciamento de Segredos com Bitnami Sealed Secrets

## 1. Segurança em Primeiro Lugar & O Mito do Base64

No Kubernetes puro, manifestos do tipo `Secret` **não são criptografados**:
```yaml
apiVersion: v1
kind: Secret
data:
  POSTGRES_PASSWORD: c2VuaGExMjM= # NÃO É CRIPTOGRAFIA! É apenas Base64 ('senha123').
```
Qualquer pessoa que ler o repositório ou executar `echo "c2VuaGExMjM=" | base64 -d` recupera o valor em texto puro instantaneamente.

Como este repositório adota a metodologia **GitOps** (onde o ArgoCD sincroniza todo o estado do cluster diretamente a partir do repositório Git), comitar manifestos de `Secret` nativos causaria o vazamento irreversível de senhas de banco de dados, chaves de API e tokens corporativos.

Para solucionar isso, utilizamos o **Bitnami Sealed Secrets**, implementando criptografia assimétrica de chave pública/privada diretamente integrada ao fluxo GitOps.

---

## 2. Arquitetura Criptográfica

```text
SUA MÁQUINA (Local / Offline)                       CLUSTER KUBERNETES (k3s)
┌───────────────────────────────┐                   ┌──────────────────────────────────────┐
│ secrets-raw/                  │                   │ Namespace: kube-system               │
│ dev-postgres.env              │                   │ ┌──────────────────────────────────┐ │
│ (Texto puro - NUNCA vai p/ Git│                   │ │ Chave Privada Mestra             │ │
└──────────────┬────────────────┘                   │ │ (Nunca sai de dentro do cluster) │ │
               │                                    │ └─────────────────┬────────────────┘ │
               │ 1. Lê variáveis locais             └───────────────────┼──────────────────┘
               ▼                                                        │
┌───────────────────────────────┐                                       │
│ kubeseal + Chave Pública      │                                       │
│ (scripts/sealed-secrets-      │                                       │
│  public-cert.pem)             │                                       │
└──────────────┬────────────────┘                                       │
               │                                                        │
               │ 2. Criptografa (RSA-OAEP / AES-GCM)                    │
               ▼                                                        │
┌───────────────────────────────┐                   ┌───────────────────┼──────────────────┐
│ sealed-secret.yaml            │── 3. git push ──► │ Sealed Secrets Controller            │
│ (Pode ser commitado no Git!)  │   (via ArgoCD)    │ (Usa a Chave Privada p/ descriptografar)
└───────────────────────────────┘                   └───────────────────┬──────────────────┘
                                                                        │
                                                                        │ 4. Cria Secret nativa
                                                                        ▼
                                                    ┌──────────────────────────────────────┐
                                                    │ Secret (postgres-secrets / eos)      │
                                                    │ Namespace: eos-dev / eos-prod        │
                                                    └───────────────────┬──────────────────┘
                                                                        │ 5. Monta variáveis
                                                                        ▼
                                                    ┌──────────────────────────────────────┐
                                                    │ Pods EOS / Postgres                  │
                                                    └──────────────────────────────────────┘
```

### O papel do diretório `secrets-raw/`
* **Local e temporário**: É o diretório na sua máquina onde você edita as senhas em formato `.env` puro.
* **Bloqueado no Git**: O arquivo `.gitignore` bloqueia explicitamente qualquer arquivo `.env` dentro de `secrets-raw/`. Somente os modelos `.env.example` são versionados.
* **Segurança**: Nunca force a adição (`git add -f`) de arquivos `.env` de `secrets-raw/` no controle de versão.

### O papel do certificado `scripts/sealed-secrets-public-cert.pem`
* **Chave Pública**: É o certificado público X.509 gerado pelo controller do cluster.
* **Criptografia Offline**: Permite que qualquer desenvolvedor com `kubeseal` criptografe segredos na sua própria máquina (mesmo offline, sem VPN e sem acesso `kubectl` ao cluster).
* **Seguro no Git**: Esse certificado público serve **apenas para trancar** o cofre. Conhecer a chave pública não permite a ninguém decifrar os dados. Ele pode e deve ser commitado no Git (permitido no `.gitignore` via exceção `!scripts/sealed-secrets-public-cert.pem`).

### A Chave Privada do Cluster
* Fica armazenada como uma Secret no namespace `kube-system` dentro do cluster k3s.
* Ela é o único elemento capaz de destrancar os arquivos `SealedSecret`. Ninguém fora do cluster possui essa chave.

### Escopo de Criptografia (Namespace + Name Binding)
Por padrão, o `kubeseal` vincula matematicamente o segredo ao **Namespace** e ao **Nome da Secret** de destino:
* Se um segredo for criptografado para a secret `eos-secrets` no namespace `eos-dev`, ele **não** poderá ser descriptografado se for copiado para o namespace `eos-prod` ou se o nome for alterado.
* Isso impede ataques de vazamento lateral ou sequestro de segredos entre ambientes.

---

## 3. Como Criptografar Segredos por Aplicação

### Método A: Via Script Automatizado (Recomendado)

O repositório disponibiliza o script [`scripts/06-encrypt-secrets-vault.sh`](../scripts/06-encrypt-secrets-vault.sh):

```bash
# 1. Copie o gabarito e preencha as credenciais reais:
cp secrets-raw/dev-postgres.env.example secrets-raw/dev-postgres.env
# Edite secrets-raw/dev-postgres.env com as senhas reais

# 2. Execute o script de criptografia:
# Para o banco Postgres em dev:
./scripts/06-encrypt-secrets-vault.sh postgres dev

# Para o banco Postgres em prod:
./scripts/06-encrypt-secrets-vault.sh postgres prod

# Para a API EOS em dev:
./scripts/06-encrypt-secrets-vault.sh eos dev

# Para a API EOS em prod:
./scripts/06-encrypt-secrets-vault.sh eos prod
```

O script detecta o certificado público `scripts/sealed-secrets-public-cert.pem` e atualiza o manifesto `sealed-secret.yaml` no overlay correspondente:
* `apps/eos/overlays/dev/sealed-secret.yaml`
* `apps/eos/overlays/prod/sealed-secret.yaml`

Após a geração, comite apenas o arquivo `sealed-secret.yaml` gerado:
```bash
git add apps/eos/overlays/dev/sealed-secret.yaml
git commit -m "feat(security): atualiza sealed-secret da api eos para dev"
git push origin main
```

---

### Método B: Criptografia Offline na sua Máquina Local

Se você estiver em sua estação de trabalho (ex: macOS) sem acesso direto ao cluster:

1. Tenha o CLI `kubeseal` instalado localmente (`brew install kubeseal`).
2. Gere um manifesto temporário de Secret nativa em memória:
   ```bash
   kubectl create secret generic eos-secrets \
     --namespace eos-dev \
     --from-env-file=secrets-raw/dev-eos.env \
     --dry-run=client -o yaml > /tmp/secret-temp.yaml
   ```
3. Criptografe usando o certificado público existente no repositório:
   ```bash
   kubeseal --format yaml --cert scripts/sealed-secrets-public-cert.pem \
     < /tmp/secret-temp.yaml > apps/eos/overlays/dev/sealed-secret.yaml
   ```
4. Remova o arquivo temporário em texto puro:
   ```bash
   rm -f /tmp/secret-temp.yaml
   ```

---

## 4. Comportamento Multi-Node e Multi-Cluster

### Multi-Node (Vários servidores no mesmo cluster)
* **Comportamento**: 100% automático e transparente.
* As chaves privadas ficam no banco do cluster (`kube-system`).
* O controller descriptografa o segredo uma única vez criando a Secret nativa no namespace da aplicação.
* Qualquer nó (Worker Node) que executar os Pods receberá as variáveis de ambiente normalmente, sem necessidade de copiar chaves para as máquinas adicionais.

### Multi-Cluster (Ambientes Isolados: Dev vs Prod)
* **Recomendação de Arquitetura**: Cada cluster deve possuir seu **próprio par de chaves**.
* O cluster de **Dev** possui seu par de chaves e seu certificado público (`sealed-secrets-dev-cert.pem`).
* O cluster de **Produção** possui seu par de chaves e seu certificado público (`sealed-secrets-prod-cert.pem`).
* **Vantagem**: Se um operador com acesso a dev tiver acesso às chaves, as credenciais e bancos de produção permanecem totalmente inacessíveis e protegidos.

---

## 5. Plano de Recuperação de Desastres (Backup e Restauração)

> [!WARNING]
> Se o cluster k3s for destruído ou reinstalado do zero sem restauração da chave privada, uma **nova chave privada aleatória** será gerada. Como consequência, todos os arquivos `sealed-secret.yaml` comitados no Git **não poderão ser descriptografados**.

### Como fazer Backup da Chave Privada Mestra
Execute este comando no cluster ativo com permissão de administrador e salve o arquivo em um cofre seguro (ex: 1Password, Bitwarden ou cofre corporativo de senhas — **NUNCA NO GIT**):

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > /caminho/seguro/sealed-secrets-master-key-backup.yaml
```

### Como Restaurar a Chave Mestra em um Cluster Novo
Caso você precise subir uma nova VM ou reconstruir o cluster k3s:

1. Restaure a chave mestra no namespace `kube-system` antes de instalar as aplicações:
   ```bash
   kubectl apply -f /caminho/seguro/sealed-secrets-master-key-backup.yaml
   ```
2. Instale ou reinicie o deployment do Sealed Secrets Controller:
   ```bash
   ./scripts/03-setup-sealed-secrets.sh
   kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets
   ```
3. O controller reiniciará utilizando a chave mestra original, e todos os arquivos `sealed-secret.yaml` versionados no Git voltarão a ser decifrados perfeitamente.

---

## 6. Diagnóstico e Resolução de Problemas (Troubleshooting)

### Verificar se o segredo foi decifrado com sucesso
```bash
kubectl get sealedsecrets -n eos-dev
# O status deve apresentar: STATUS: Synced
```

### Inspecionar erros de descriptografia
Se o status apresentar `CrashLoopBackOff` ou `Error`:
```bash
kubectl describe sealedsecret eos-secrets -n eos-dev
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets --tail=50
```

### Erro comum: `cannot unseal secret`
Causas usuais:
1. **Chave pública divergente**: O segredo foi criptografado com um certificado público diferente do que a chave privada do cluster atual possui.
2. **Namespace ou Nome incompatível**: O manifesto foi movido para outro namespace sem ser re-criptografado para aquele namespace específico.
