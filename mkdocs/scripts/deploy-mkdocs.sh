#!/bin/bash

# Script de Despliegue de MkDocs para Integración Backstage-OpenWebUI
# Implementa documentación automática con procesamiento de conversaciones

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Variables de configuración
NAMESPACE="mkdocs-demo"
CHART_PATH="./charts/mkdocs"
VALUES_FILE="./charts/mkdocs/values.yaml"
RELEASE_NAME="mkdocs"
DOCKER_REGISTRY="edissonz8809"
IMAGE_TAG="latest"

# Verificar prerrequisitos
check_prerequisites() {
    log "Verificando prerrequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        error "helm no está instalado"
        exit 1
    fi
    
    # Verificar docker
    if ! command -v docker &> /dev/null; then
        error "docker no está instalado"
        exit 1
    fi
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar minikube (si aplica)
    if command -v minikube &> /dev/null; then
        if minikube status | grep -q "Running"; then
            info "Minikube está ejecutándose"
        else
            warn "Minikube no está ejecutándose"
        fi
    fi
    
    log "Prerrequisitos verificados ✓"
}

# Crear namespace
create_namespace() {
    log "Creando namespace $NAMESPACE..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    app.kubernetes.io/name: mkdocs-demo
    app.kubernetes.io/part-of: backstage-openwebui-demo
    demo.minikube/component: documentation
  annotations:
    demo.minikube/optimized: "true"
    demo.minikube/description: "Namespace para MkDocs con documentación automática"
EOF
    
    log "Namespace $NAMESPACE creado ✓"
}

# Construir imágenes Docker
build_docker_images() {
    log "Construyendo imágenes Docker..."
    
    # Imagen principal de MkDocs
    log "Construyendo imagen MkDocs..."
    docker build -t ${DOCKER_REGISTRY}/iaops-mkdocs:${IMAGE_TAG} .
    
    # Imagen del procesador (usando la misma base)
    log "Construyendo imagen del procesador..."
    docker build -t ${DOCKER_REGISTRY}/iaops-mkdocs-processor:${IMAGE_TAG} \
        --target builder \
        -f Dockerfile.processor .
    
    log "Imágenes Docker construidas ✓"
}

# Crear Dockerfile para procesador
create_processor_dockerfile() {
    log "Creando Dockerfile para procesador..."
    
    cat > Dockerfile.processor <<EOF
# Dockerfile para procesador de conversaciones
FROM python:3.11-slim as base

# Metadatos
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL description="Procesador de conversaciones para MkDocs"
LABEL demo.minikube/optimized="true"

# Variables de entorno
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias Python
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Crear usuario no-root
RUN groupadd -r processor && useradd -r -g processor -u 1000 processor

# Crear directorios
RUN mkdir -p /app/{processors,templates,data,docs-source,config} && \\
    chown -R processor:processor /app

# Copiar archivos
COPY --chown=processor:processor processors/ /app/processors/
COPY --chown=processor:processor templates/ /app/templates/

# Configurar directorio de trabajo
WORKDIR /app

# Cambiar a usuario no-root
USER processor

# Comando por defecto
CMD ["python3", "/app/processors/conversation_processor.py"]
EOF
    
    log "Dockerfile del procesador creado ✓"
}

# Subir imágenes a registry
push_docker_images() {
    log "Subiendo imágenes a DockerHub..."
    
    # Login a DockerHub (si es necesario)
    if [ -n "${DOCKER_PASSWORD:-}" ]; then
        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    fi
    
    # Subir imágenes
    docker push ${DOCKER_REGISTRY}/iaops-mkdocs:${IMAGE_TAG}
    docker push ${DOCKER_REGISTRY}/iaops-mkdocs-processor:${IMAGE_TAG}
    
    log "Imágenes subidas a DockerHub ✓"
}

# Crear ConfigMaps
create_configmaps() {
    log "Creando ConfigMaps..."
    
    # ConfigMap para configuración de MkDocs
    kubectl create configmap mkdocs-config \
        --from-file=mkdocs.yml=configs/mkdocs.yml \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # ConfigMap para configuración del procesador
    kubectl create configmap mkdocs-processor-config \
        --from-file=processor_config.yaml=configs/processor_config.yaml \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # ConfigMap para templates
    kubectl create configmap mkdocs-templates \
        --from-file=templates/ \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log "ConfigMaps creados ✓"
}

