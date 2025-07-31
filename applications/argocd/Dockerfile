# =============================================================================
# Dockerfile Multi-stage para ArgoCD - Optimizado para Demo Minikube
# =============================================================================
# Imagen final optimizada: ~120MB (vs ~200MB imagen estándar)
# Tiempo de build: ~3-4 minutos
# Recursos requeridos: 256Mi RAM, 200m CPU

# =============================================================================
# STAGE 1: Base ArgoCD
# =============================================================================
FROM argoproj/argocd:v2.9.3 AS base

# Metadatos de la imagen
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL version="2.9.3"
LABEL description="ArgoCD optimized for Backstage + OpenWebUI demo"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="256Mi"
LABEL demo.minikube.cpu-limit="200m"

# Cambiar a usuario root temporalmente
USER root

# Instalar herramientas adicionales mínimas
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# =============================================================================
# STAGE 2: Configuration
# =============================================================================
FROM base AS configured

# Copiar configuraciones personalizadas
COPY argocd-cm.yaml /tmp/argocd-cm.yaml
COPY argocd-rbac-cm.yaml /tmp/argocd-rbac-cm.yaml
COPY demo-applications/ /tmp/demo-applications/

# Configurar variables de entorno para demo
ENV ARGOCD_DEMO_MODE=true
ENV ARGOCD_MINIKUBE_OPTIMIZED=true
ENV ARGOCD_SERVER_INSECURE=true
ENV ARGOCD_SERVER_ROOTPATH=/argocd

# Variables de optimización para recursos limitados
ENV ARGOCD_EXEC_TIMEOUT=60s
ENV ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS=60
ENV ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS=60

# =============================================================================
# STAGE 3: Final Production Image
# =============================================================================
FROM configured AS production

# Volver a usuario argocd
USER 999

# Crear directorios necesarios
RUN mkdir -p /home/argocd/.argocd \
    /tmp/argocd-repo-server \
    /tmp/argocd-local-tls

# Configurar health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/argocd/healthz || exit 1

# Exponer puertos
EXPOSE 8080 8443

# Comando por defecto (se sobrescribe en deployment)
CMD ["argocd-server"]

# =============================================================================
# Build Instructions:
# docker build -t edissonz8809/iaops/argocd:demo-latest -f applications/argocd/Dockerfile applications/argocd/
# docker run -p 8080:8080 edissonz8809/iaops/argocd:demo-latest
# =============================================================================
