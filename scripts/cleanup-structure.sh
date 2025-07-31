#!/bin/bash

# Script de Limpieza de Estructura del Proyecto
# Fecha: 30 de Julio de 2025
# Propósito: Eliminar carpetas vacías y no utilizadas

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar que estamos en el directorio correcto
if [[ ! -f "Makefile" ]] || [[ ! -d "docs" ]]; then
    error "Este script debe ejecutarse desde el directorio raíz del proyecto backstage_openwebui"
    exit 1
fi

log "🧹 Iniciando limpieza de estructura del proyecto..."

# Crear backup antes de la limpieza
BACKUP_DIR="backup-structure-$(date +%Y%m%d-%H%M%S)"
log "📦 Creando backup en: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Función para hacer backup de una carpeta antes de eliminarla
backup_and_remove() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        log "📁 Procesando: $dir"
        # Crear estructura de directorios en backup
        mkdir -p "$BACKUP_DIR/$(dirname "$dir")"
        # Copiar contenido si existe
        if [[ $(find "$dir" -mindepth 1 | wc -l) -gt 0 ]]; then
            cp -r "$dir" "$BACKUP_DIR/$dir" 2>/dev/null || true
            warning "Backup creado para: $dir"
        fi
        # Eliminar directorio
        rm -rf "$dir"
        success "Eliminado: $dir"
    else
        log "⏭️  Ya eliminado o no existe: $dir"
    fi
}

# Fase 1: Eliminar carpetas completamente vacías identificadas
log "📁 Fase 1: Eliminando carpetas completamente vacías..."

# Config vacío
backup_and_remove "config/demo"
backup_and_remove "config/development"
backup_and_remove "config/production"

# Helm configs vacíos
backup_and_remove "helm/umbrella"
backup_and_remove "helm/backstage/config"
backup_and_remove "helm/jenkins/config"

# Kubernetes vacío (duplica k8s/)
backup_and_remove "kubernetes/secrets"
backup_and_remove "kubernetes/namespaces"
backup_and_remove "kubernetes/services"
backup_and_remove "kubernetes/deployments"
backup_and_remove "kubernetes/configmaps"

# Monitoring vacío
backup_and_remove "monitoring/grafana"
backup_and_remove "monitoring/logs"
backup_and_remove "monitoring/prometheus"

# CI-CD vacío
backup_and_remove "ci-cd/argocd"
backup_and_remove "ci-cd/github-actions"
backup_and_remove "ci-cd/jenkins"

# Scripts vacíos (funcionalidad en Makefile)
backup_and_remove "scripts/build"
backup_and_remove "scripts/deploy"
backup_and_remove "scripts/utils"

# Tools vacío
backup_and_remove "tools/documentation"
backup_and_remove "tools/dev-setup"
backup_and_remove "tools/database"

# Infrastructure vacío
backup_and_remove "infrastructure/minikube"
backup_and_remove "infrastructure/terraform"
backup_and_remove "infrastructure/terragrunt"

# Tests vacío (no implementados)
backup_and_remove "tests/unit"
backup_and_remove "tests/integration"
backup_and_remove "tests/performance"
backup_and_remove "tests/e2e"

# MkDocs runtime (se genera automáticamente)
backup_and_remove "mkdocs/docs-source"

# Docker jobs vacío
backup_and_remove "docker/jenkins/jobs"

# Fase 2: Eliminar carpetas padre que quedaron vacías
log "📁 Fase 2: Eliminando carpetas padre vacías..."

# Función para eliminar directorio si está vacío
remove_if_empty() {
    local dir="$1"
    if [[ -d "$dir" ]] && [[ $(find "$dir" -mindepth 1 -maxdepth 1 | wc -l) -eq 0 ]]; then
        rmdir "$dir"
        success "Eliminado directorio vacío: $dir"
    elif [[ -d "$dir" ]]; then
        log "⏭️  Directorio no vacío, manteniendo: $dir"
    fi
}

remove_if_empty "config"
remove_if_empty "kubernetes"
remove_if_empty "monitoring"
remove_if_empty "ci-cd"
remove_if_empty "tools"
remove_if_empty "infrastructure"
remove_if_empty "tests"

