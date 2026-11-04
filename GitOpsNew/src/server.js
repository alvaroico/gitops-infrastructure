const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

let requestCount = 0;

// Health check para Kubernetes Probes
app.get(['/health', '/node/health'], (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// Endpoint JSON estruturado
app.get(['/api', '/node/api'], (req, res) => {
  requestCount++;
  res.json({
    version: APP_VERSION,
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    requestCount,
    timestamp: new Date().toISOString()
  });
});

// Interface Web HTML visual
app.get(['/', '/node'], (req, res) => {
  requestCount++;
  const html = `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Deploy Automático GitOps - Kubernetes</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
    .card { background: #1e293b; padding: 2.5rem; border-radius: 1rem; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.5); width: 100%; max-width: 500px; border: 1px solid #334155; }
    h1 { color: #38bdf8; font-size: 1.5rem; margin-top: 0; }
    .badge { display: inline-block; background: #0284c7; color: white; padding: 0.25rem 0.75rem; border-radius: 9999px; font-weight: bold; font-size: 0.875rem; margin-bottom: 1rem; }
    .info { margin: 0.75rem 0; padding: 0.75rem; background: #0f172a; border-radius: 0.5rem; border-left: 4px solid #38bdf8; }
    .label { color: #94a3b8; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; }
    .val { font-size: 1.1rem; font-family: monospace; color: #e2e8f0; word-break: break-all; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Deploy Automático K3s Ativo</div>
    <h1>🚀 Node.js GitOps Demo</h1>
    <div class="info">
      <div class="label">Versão da Aplicação</div>
      <div class="val">${APP_VERSION}</div>
    </div>
    <div class="info">
      <div class="label">Pod Kubernetes (Hostname)</div>
      <div class="val">${os.hostname()}</div>
    </div>
    <div class="info">
      <div class="label">Total de Requisições Atendidas</div>
      <div class="val">${requestCount}</div>
    </div>
    <div class="info">
      <div class="label">Arquitetura do Nó</div>
      <div class="val">${os.platform()} (${os.arch()})</div>
    </div>
  </div>
</body>
</html>
  `;
  res.send(html);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Node API rodando na porta ${PORT} (Versão: ${APP_VERSION})`);
});
