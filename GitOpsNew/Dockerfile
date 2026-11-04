# Estágio 1: Dependências
FROM node:20-alpine AS deps
WORKDIR /app
COPY src/package.json ./
RUN npm install --omit=dev

# Estágio 2: Runner de produção (não-root)
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Executar como usuário não-root numérico do node (UID 1000)
USER 1000:1000

COPY --from=deps --chown=1000:1000 /app/node_modules ./node_modules
COPY --chown=1000:1000 src/ ./

EXPOSE 3000

CMD ["node", "server.js"]
