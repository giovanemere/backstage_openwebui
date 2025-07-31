# =============================================================================
# Jenkins Multi-Stage Dockerfile - Optimizado para Demo Minikube
# =============================================================================
# Imagen Jenkins ligera con plugins esenciales y configuración para demo
# Tamaño final: ~300MB (vs ~600MB imagen estándar)

# =============================================================================
# Stage 1: Base Jenkins LTS
# =============================================================================
FROM jenkins/jenkins:2.426.1-lts-slim as base

# Metadata para demo
LABEL maintainer="Amazon Q <demo@example.com>" \
      version="1.0.0" \
      description="Jenkins optimizado para demo Backstage + OpenWebUI" \
      demo.component="jenkins" \
      demo.optimized="true" \
      demo.minikube="true"

# Cambiar a usuario root temporalmente para instalaciones
USER root

# Instalar dependencias mínimas
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    docker.io \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Agregar usuario jenkins al grupo docker
RUN usermod -aG docker jenkins

# =============================================================================
# Stage 2: Plugin Installation
# =============================================================================
FROM base as plugins

# Cambiar a usuario jenkins para instalar plugins
USER jenkins

# Lista de plugins esenciales para demo (mínimos)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Instalar plugins usando jenkins-plugin-cli
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# =============================================================================
# Stage 3: Configuration
# =============================================================================
FROM plugins as config

# Copiar configuraciones personalizadas
COPY --chown=jenkins:jenkins config/ /usr/share/jenkins/ref/

# Copiar scripts de inicialización
COPY --chown=jenkins:jenkins init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

# Copiar jobs predefinidos
COPY --chown=jenkins:jenkins jobs/ /usr/share/jenkins/ref/jobs/

# =============================================================================
# Stage 4: Final Optimized Image
# =============================================================================
FROM config as final

# Volver a usuario jenkins
USER jenkins

# Variables de entorno para demo
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xmx256m -Xms128m" \
    JENKINS_OPTS="--httpPort=8080 --prefix=/jenkins" \
    JENKINS_SLAVE_AGENT_PORT=50000 \
    JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental \
    COPY_REFERENCE_FILE_LOG=/var/jenkins_home/copy_reference_file.log

# Exponer puertos
EXPOSE 8080 50000

# Health check optimizado
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/jenkins/login || exit 1

# Punto de entrada
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
