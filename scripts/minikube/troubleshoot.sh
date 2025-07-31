#!/bin/bash

# =============================================================================
# Script de Troubleshooting para Minikube Demo
# =============================================================================
# Diagnostica y resuelve problemas comunes con Minikube y el demo

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
║                    🔧 TROUBLESHOOTING - MINIKUBE DEMO                       ║
║                                                                              ║
║                        Diagnóstico y Solución de Problemas                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

show_usage() {
    cat << EOF
Script de Troubleshooting para Minikube Demo

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    diagnose        Ejecutar diagnóstico completo (default)
    fix-common      Intentar reparar problemas comunes
    reset-cluster   Resetear cluster completamente
    check-pods      Verificar estado de pods
    check-services  Verificar servicios
    check-ingress   Verificar ingress controller
    logs            Mostrar logs relevantes
    cleanup         Limpiar recursos huérfanos

OPTIONS:
    --cluster NAME  Nombre del cluster (default: $CLUSTER_NAME)
    --verbose       Output detallado
    --help          Mostrar esta ayuda

EXAMPLES:
    $0                      # Diagnóstico completo
    $0 fix-common          # Reparar problemas comunes
    $0 check-pods          # Solo verificar pods
    $0 logs --verbose      # Logs detallados
    $0 reset-cluster       # Resetear cluster

PROBLEMAS COMUNES QUE RESUELVE:
    • Cluster no inicia
    • Pods en estado Pending/CrashLoopBackOff
    • Servicios no accesibles
    • Ingress no funciona
    • Imágenes no se pueden descargar
    • Recursos insuficientes
EOF
}

# =============================================================================
# FUNCIONES DE DIAGNÓSTICO
# =============================================================================

diagnose_cluster_status() {
    log_step "Diagnóstico del Estado del Cluster"
    
    # Verificar si Minikube está ejecutándose
    if ! minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        log_error "Cluster '$CLUSTER_NAME' no está ejecutándose"
        echo -e "  ${YELLOW}Solución:${NC} ./scripts/minikube/setup-minikube.sh"
        return 1
    fi
    
    log_success "Cluster '$CLUSTER_NAME' está ejecutándose"
    
    # Mostrar información básica
    log_info "Información del cluster:"
    minikube status -p "$CLUSTER_NAME"
    
    # Verificar nodos
    log_info "Estado de nodos:"
    kubectl get nodes -o wide
    
    # Verificar componentes del sistema
    log_info "Componentes del sistema:"
    kubectl get pods -n kube-system --no-headers | while read -r line; do
        local pod_name
        local status
        pod_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        
        if [[ "$status" == "Running" ]]; then
            echo -e "  ✅ $pod_name"
        else
            echo -e "  ❌ $pod_name ($status)"
        fi
    done
    
    return 0
}

diagnose_resources() {
    log_step "Diagnóstico de Recursos"
    
    # Verificar uso de recursos del cluster
    log_info "Uso de recursos del cluster:"
    kubectl top nodes 2>/dev/null || log_warning "Metrics server no disponible"
    
    # Verificar recursos por namespace
    log_info "Recursos por namespace:"
    kubectl get resourcequota --all-namespaces
    
    # Verificar pods con problemas de recursos
    log_info "Pods con problemas de recursos:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded | grep -v "No resources found" || log_info "No hay pods con problemas"
    
    # Verificar eventos relacionados con recursos
    log_info "Eventos recientes relacionados con recursos:"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "insufficient\|failed\|error" | tail -10 || log_info "No hay eventos de error recientes"
}

diagnose_networking() {
    log_step "Diagnóstico de Red"
    
    # Verificar servicios
    log_info "Servicios del sistema:"
    kubectl get services --all-namespaces
    
    # Verificar ingress controller
    log_info "Estado del Ingress Controller:"
    kubectl get pods -n ingress-nginx --no-headers | while read -r line; do
        local pod_name
        local status
        pod_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        
        if [[ "$status" == "Running" ]]; then
            echo -e "  ✅ $pod_name"
        else
            echo -e "  ❌ $pod_name ($status)"
        fi
    done
    
    # Verificar DNS
    log_info "Probando resolución DNS:"
    kubectl run dns-test --image=busybox --rm -it --restart=Never --timeout=30s -- nslookup kubernetes.default 2>/dev/null && log_success "DNS funcionando" || log_warning "Problemas con DNS"
}

diagnose_storage() {
    log_step "Diagnóstico de Almacenamiento"
    
    # Verificar storage classes
    log_info "Storage Classes:"
    kubectl get storageclass
    
    # Verificar persistent volumes
    log_info "Persistent Volumes:"
    kubectl get pv
    
    # Verificar persistent volume claims
    log_info "Persistent Volume Claims:"
    kubectl get pvc --all-namespaces
    
    # Verificar pods con problemas de storage
    log_info "Pods con problemas de almacenamiento:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' | grep -v Running | grep -v Succeeded || log_info "No hay pods con problemas de almacenamiento"
}

