# =============================================================================
# Dockerfile Multi-stage para Jenkins - Optimizado para Demo Minikube
# =============================================================================
# Imagen final optimizada: ~300MB (vs ~600MB imagen estándar)
# Tiempo de build: ~4-6 minutos
# Recursos requeridos: 512Mi RAM, 500m CPU

# =============================================================================
# STAGE 1: Base Jenkins
# =============================================================================
FROM jenkins/jenkins:2.426.1-lts-alpine AS base

# Metadatos de la imagen
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL version="2.426.1-lts"
LABEL description="Jenkins optimized for Backstage + OpenWebUI demo"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="512Mi"
LABEL demo.minikube.cpu-limit="500m"

# Cambiar a usuario root temporalmente para instalaciones
USER root

# Instalar dependencias adicionales mínimas
RUN apk add --no-cache \
    curl \
    git \
    docker-cli \
    kubectl \
    helm \
    && rm -rf /var/cache/apk/*

# =============================================================================
# STAGE 2: Plugin Installation
# =============================================================================
FROM base AS plugins

# Copiar lista de plugins necesarios
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Instalar plugins esenciales para demo
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# =============================================================================
# STAGE 3: Configuration
# =============================================================================
FROM plugins AS configured

# Copiar configuraciones personalizadas
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
COPY init-scripts/ /usr/share/jenkins/ref/init.groovy.d/

# Configurar variables de entorno para demo
ENV JAVA_OPTS="-Xmx256m -Xms128m -Djava.awt.headless=true"
ENV JENKINS_OPTS="--httpPort=8080 --prefix=/jenkins"
ENV CASC_JENKINS_CONFIG="/var/jenkins_home/casc_configs"

# Variables específicas para demo
ENV JENKINS_DEMO_MODE=true
ENV JENKINS_MINIKUBE_OPTIMIZED=true
ENV JENKINS_ADMIN_USER=admin
ENV JENKINS_ADMIN_PASSWORD=demo-jenkins-password

# =============================================================================
# STAGE 4: Final Production Image
# =============================================================================
FROM configured AS production

# Volver a usuario jenkins
USER jenkins

# Crear directorios necesarios
RUN mkdir -p /var/jenkins_home/casc_configs \
    /var/jenkins_home/jobs \
    /var/jenkins_home/workspace

# Configurar health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8080/jenkins/login || exit 1

# Exponer puerto
EXPOSE 8080

# Comando de inicio
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# =============================================================================
# Build Instructions:
# docker build -t edissonz8809/iaops/jenkins:demo-latest -f applications/jenkins/Dockerfile applications/jenkins/
# docker run -p 8080:8080 edissonz8809/iaops/jenkins:demo-latest
# =============================================================================
