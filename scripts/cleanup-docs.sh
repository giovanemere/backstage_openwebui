#!/bin/bash

# Script de Limpieza de Documentación Obsoleta
# Fecha: 31 de Julio de 2025
# Propósito: Eliminar archivos markdown obsoletos y duplicados en docs/

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

log "🧹 Iniciando limpieza de documentación obsoleta en docs/..."

# Crear backup antes de la limpieza
BACKUP_DIR="backup-docs-$(date +%Y%m%d-%H%M%S)"
log "📦 Creando backup de docs/ en: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r docs/ "$BACKUP_DIR/"
success "Backup creado en: $BACKUP_DIR"

# Función para hacer backup y eliminar archivo
backup_and_remove_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log "📄 Procesando: $file"
        # El archivo ya está en el backup general
        # Eliminar archivo
        rm "$file"
        success "Eliminado: $file"
    else
        log "⏭️  Ya eliminado o no existe: $file"
    fi
}

# Contar archivos antes de la limpieza
TOTAL_BEFORE=$(find docs/ -name "*.md" -type f | wc -l)
SIZE_BEFORE=$(du -sh docs/ | cut -f1)

log "📊 Estado inicial:"
log "   - Archivos .md: $TOTAL_BEFORE"
log "   - Tamaño total: $SIZE_BEFORE"

# Fase 1: Eliminar archivos de seguimiento temporal (obsoletos)
log "📁 Fase 1: Eliminando archivos de seguimiento temporal..."

backup_and_remove_file "docs/seguimiento-progreso.md"
backup_and_remove_file "docs/plan-implementacion.md"
backup_and_remove_file "docs/control-ajustes-estructura.md"

# Fase 2: Eliminar reportes automáticos temporales
log "📁 Fase 2: Eliminando reportes automáticos temporales..."

# Eliminar todos los reportes de limpieza con timestamp
for report in docs/reporte-limpieza-*.md; do
    if [[ -f "$report" ]]; then
        backup_and_remove_file "$report"
    fi
done

# Fase 3: Eliminar resúmenes duplicados
log "📁 Fase 3: Eliminando resúmenes duplicados..."

backup_and_remove_file "docs/resumen-final.md"
backup_and_remove_file "docs/resumen-ejecutivo-optimizacion.md"

# Mantener solo: docs/resumen-final-optimizacion.md (más completo)

# Fase 4: Eliminar este archivo de análisis (temporal)
log "📁 Fase 4: Eliminando archivo de análisis temporal..."

backup_and_remove_file "docs/analisis-archivos-obsoletos.md"

# Contar archivos después de la limpieza
TOTAL_AFTER=$(find docs/ -name "*.md" -type f | wc -l)
SIZE_AFTER=$(du -sh docs/ | cut -f1)
REMOVED=$((TOTAL_BEFORE - TOTAL_AFTER))

# Generar reporte de limpieza
log "📊 Generando reporte de limpieza de documentación..."

REPORT_FILE="docs/reporte-limpieza-docs-$(date +%Y%m%d-%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# Reporte de Limpieza de Documentación

**Fecha**: $(date)
**Script**: cleanup-docs.sh
**Backup**: $BACKUP_DIR

## Archivos Eliminados

### Archivos de Seguimiento Temporal (Obsoletos)
- docs/seguimiento-progreso.md (30KB) - Seguimiento diario obsoleto
- docs/plan-implementacion.md (20KB) - Plan ya completado
- docs/control-ajustes-estructura.md (19KB) - Control temporal de cambios

### Reportes Automáticos Temporales
- docs/reporte-limpieza-20250730-215950.md (2KB) - Reporte específico obsoleto

### Resúmenes Duplicados
- docs/resumen-final.md (10KB) - Información duplicada
- docs/resumen-ejecutivo-optimizacion.md (9KB) - Información duplicada

### Archivos de Análisis Temporal
- docs/analisis-archivos-obsoletos.md (15KB) - Análisis temporal

## Archivos Mantenidos

### Documentación Principal
- docs/estructura-proyecto.md (28KB) - ✅ Documentación principal
- docs/analisis-limpieza-estructura.md (14KB) - ✅ Análisis de optimización
- docs/resumen-actualizacion-estructura.md (16KB) - ✅ Cambios realizados
- docs/resumen-final-optimizacion.md (9KB) - ✅ Resumen consolidado

### Documentación Técnica
- docs/jenkins-setup.md (11KB) - ✅ Setup de Jenkins
- docs/backstage-deployment.md (9KB) - ✅ Despliegue Backstage
- docs/openwebui-deployment.md (14KB) - ✅ Despliegue OpenWebUI
- docs/docker-images.md (12KB) - ✅ Imágenes Docker
- docs/tarea3-helm-resumen.md (8KB) - ✅ Charts Helm

### Arquitectura
- docs/arquitectura/ - ✅ Diagramas y arquitectura

## Métricas

### Antes de la Limpieza
- Archivos .md: $TOTAL_BEFORE
- Tamaño: $SIZE_BEFORE

### Después de la Limpieza
- Archivos .md: $TOTAL_AFTER
- Tamaño: $SIZE_AFTER
- Archivos eliminados: $REMOVED
- Reducción: $(echo "scale=1; ($REMOVED * 100) / $TOTAL_BEFORE" | bc -l)%

## Backup

Backup completo creado en: $BACKUP_DIR

## Validación Requerida

- [ ] Verificar que documentación principal contiene información esencial
- [ ] Probar navegación en docs/ es más clara
- [ ] Confirmar que no hay referencias rotas
- [ ] Validar que información crítica está preservada

EOF

success "Reporte generado: $REPORT_FILE"

# Validación básica
log "🔍 Realizando validación básica..."

# Verificar que archivos críticos existen
CRITICAL_DOCS=(
    "docs/estructura-proyecto.md"
    "docs/resumen-final-optimizacion.md"
    "docs/analisis-limpieza-estructura.md"
    "docs/resumen-actualizacion-estructura.md"
)

for doc in "${CRITICAL_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        success "Documentación crítica presente: $doc"
    else
        error "Documentación crítica faltante: $doc"
    fi
done

# Verificar que directorio arquitectura existe
if [[ -d "docs/arquitectura" ]]; then
    success "Directorio de arquitectura presente: docs/arquitectura"
else
    error "Directorio de arquitectura faltante: docs/arquitectura"
fi

# Mostrar estructura final
log "📊 Estructura final de docs/:"
tree docs/ 2>/dev/null || find docs/ -type f -name "*.md" | sort

# Resumen final
log "🎉 Limpieza de documentación completada exitosamente!"
echo
success "✅ Documentación optimizada y simplificada"
success "✅ Archivos eliminados: $REMOVED de $TOTAL_BEFORE (-$(echo "scale=1; ($REMOVED * 100) / $TOTAL_BEFORE" | bc -l)%)"
success "✅ Backup creado en: $BACKUP_DIR"
success "✅ Reporte generado: $REPORT_FILE"
success "✅ Validación básica completada"
echo
warning "⚠️  PRÓXIMOS PASOS RECOMENDADOS:"
echo "   1. Revisar que documentación principal tiene información esencial"
echo "   2. Probar navegación en docs/ para confirmar mejora"
echo "   3. Validar que no hay referencias rotas en otros archivos"
echo "   4. Hacer commit de los cambios"
echo
log "🏁 Script de limpieza de documentación finalizado."