diagnose_images() {
    log_step "Diagnóstico de Imágenes Docker"
    
    # Verificar imágenes en Minikube
    log_info "Imágenes disponibles en Minikube:"
    minikube image ls -p "$CLUSTER_NAME" | grep "edissonz8809/iaops" || log_warning "No hay imágenes del demo cargadas"
    
    # Verificar pods con problemas de imágenes
    log_info "Pods con problemas de imágenes:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.containerStatuses[0].state}{"\n"}{end}' 2>/dev/null | grep -i "imagepull\|errimagepull" || log_info "No hay pods con problemas de imágenes"
}

# =============================================================================
# FUNCIONES DE REPARACIÓN
# =============================================================================

fix_cluster_not_starting() {
    log_step "Reparando Problemas de Inicio del Cluster"
    
    log_info "Intentando reparar cluster..."
    
    # Detener cluster si está en estado inconsistente
    minikube stop -p "$CLUSTER_NAME" 2>/dev/null || true
    
    # Limpiar configuración corrupta
    log_info "Limpiando configuración..."
    minikube delete -p "$CLUSTER_NAME" --purge 2>/dev/null || true
    
    # Limpiar cache de Docker
    log_info "Limpiando cache de Docker..."
    docker system prune -f 2>/dev/null || true
    
    # Reiniciar cluster
    log_info "Reiniciando cluster..."
    "$PROJECT_ROOT/scripts/minikube/setup-minikube.sh" --clean
    
    log_success "Cluster reparado"
}

fix_pods_not_running() {
    log_step "Reparando Pods que No Están Ejecutándose"
    
    # Obtener pods problemáticos
    local problematic_pods
    problematic_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || true)
    
    if [[ -z "$problematic_pods" ]]; then
        log_info "No hay pods problemáticos"
        return 0
    fi
    
    echo "$problematic_pods" | while read -r namespace pod_name status _; do
        log_info "Reparando pod: $namespace/$pod_name ($status)"
        
        case "$status" in
            "Pending")
                # Verificar recursos y scheduling
                kubectl describe pod "$pod_name" -n "$namespace" | grep -A 5 "Events:" || true
                
                # Intentar eliminar y recrear
                kubectl delete pod "$pod_name" -n "$namespace" --force --grace-period=0 2>/dev/null || true
                ;;
            "CrashLoopBackOff"|"Error")
                # Mostrar logs y eliminar
                log_info "Logs del pod $pod_name:"
                kubectl logs "$pod_name" -n "$namespace" --tail=20 || true
                
                kubectl delete pod "$pod_name" -n "$namespace" --force --grace-period=0 2>/dev/null || true
                ;;
            "ImagePullBackOff"|"ErrImagePull")
                # Problema con imágenes
                log_info "Problema con imagen en pod $pod_name"
                kubectl describe pod "$pod_name" -n "$namespace" | grep -A 3 "Failed to pull image" || true
                
                # Precargar imágenes
                "$PROJECT_ROOT/scripts/minikube/setup-minikube.sh" --skip-addons --skip-namespaces
                ;;
        esac
    done
    
    log_success "Reparación de pods completada"
}

fix_ingress_issues() {
    log_step "Reparando Problemas de Ingress"
    
    # Verificar si ingress addon está habilitado
    if ! minikube addons list -p "$CLUSTER_NAME" | grep ingress | grep -q enabled; then
        log_info "Habilitando addon de ingress..."
        minikube addons enable ingress -p "$CLUSTER_NAME"
    fi
    
    # Reiniciar ingress controller si está fallando
    local ingress_pods
    ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers | grep -v Running || true)
    
    if [[ -n "$ingress_pods" ]]; then
        log_info "Reiniciando ingress controller..."
        kubectl delete pods -n ingress-nginx --all
        
        # Esperar a que se reinicie
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=300s
    fi
    
    log_success "Ingress reparado"
}

fix_dns_issues() {
    log_step "Reparando Problemas de DNS"
    
    # Reiniciar CoreDNS
    log_info "Reiniciando CoreDNS..."
    kubectl delete pods -n kube-system -l k8s-app=kube-dns
    
    # Esperar a que CoreDNS esté listo
    kubectl wait --namespace kube-system \
        --for=condition=ready pod \
        --selector=k8s-app=kube-dns \
        --timeout=300s
    
    # Probar DNS
    log_info "Probando DNS..."
    kubectl run dns-test --image=busybox --rm -it --restart=Never --timeout=30s -- nslookup kubernetes.default && log_success "DNS funcionando" || log_warning "DNS aún tiene problemas"
}