# Crear configuración del procesador
create_processor_config() {
    log "Creando configuración del procesador..."
    
    mkdir -p configs
    
    cat > configs/processor_config.yaml <<EOF
# Configuración del procesador de conversaciones
processor:
  name: "MkDocs Conversation Processor"
  version: "1.0.0"
  
  # URLs de APIs
  integration_api_url: "http://backstage-openwebui-integration.integration-demo.svc.cluster.local:8000"
  backstage_api_url: "http://backstage.backstage-demo.svc.cluster.local:7007"
  
  # Configuración de procesamiento
  processing:
    batch_size: 50
    timeout: 30
    retry_attempts: 3
    retry_delay: 5
    
  # Configuración de base de datos
  database:
    path: "/app/data/conversations.db"
    backup_enabled: true
    backup_retention_days: 7
    
  # Configuración de documentación
  documentation:
    output_path: "/app/docs-source"
    template_path: "/app/templates"
    include_system_messages: false
    max_conversation_length: 1000
    
  # Configuración de análisis
  analysis:
    enable_insights: true
    enable_tags: true
    enable_summaries: true
    min_insight_confidence: 0.7
    
  # Configuración de logging
  logging:
    level: "INFO"
    format: "json"
    include_timestamps: true
EOF
    
    log "Configuración del procesador creada ✓"
}

# Crear Secrets
create_secrets() {
    log "Creando Secrets..."
    
    # Secret para tokens de integración
    kubectl create secret generic mkdocs-secrets \
        --from-literal=integration-token="demo-integration-token" \
        --from-literal=backstage-token="demo-backstage-token" \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log "Secrets creados ✓"
}

# Desplegar con Helm
deploy_with_helm() {
    log "Desplegando MkDocs con Helm..."
    
    # Validar chart
    helm lint $CHART_PATH
    
    # Instalar o actualizar
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace=$NAMESPACE \
        --values=$VALUES_FILE \
        --set image.repository=${DOCKER_REGISTRY}/iaops-mkdocs \
        --set image.tag=${IMAGE_TAG} \
        --set processor.image.repository=${DOCKER_REGISTRY}/iaops-mkdocs-processor \
        --set processor.image.tag=${IMAGE_TAG} \
        --wait \
        --timeout=300s
    
    log "MkDocs desplegado con Helm ✓"
}

# Verificar despliegue
verify_deployment() {
    log "Verificando despliegue..."
    
    # Esperar a que los pods estén listos
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mkdocs -n $NAMESPACE --timeout=300s
    
    # Verificar servicios
    kubectl get services -n $NAMESPACE
    
    # Verificar pods
    kubectl get pods -n $NAMESPACE -o wide
    
    # Verificar ingress
    kubectl get ingress -n $NAMESPACE
    
    # Test de conectividad
    log "Probando conectividad..."
    
    # Port-forward temporal para test
    kubectl port-forward -n $NAMESPACE service/mkdocs 8000:8000 &
    local pf_pid=$!
    
    sleep 10
    
    # Test health endpoint
    if curl -s http://localhost:8000/ | grep -q "Backstage-OpenWebUI"; then
        log "MkDocs respondiendo correctamente ✓"
    else
        warn "MkDocs no responde correctamente"
    fi
    
    # Limpiar port-forward
    kill $pf_pid 2>/dev/null || true
    
    log "Verificación de despliegue completada ✓"
}

# Configurar acceso externo
setup_external_access() {
    log "Configurando acceso externo..."
    
    # Verificar si hay ingress controller
    if kubectl get ingressclass &> /dev/null; then
        info "Ingress controller detectado"
        
        # Verificar ingress
        if kubectl get ingress mkdocs -n $NAMESPACE &> /dev/null; then
            log "Ingress configurado ✓"
            
            # Si es minikube, mostrar instrucciones
            if command -v minikube &> /dev/null; then
                info "Para acceder externamente:"
                info "1. Ejecutar: minikube tunnel"
                info "2. Agregar a /etc/hosts: \$(minikube ip) docs.demo.local"
                info "3. Acceder a: http://docs.demo.local"
            fi
        fi
    else
        info "No hay ingress controller, usando port-forward para acceso externo"
        info "Ejecutar: kubectl port-forward -n $NAMESPACE service/mkdocs 8000:8000"
    fi
}

