#!/bin/bash

# =============================================================================
# Setup de Jenkins para Demo Backstage + OpenWebUI
# =============================================================================
# Script para configurar Jenkins optimizado para Minikube

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuración
readonly CLUSTER_NAME="backstage-demo"
readonly NAMESPACE="jenkins"
readonly CHART_PATH="helm/jenkins"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🏗️ SETUP JENKINS - DEMO AUTOMATION                       ║
║                                                                              ║
║                        CI/CD para Backstage + OpenWebUI                     ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

show_usage() {
    cat << EOF
Setup de Jenkins para Demo

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --build-image   Construir imagen Docker de Jenkins
    --deploy-only   Solo desplegar (sin construir imagen)
    --clean         Limpiar instalación existente
    --skip-wait     No esperar a que Jenkins esté listo
    --help          Mostrar esta ayuda

EXAMPLES:
    $0                      # Setup completo
    $0 --build-image        # Construir imagen y desplegar
    $0 --deploy-only        # Solo desplegar
    $0 --clean              # Limpiar y reinstalar

RECURSOS CONFIGURADOS:
    - Memoria: 512Mi (límite), 256Mi (request)
    - CPU: 500m (límite), 100m (request)
    - Storage: 2Gi PVC
    - Namespace: $NAMESPACE

TIEMPO ESTIMADO: 3-5 minutos
EOF
}

verify_prerequisites() {
    log_step "Verificando Prerequisitos"
    
    # Verificar herramientas
    local missing_tools=()
    local required_tools=("kubectl" "helm" "docker" "minikube")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            log_info "✓ $tool encontrado"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        exit 1
    fi
    
    # Verificar cluster Minikube
    if ! minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        log_error "Cluster '$CLUSTER_NAME' no está ejecutándose"
        log_error "Ejecuta: ./scripts/minikube/setup-minikube.sh"
        exit 1
    fi
    
    # Configurar kubectl context
    kubectl config use-context "$CLUSTER_NAME"
    
    log_success "Todos los prerequisitos verificados"
}

build_jenkins_image() {
    log_step "Construyendo Imagen Docker de Jenkins"
    
    cd "$PROJECT_ROOT/docker/jenkins"
    
    log_info "Construyendo imagen optimizada de Jenkins..."
    docker build -t edissonz8809/iaops/jenkins:demo-latest .
    
    log_info "Cargando imagen en Minikube..."
    minikube image load edissonz8809/iaops/jenkins:demo-latest -p "$CLUSTER_NAME"
    
    log_success "Imagen de Jenkins construida y cargada"
}

create_namespace() {
    log_step "Configurando Namespace"
    
    log_info "Creando namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Agregar labels para demo
    kubectl label namespace "$NAMESPACE" \
        demo.minikube=true \
        demo.component=jenkins \
        --overwrite
    
    log_success "Namespace '$NAMESPACE' configurado"
}

deploy_jenkins() {
    log_step "Desplegando Jenkins con Helm"
    
    cd "$PROJECT_ROOT"
    
    log_info "Validando Chart de Helm..."
    helm lint "$CHART_PATH"
    
    log_info "Desplegando Jenkins..."
    helm upgrade --install jenkins "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout=300s \
        --values "$CHART_PATH/values.yaml"
    
    log_success "Jenkins desplegado exitosamente"
}

wait_for_jenkins() {
    log_step "Esperando a que Jenkins esté Listo"
    
    log_info "Esperando a que el pod esté listo..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=jenkins \
        --timeout=300s
    
    log_info "Esperando a que Jenkins esté completamente inicializado..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl exec -n "$NAMESPACE" -l app.kubernetes.io/name=jenkins -- curl -f http://localhost:8080/jenkins/login &> /dev/null; then
            log_success "Jenkins está listo y respondiendo"
            break
        fi
        
        log_info "Esperando Jenkins... (intento $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_warning "Jenkins tardó más de lo esperado en estar listo"
        log_info "Verifica el estado con: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=jenkins"
    fi
}

configure_ingress() {
    log_step "Configurando Acceso a Jenkins"
    
    # Verificar que ingress controller esté funcionando
    if ! kubectl get pods -n ingress-nginx | grep -q "Running"; then
        log_warning "Ingress controller no está ejecutándose"
        log_info "Habilitando addon de ingress..."
        minikube addons enable ingress -p "$CLUSTER_NAME"
        
        # Esperar a que ingress controller esté listo
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=300s
    fi
    
    log_info "Verificando configuración de ingress..."
    kubectl get ingress -n "$NAMESPACE"
    
    log_success "Ingress configurado"
}

show_access_info() {
    log_step "Información de Acceso"
    
    local minikube_ip
    minikube_ip=$(minikube ip -p "$CLUSTER_NAME")
    
    echo
    log_success "🎉 Jenkins desplegado exitosamente!"
    echo
    
    cat << EOF
$(echo -e "${CYAN}Información de Acceso:${NC}")
  URL: http://$minikube_ip/jenkins
  Usuario: admin
  Contraseña: demo123
  
$(echo -e "${CYAN}Usuario Demo:${NC}")
  Usuario: demo
  Contraseña: demo123

$(echo -e "${CYAN}Pipelines Disponibles:${NC}")
  • Demo/backstage-build - Build y deploy de Backstage
  • Demo/openwebui-build - Build y deploy de OpenWebUI
  • Demo/full-deploy - Despliegue completo del demo

$(echo -e "${CYAN}Comandos Útiles:${NC}")
  # Ver pods de Jenkins
  kubectl get pods -n $NAMESPACE
  
  # Ver logs de Jenkins
  kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/name=jenkins
  
  # Port-forward directo
  kubectl port-forward -n $NAMESPACE svc/jenkins 8080:8080
  
  # Acceder al pod
  kubectl exec -it -n $NAMESPACE -l app.kubernetes.io/name=jenkins -- bash

$(echo -e "${CYAN}Configuración del Sistema:${NC}")
  Namespace: $NAMESPACE
  Recursos: 512Mi RAM, 500m CPU (límites)
  Storage: 2Gi PVC
  Ingress: Habilitado con nginx

$(echo -e "${GREEN}¡Jenkins listo para CI/CD del demo!${NC}")
EOF
}

cleanup_jenkins() {
    log_step "Limpiando Instalación Existente"
    
    log_info "Eliminando release de Helm..."
    helm uninstall jenkins -n "$NAMESPACE" 2>/dev/null || true
    
    log_info "Eliminando recursos restantes..."
    kubectl delete all,pvc,configmap,secret,ingress -l app.kubernetes.io/name=jenkins -n "$NAMESPACE" 2>/dev/null || true
    
    log_info "Eliminando namespace..."
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    log_success "Instalación anterior limpiada"
}

main() {
    local build_image=false
    local deploy_only=false
    local clean=false
    local skip_wait=false
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-image)
                build_image=true
                shift
                ;;
            --deploy-only)
                deploy_only=true
                shift
                ;;
            --clean)
                clean=true
                shift
                ;;
            --skip-wait)
                skip_wait=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Argumento desconocido: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    show_banner
    echo
    
    local start_time
    start_time=$(date +%s)
    
    verify_prerequisites
    
    if [[ "$clean" == true ]]; then
        cleanup_jenkins
    fi
    
    if [[ "$deploy_only" != true ]]; then
        build_jenkins_image
    fi
    
    create_namespace
    deploy_jenkins
    configure_ingress
    
    if [[ "$skip_wait" != true ]]; then
        wait_for_jenkins
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_access_info
    
    echo
    log_success "Setup de Jenkins completado en ${duration} segundos"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
