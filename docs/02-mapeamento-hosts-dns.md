# Mapeamento de Hosts e DNS para Ambiente Local

Para acessar a interface do ArgoCD e as APIs do projeto EOS em ambos os ambientes (**Dev** e **Prod**), é necessário mapear os domínios no arquivo `hosts` tanto na Máquina Virtual quanto na Máquina Host externa.

---

## Domínios do Sistema

| Domínio | Ambiente | Destino no K8s |
|---|---|---|
| `argocd.alvaroico-teste.com.br` | ArgoCD Management UI | Service `argocd-server:80` (namespace `argocd`) |
| `eos-dev.alvaroico-teste.com.br` | API EOS (Desenvolvimento) | Service `eos-api:3000` (namespace `eos-dev`) |
| `eos.alvaroico-teste.com.br` | API EOS (Produção) | Service `eos-api:3000` (namespace `eos-prod`) |

---

## 1. Mapeamento Interno na Máquina Virtual (Linux)

No arquivo `/etc/hosts` da própria VM onde o k3s/Traefik está rodando:

### Editar `/etc/hosts`
```bash
sudo nano /etc/hosts
```

### Adicionar as seguintes linhas:
```text
127.0.0.1 argocd.alvaroico-teste.com.br
127.0.0.1 eos-dev.alvaroico-teste.com.br
127.0.0.1 eos.alvaroico-teste.com.br
```

---

## 2. Mapeamento Externo na Máquina Host (Mac ou Windows)

Na sua máquina física (Host), onde você abre o navegador web para acessar os serviços rodando dentro da VM (cujo IP é `192.168.64.9`):

### No macOS / Linux Host:
```bash
sudo nano /etc/hosts
```

Adicionar:
```text
192.168.64.9 argocd.alvaroico-teste.com.br
192.168.64.9 eos-dev.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

### No Windows Host:
Abrir o Bloco de Notas como Administrador e editar:
`C:\Windows\System32\drivers\etc\hosts`

Adicionar:
```text
192.168.64.9 argocd.alvaroico-teste.com.br
192.168.64.9 eos-dev.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

---

## 3. Teste de Validação de Conectividade

Após salvar o arquivo `hosts`, teste no terminal:

```bash
curl -I http://argocd.alvaroico-teste.com.br
curl -I http://eos-dev.alvaroico-teste.com.br
curl -I http://eos.alvaroico-teste.com.br
```

A resposta esperada em todos é o código **HTTP 200 OK**!
