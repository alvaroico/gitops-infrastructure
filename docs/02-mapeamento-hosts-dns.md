# Mapeamento de Hosts e DNS para Ambiente Local

Para acessar a interface do ArgoCD e a API EOS usando os domínios customizados `argocd.alvaroico-teste.com.br` e `eos.alvaroico-teste.com.br`, é necessário mapear o arquivo `hosts` tanto na Máquina Virtual quanto na Máquina Host externa.

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
192.168.64.9 eos.alvaroico-teste.com.br
```

### No Windows Host:
Abrir o Bloco de Notas como Administrador e editar:
`C:\Windows\System32\drivers\etc\hosts`

Adicionar:
```text
192.168.64.9 argocd.alvaroico-teste.com.br
192.168.64.9 eos.alvaroico-teste.com.br
```

---

## 3. Teste de Validação de Conectividade

Após salvar o arquivo `hosts`, teste no terminal:

```bash
curl -I http://argocd.alvaroico-teste.com.br
curl -I http://eos.alvaroico-teste.com.br
```

A resposta esperada é um código HTTP (200 OK ou 303 Redirect para o ArgoCD).
