# 10 — Padrão de Dual-Routing (sslip.io + Domínios Oficiais) e Resolução Dinâmica de Frontend

> **Problema Comum:** Ao provisionar uma nova infraestrutura em nuvem, a compra de domínios, configuração de cPanel, delegação de Nameservers ou aprovação de chamados de TI podem levar de várias horas a dias. No entanto, o time de desenvolvimento precisa testar e validar imediatamente com **HTTPS e certificados válidos**.

---

## 1. O Padrão de Dual-Routing no Traefik (k3s)

Em vez de configurar o `IngressRoute` apenas com o domínio oficial, configuramos uma regra composta utilizando o operador lógico `||` (OR):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backend-ingress
  namespace: prod
spec:
  entryPoints:
    - web
    - websecure
  routes:
    # 🟢 Rota temporária instantânea via IP + ⏳ Rota definitiva oficial
    - match: Host(`api.35.232.196.218.sslip.io`) || Host(`api.empresa.com.br`)
      kind: Rule
      services:
        - name: backend-service
          port: 3333
  tls:
    certResolver: letsencrypt
```

### Por que usar o `sslip.io`?

- **Zero Cadastro**: Qualquer IP no formato `<qualquer-subdominio>.<IP-PUBLICO>.sslip.io` resolve mundialmente para o IP fornecido em milissegundos.
- **Let's Encrypt Compatível**: O `sslip.io` faz parte da **Public Suffix List (PSL)** oficial. Isso impede bloqueios por limites de taxa (_Rate Limiting_) na emissão de certificados.

---

## 2. Resolução Dinâmica de Host no Frontend SPA (Vite / React / Vue)

No ecossistema React/Vite, as variáveis de ambiente `VITE_API_URL` são compiladas de forma **estática** durante o build da imagem Docker (`npm run build`). Se a imagem foi gerada com a URL oficial (`https://api.empresa.com.br`), o frontend falhará ao ser acessado pelo IP temporário.

### Solução de Engenharia: Detecção Dinâmica de Host em Runtime

No arquivo central de configuração da API (ex: `src/store/appStore.ts` ou `src/services/api.ts`):

```typescript
function getApiBaseUrl(): string {
  if (typeof window !== "undefined" && window.location) {
    const host = window.location.hostname;
    const proto = window.location.protocol;

    // Se estiver acessando via wildcard DNS temporário (sslip.io / nip.io)
    if (host.includes(".sslip.io") || host.includes(".nip.io")) {
      if (host.startsWith("hom-sistema.") || host.startsWith("dev-sistema.")) {
        return `${proto}//${host.replace(/^(hom|dev)-sistema\./, "$1-api.")}/api/v1`;
      }
      if (host.startsWith("sistema.")) {
        return `${proto}//${host.replace(/^sistema\./, "api.")}/api/v1`;
      }
      return `${proto}//${host}/api/v1`;
    }
  }

  // Fallback padrão para variáveis de build ou localhost
  const raw = (
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3333"
  ).replace(/\/+$/, "");
  return raw.endsWith("/api/v1") ? raw : `${raw}/api/v1`;
}
```

---

## 3. Transição Transparente Sem Parada (Cutover)

Quando o chamado de DNS no Registro.br/cPanel for finalizado apontando para o IP do cluster:

1. O usuário acessa `https://sistema.empresa.com.br`.
2. O Traefik intercepta o tráfego e emite o certificado Let's Encrypt para o domínio oficial automaticamente.
3. O frontend identifica o domínio oficial e direciona chamadas para `https://api.empresa.com.br`.
4. **Resultado**: Transição 100% transparente com **zero downtime** e **zero commits adicionais**.
