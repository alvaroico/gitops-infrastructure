# Reorganização da Pipeline de CI no GitHub Actions

## Objetivo

Separar responsabilidades:
- **CI (GitHub Actions)**: Responsável unicamente por validar o código, compilar os artefatos, construir as imagens Docker (multi-arquitetura ARM64/AMD64) e publicar no container registry (**GHCR - GitHub Container Registry**).
- **CD (ArgoCD)**: Responsável por observar as mudanças e realizar o deploy no cluster k3s.

---

## Estrutura do Workflow Renovado (`.github/workflows/ci.yaml`)

```yaml
name: CI - Build & Push Docker Image

on:
  push:
    branches: [ alvaroico, main ]
  pull_request:
    branches: [ alvaroico, main ]

jobs:
  build-and-push:
    name: Build Multi-Arch Docker Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest
            type=sha,format=short,prefix=sha-

      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Principais Melhorias Implementadas

1. **Build Multi-Arquitetura Inteligente**: Permite rodar a imagem tanto em servidores x86/AMD64 quanto em instâncias ARM64 (Apple Silicon / AWS Graviton).
2. **Cache de Build GHA**: Acelera o tempo de compilação usando cache do GitHub Actions.
3. **Tagging Dinâmico (`sha-XXXXXXX` e `latest`)**: Permite rastreabilidade exata do commit que gerou cada imagem Docker.
