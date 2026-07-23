# Gerenciamento de Segredos e Variáveis com Sealed Secrets e ConfigMaps

No GitOps, a regra fundamental de segurança é: **Nunca comite senhas, tokens ou dados sensíveis em texto puro no Git.**

Para resolver isso, dividimos as variáveis de ambiente em duas categorias:

---

## 1. Variáveis Públicas / Não-Sensíveis (ConfigMap)

Variáveis como URLs de banco de dados, nomes de portas ou diretórios de upload ficam declaradas diretamente em manifestos `ConfigMap` versionados no Git.

Exemplo (`eos/k8s/base/configmap.yaml`):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eos-config
  namespace: eos
data:
  POSTGRES_HOST: "postgres"
  POSTGRES_PORT: "5432"
  POSTGRES_DB: "eos"
  UPLOAD_DIR: "/public/images"
```

---

## 2. Segredos e Variáveis Sensíveis (Sealed Secrets)

O **Sealed Secrets (Bitnami)** funciona através de um par de chaves assimétricas (pública e privada):
1. O **Controller no cluster** guarda a chave privada.
2. A ferramenta CLI **`kubeseal`** usa a chave pública obtida do cluster para criptografar uma Secret K8s localmente.
3. O resultado é um arquivo `SealedSecret` (.yaml) criptografado. Este arquivo é **seguro para versionar no Git público ou privado**.
4. O ArgoCD aplica o `SealedSecret` no cluster, e o controller descriptografa o conteúdo em uma `Secret` nativa do Kubernetes.

---

## Passo a Passo para Criar um Segredo Criptografado

### Passo 1: Criar a Secret em texto puro em um arquivo temporário (fora do Git)
```bash
kubectl create secret generic eos-secrets \
  --namespace eos \
  --from-literal=POSTGRES_USER=admin \
  --from-literal=POSTGRES_PASSWORD=minhasenhasupersegura \
  --from-literal=JWT_SECRET=superchavejwt \
  --from-literal=MAILTRAP_USERNAME=usuario_mailtrap \
  --from-literal=MAILTRAP_API_KEY=key_mailtrap \
  --dry-run=client -o yaml > /tmp/secret-temp.yaml
```

### Passo 2: Criptografar a Secret usando o `kubeseal`
```bash
kubeseal --format yaml < /tmp/secret-temp.yaml > /home/alvaroico/projects/eos/k8s/base/sealed-secret.yaml
```

### Passo 3: Apagar o arquivo temporário em texto puro
```bash
rm /tmp/secret-temp.yaml
```

### Passo 4: Commit do arquivo `sealed-secret.yaml` no Git
```bash
cd /home/alvaroico/projects/eos
git add k8s/base/sealed-secret.yaml
git commit -m "feat: adiciona sealed-secret criptografado para a API EOS"
git push
```

O ArgoCD detectará o novo manifesto `SealedSecret` e o controller dentro do k3s gerará a `Secret` `eos-secrets` automaticamente no namespace `eos`!