fix_storage_issues() {
    log_step "Reparando Problemas de Almacenamiento"
    
    # Verificar y reparar storage class por defecto
    local default_sc
    default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    
    if [[ -z "$default_sc" ]]; then
        log_info "Configurando storage class por defecto..."
        kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
    
    # Limpiar PVCs huérfanos
    log_info "Limpiando PVCs huérfanos..."
    kubectl get pvc --all-namespaces --no-headers | while read -r namespace pvc_name status _; do
        if [[ "$status" == "Pending" ]]; then
            log_info "Eliminando PVC pendiente: $namespace/$pvc_name"
            kubectl delete pvc "$pvc_name" -n "$namespace" --force --grace-period=0 2>/dev/null || true
        fi
    done
    
    log_success "Almacenamiento reparado"
}

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

show_cluster_logs() {
    log_step "Logs del Cluster"
    
    log_info "Logs de Minikube:"
    minikube logs -p "$CLUSTER_NAME" --length=50
    
    log_info "Eventos recientes del cluster:"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
}

show_pod_details() {
    log_step "Detalles de Pods Problemáticos"
    
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | while read -r namespace pod_name status _; do
        echo
        log_info "Pod: $namespace/$pod_name ($status)"
        echo "----------------------------------------"
        kubectl describe pod "$pod_name" -n "$namespace" | head -50
        echo
        log_info "Logs del pod:"
        kubectl logs "$pod_name" -n "$namespace" --tail=10 2>/dev/null || log_warning "No se pueden obtener logs"
        echo "========================================"
    done
}

cleanup_resources() {
    log_step "Limpiando Recursos Huérfanos"
    
    # Limpiar pods terminados
    log_info "Limpiando pods terminados..."
    kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded -o name | xargs -r kubectl delete 2>/dev/null || true
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o name | xargs -r kubectl delete 2>/dev/null || true
    
    # Limpiar jobs completados
    log_info "Limpiando jobs completados..."
    kubectl get jobs --all-namespaces --field-selector=status.successful=1 -o name | xargs -r kubectl delete 2>/dev/null || true
    
    # Limpiar eventos antiguos
    log_info "Limpiando eventos antiguos..."
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | head -n -50 | awk 'NR>1 {print $1 " " $2}' | xargs -r -n2 kubectl delete event -n 2>/dev/null || true
    
    log_success "Limpieza completada"
}

reset_cluster() {
    log_step "Reseteando Cluster Completamente"
    
    log_warning "Esta operación eliminará todo el cluster y lo recreará"
    read -p "¿Continuar? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operación cancelada"
        return 0
    fi
    
    # Eliminar cluster completamente
    log_info "Eliminando cluster..."
    minikube delete -p "$CLUSTER_NAME" --purge
    
    # Limpiar Docker
    log_info "Limpiando Docker..."
    docker system prune -f
    
    # Recrear cluster
    log_info "Recreando cluster..."
    "$PROJECT_ROOT/scripts/minikube/setup-minikube.sh"
    
    log_success "Cluster reseteado completamente"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    local command="diagnose"
    local verbose=false
    local cluster_name="$CLUSTER_NAME"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            diagnose|fix-common|reset-cluster|check-pods|check-services|check-ingress|logs|cleanup)
                command=$1
                shift
                ;;
            --cluster)
                cluster_name="$2"
                shift 2
                ;;
            --verbose)
                verbose=true
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
    
    # Actualizar nombre del cluster
    CLUSTER_NAME="$cluster_name"
    
    show_banner
    echo
    
    case "$command" in
        "diagnose")
            log_info "Ejecutando diagnóstico completo del cluster '$CLUSTER_NAME'..."
            diagnose_cluster_status
            diagnose_resources
            diagnose_networking
            diagnose_storage
            diagnose_images
            ;;
        "fix-common")
            log_info "Reparando problemas comunes..."
            fix_pods_not_running
            fix_ingress_issues
            fix_dns_issues
            fix_storage_issues
            ;;
        "reset-cluster")
            reset_cluster
            ;;
        "check-pods")
            diagnose_cluster_status
            show_pod_details
            ;;
        "check-services")
            diagnose_networking
            ;;
        "check-ingress")
            fix_ingress_issues
            ;;
        "logs")
            show_cluster_logs
            if [[ "$verbose" == true ]]; then
                show_pod_details
            fi
            ;;
        "cleanup")
            cleanup_resources
            ;;
        *)
            log_error "Comando desconocido: $command"
            show_usage
            exit 1
            ;;
    esac
    
    echo
    log_success "Troubleshooting completado"
    
    # Mostrar comandos útiles
    cat << EOF

$(echo -e "${CYAN}Comandos útiles para continuar:${NC}")
  # Verificar estado general
  kubectl get pods --all-namespaces
  
  # Ver logs de un pod específico
  kubectl logs <pod-name> -n <namespace>
  
  # Acceder al dashboard
  minikube dashboard -p $CLUSTER_NAME
  
  # Reiniciar setup completo
  ./scripts/minikube/setup-minikube.sh --clean
EOF
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