# Ejecutar procesamiento inicial
run_initial_processing() {
    log "Ejecutando procesamiento inicial de conversaciones..."
    
    # Crear Job para procesamiento inicial
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: mkdocs-initial-processing
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: mkdocs
    app.kubernetes.io/component: initial-processor
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mkdocs
        app.kubernetes.io/component: initial-processor
    spec:
      restartPolicy: OnFailure
      containers:
      - name: processor
        image: ${DOCKER_REGISTRY}/iaops-mkdocs-processor:${IMAGE_TAG}
        env:
        - name: INTEGRATION_API_URL
          value: "http://backstage-openwebui-integration.integration-demo.svc.cluster.local:8000"
        - name: BACKSTAGE_API_URL
          value: "http://backstage.backstage-demo.svc.cluster.local:7007"
        - name: INTEGRATION_TOKEN
          valueFrom:
            secretKeyRef:
              name: mkdocs-secrets
              key: integration-token
        volumeMounts:
        - name: processor-config
          mountPath: /app/config
        - name: templates
          mountPath: /app/templates
        - name: docs-source
          mountPath: /app/docs-source
        - name: data
          mountPath: /app/data
      volumes:
      - name: processor-config
        configMap:
          name: mkdocs-processor-config
      - name: templates
        configMap:
          name: mkdocs-templates
      - name: docs-source
        emptyDir: {}
      - name: data
        emptyDir: {}
EOF
    
    # Esperar a que el job complete
    kubectl wait --for=condition=complete job/mkdocs-initial-processing -n $NAMESPACE --timeout=300s
    
    log "Procesamiento inicial completado ✓"
}

# Mostrar información de despliegue
show_deployment_info() {
    log "Información del despliegue:"
    
    echo ""
    echo "=== SERVICIOS DESPLEGADOS ==="
    kubectl get services -n $NAMESPACE -o wide
    
    echo ""
    echo "=== PODS ==="
    kubectl get pods -n $NAMESPACE -o wide
    
    echo ""
    echo "=== INGRESS ==="
    kubectl get ingress -n $NAMESPACE
    
    echo ""
    echo "=== CRONJOBS ==="
    kubectl get cronjobs -n $NAMESPACE
    
    echo ""
    echo "=== ENDPOINTS DE MKDOCS ==="
    echo "• Documentación: http://docs.demo.local (con ingress)"
    echo "• Port-forward: kubectl port-forward -n $NAMESPACE service/mkdocs 8000:8000"
    echo "• Acceso local: http://localhost:8000"
    
    echo ""
    echo "=== COMANDOS ÚTILES ==="
    echo "• Ver logs: kubectl logs -f deployment/mkdocs -n $NAMESPACE"
    echo "• Ver logs del procesador: kubectl logs -f job/mkdocs-initial-processing -n $NAMESPACE"
    echo "• Ejecutar procesamiento manual: kubectl create job --from=cronjob/mkdocs-processor mkdocs-manual-\$(date +%s) -n $NAMESPACE"
    echo "• Ver configuración: kubectl get configmap mkdocs-config -n $NAMESPACE -o yaml"
    echo "• Acceder al pod: kubectl exec -it deployment/mkdocs -n $NAMESPACE -- /bin/bash"
}

# Función de limpieza
cleanup() {
    log "Limpiando recursos de MkDocs..."
    
    # Eliminar release de Helm
    helm uninstall $RELEASE_NAME --namespace=$NAMESPACE || true
    
    # Eliminar namespace (esto eliminará todo lo que quede)
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Limpiar archivos temporales
    rm -f Dockerfile.processor
    
    log "Limpieza completada ✓"
}

# Función principal
main() {
    local action="${1:-deploy}"
    
    case $action in
        "deploy")
            log "=== INICIANDO DESPLIEGUE DE MKDOCS ==="
            check_prerequisites
            create_namespace
            create_processor_config
            create_processor_dockerfile
            build_docker_images
            if [ "${PUSH_IMAGES:-true}" = "true" ]; then
                push_docker_images
            fi
            create_configmaps
            create_secrets
            deploy_with_helm
            verify_deployment
            setup_external_access
            run_initial_processing
            show_deployment_info
            log "=== DESPLIEGUE DE MKDOCS COMPLETADO ✓ ==="
            ;;
        "cleanup")
            log "=== INICIANDO LIMPIEZA DE MKDOCS ==="
            cleanup
            log "=== LIMPIEZA COMPLETADA ✓ ==="
            ;;
        "status")
            log "=== ESTADO DE MKDOCS ==="
            show_deployment_info
            ;;
        "process")
            log "=== EJECUTANDO PROCESAMIENTO MANUAL ==="
            run_initial_processing
            ;;
        "build")
            log "=== CONSTRUYENDO IMÁGENES ==="
            create_processor_dockerfile
            build_docker_images
            if [ "${PUSH_IMAGES:-true}" = "true" ]; then
                push_docker_images
            fi
            ;;
        *)
            echo "Uso: $0 {deploy|cleanup|status|process|build}"
            echo ""
            echo "Comandos:"
            echo "  deploy  - Desplegar MkDocs completo"
            echo "  cleanup - Limpiar todos los recursos"
            echo "  status  - Mostrar estado actual"
            echo "  process - Ejecutar procesamiento manual"
            echo "  build   - Construir y subir imágenes Docker"
            exit 1
            ;;
    esac
}

# Ejecutar función principal con argumentos
main "$@"