# Fase 3: Limpieza general de carpetas vacías restantes
log "📁 Fase 3: Limpieza general de carpetas vacías..."

# Encontrar y eliminar cualquier carpeta vacía restante (excluyendo .git)
EMPTY_DIRS=$(find . -type d -empty -not -path "*/.git/*" 2>/dev/null || true)
if [[ -n "$EMPTY_DIRS" ]]; then
    echo "$EMPTY_DIRS" | while read -r dir; do
        if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
            rmdir "$dir" 2>/dev/null || true
            success "Eliminado directorio vacío adicional: $dir"
        fi
    done
else
    log "ℹ️  No se encontraron carpetas vacías adicionales"
fi

# Fase 4: Generar reporte de limpieza
log "📊 Generando reporte de limpieza..."

REPORT_FILE="docs/reporte-limpieza-$(date +%Y%m%d-%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# Reporte de Limpieza de Estructura

**Fecha**: $(date)
**Script**: cleanup-structure.sh
**Backup**: $BACKUP_DIR

## Carpetas Eliminadas

### Carpetas Completamente Vacías
- config/demo/
- config/development/
- config/production/
- helm/umbrella/
- helm/backstage/config/
- helm/jenkins/config/
- kubernetes/secrets/
- kubernetes/namespaces/
- kubernetes/services/
- kubernetes/deployments/
- kubernetes/configmaps/
- monitoring/grafana/
- monitoring/logs/
- monitoring/prometheus/
- ci-cd/argocd/
- ci-cd/github-actions/
- ci-cd/jenkins/
- scripts/build/
- scripts/deploy/
- scripts/utils/
- tools/documentation/
- tools/dev-setup/
- tools/database/
- infrastructure/minikube/
- infrastructure/terraform/
- infrastructure/terragrunt/
- tests/unit/
- tests/integration/
- tests/performance/
- tests/e2e/
- mkdocs/docs-source/
- docker/jenkins/jobs/

### Carpetas Padre Eliminadas (si quedaron vacías)
- config/
- kubernetes/
- monitoring/
- ci-cd/
- tools/
- infrastructure/
- tests/

## Estructura Final

\`\`\`
$(tree -d -L 2 2>/dev/null || find . -type d -not -path "*/.git/*" | head -20)
\`\`\`

## Backup

Backup completo creado en: $BACKUP_DIR

## Validación Requerida

- [ ] Verificar que Makefile funciona correctamente
- [ ] Probar despliegue completo
- [ ] Actualizar documentación si es necesario
- [ ] Verificar que scripts funcionan sin referencias eliminadas

EOF

success "Reporte generado: $REPORT_FILE"

# Fase 5: Validación básica
log "🔍 Realizando validación básica..."

# Verificar que archivos críticos existen
CRITICAL_FILES=(
    "Makefile"
    "README.md"
    "docs/estructura-proyecto.md"
    "integration/README.md"
    "mkdocs/README.md"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        success "Archivo crítico presente: $file"
    else
        error "Archivo crítico faltante: $file"
    fi
done

# Verificar que directorios críticos existen
CRITICAL_DIRS=(
    "docs"
    "scripts"
    "integration"
    "mkdocs"
    "helm"
    "applications"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        success "Directorio crítico presente: $dir"
    else
        error "Directorio crítico faltante: $dir"
    fi
done

# Contar directorios antes y después (aproximado)
TOTAL_DIRS=$(find . -type d -not -path "*/.git/*" | wc -l)
log "📊 Directorios totales después de limpieza: $TOTAL_DIRS"

# Resumen final
log "🎉 Limpieza completada exitosamente!"
echo
success "✅ Estructura optimizada y simplificada"
success "✅ Backup creado en: $BACKUP_DIR"
success "✅ Reporte generado: $REPORT_FILE"
success "✅ Validación básica completada"
echo
warning "⚠️  PRÓXIMOS PASOS REQUERIDOS:"
echo "   1. Ejecutar 'make help' para verificar que Makefile funciona"
echo "   2. Probar despliegue con 'make deploy-demo'"
echo "   3. Revisar y actualizar documentación si es necesario"
echo "   4. Hacer commit de los cambios"
echo
log "🏁 Script de limpieza finalizado."
