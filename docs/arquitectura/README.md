# Documentación de Arquitectura - Backstage + OpenWebUI (Demo Minikube)

Esta carpeta contiene la documentación completa de la arquitectura optimizada para demo en Minikube con recursos limitados.

## 📋 Índice de Diagramas

### 🏗️ [Diagrama de Arquitectura General](./diagrama-general.md)
Arquitectura simplificada para demo en Minikube:
- **Componentes unificados**: Backstage con proxy integrado, sin API Gateway separado
- **Base de datos compartida**: PostgreSQL único para ambos servicios
- **Recursos optimizados**: Configuración específica para 4GB RAM en Minikube
- **Servicios opcionales**: Redis y Jenkins solo si hay recursos disponibles

### 🔄 [Diagrama de Flujo de Datos](./diagrama-flujo-datos.md)
Flujos optimizados para comunicación directa:
- **Autenticación básica integrada**: Sin servicio de auth separado
- **Chat directo**: Proxy integrado en Backstage hacia OpenWebUI
- **Documentación automática**: MkDocs como sidecar container
- **CI/CD simplificado**: Pipeline básico opcional

### 🧩 [Diagrama de Componentes](./diagrama-componentes.md)
Componentes optimizados para recursos limitados:
- **Frontend unificado**: Una sola interfaz con chat embebido
- **Backend simplificado**: Servicios integrados en menos pods
- **Data layer compartido**: Base de datos única con esquemas separados
- **Infraestructura básica**: Kubernetes resources mínimos necesarios

## 🎯 Objetivos de la Arquitectura Simplificada

### Demo Funcional
- **Setup rápido**: Menos de 5 minutos para estar operativo
- **Recursos limitados**: Funciona con 8GB RAM total del sistema
- **Funcionalidad core**: Chat integrado y documentación automática
- **Estabilidad**: Sistema estable para demostraciones de 30+ minutos

### Eficiencia de Recursos
- **Minikube optimizado**: 4GB RAM, 2 CPU cores asignados
- **Pods mínimos**: Solo 4 pods core obligatorios
- **Comunicación directa**: Sin overhead de API Gateway
- **Base de datos compartida**: Menor uso de memoria y almacenamiento

### Simplicidad Operacional
- **Menos configuración**: Configuración mínima necesaria
- **Debugging fácil**: Menos componentes para troubleshoot
- **Monitoreo básico**: Logs nativos de Kubernetes

## 🛠️ Stack Tecnológico Optimizado

### Core Services (Obligatorios)
- **Backstage**: Portal de desarrolladores con proxy integrado
- **OpenWebUI**: Motor de chat optimizado
- **PostgreSQL**: Base de datos compartida
- **MkDocs**: Generador de documentación como sidecar

### Optional Services (Si hay recursos)
- **Redis**: Cache para mejor performance
- **Jenkins**: CI/CD básico

### Infrastructure
- **Minikube**: Kubernetes local (4GB RAM, 2 CPU)
- **Docker**: Containerización
- **Helm**: Gestión de paquetes simplificada

## 📊 Requisitos del Sistema

### Requisitos Mínimos
- **RAM Total**: 8GB (4GB para Minikube + 4GB para SO)
- **CPU**: 4 cores físicos
- **Disco**: 20GB espacio libre
- **SO**: Linux, macOS, o Windows con WSL2

### Requisitos Recomendados
- **RAM Total**: 12GB (6GB para Minikube + 6GB para SO)
- **CPU**: 6 cores físicos
- **Disco**: 30GB espacio libre
- **SSD**: Para mejor performance

### Configuración Minikube
```bash
# Configuración mínima
minikube start --memory=4096 --cpus=2 --disk-size=20g

# Configuración recomendada
minikube start --memory=6144 --cpus=3 --disk-size=30g
```

## 🔧 Principios de Diseño para Demo

### 1. **Simplicidad sobre Completitud**
Priorizar funcionalidad core sobre características avanzadas.

### 2. **Recursos Compartidos**
Maximizar el uso de recursos compartiendo servicios cuando sea posible.

### 3. **Comunicación Directa**
Evitar componentes intermedios innecesarios para reducir latencia y overhead.

### 4. **Configuración Fija**
Usar configuraciones predefinidas para evitar complejidad de setup.

### 5. **Graceful Degradation**
Sistema funciona con servicios opcionales deshabilitados.

### 6. **Fast Startup**
Optimizar para tiempo de inicialización rápido.

## 📈 Métricas de Performance para Demo

### Startup Performance
- **Tiempo total de startup**: < 5 minutos
- **Tiempo hasta UI disponible**: < 3 minutos
- **Tiempo hasta chat funcional**: < 4 minutos

### Runtime Performance
- **Tiempo de respuesta de chat**: < 10 segundos
- **Tiempo de carga de páginas**: < 3 segundos
- **Generación de documentación**: < 30 segundos

### Resource Usage
- **RAM total utilizada**: < 3GB
- **CPU utilización promedio**: < 60%
- **Disco utilizado**: < 5GB

## 🚀 Flujo de Implementación Optimizado

### Fase 1: Setup Base (30 min)
1. **Diagramas actualizados** para arquitectura simplificada
2. **Estructura de proyecto** optimizada para demo
3. **Helm Charts básicos** con configuraciones de recursos

### Fase 2: Infraestructura (45 min)
4. **Minikube configurado** con recursos específicos
5. **Imágenes Docker** optimizadas y ligeras
6. **CI/CD básico** (opcional, si hay recursos)

### Fase 3: Aplicaciones Core (60 min)
7. **Backstage desplegado** con proxy integrado
8. **OpenWebUI desplegado** con configuración ligera
9. **Integración funcionando** entre ambos servicios

### Fase 4: Funcionalidades Avanzadas (45 min)
10. **Documentación automática** con MkDocs
11. **Chat completamente integrado** en Backstage UI

**Tiempo total estimado**: 3 horas

## ⚠️ Limitaciones Conocidas

### Escalabilidad
- **Single instance**: No load balancing
- **Recursos fijos**: No auto-scaling
- **Shared database**: Posible cuello de botella

### Disponibilidad
- **No redundancia**: Sin réplicas para alta disponibilidad
- **Single point of failure**: Falla de un pod afecta funcionalidad
- **Backup manual**: Sin backup automático

### Seguridad
- **Autenticación básica**: No production-ready
- **Comunicación interna**: Sin encriptación adicional
- **Secrets básicos**: Gestión simple de credenciales

## 🔄 Migración a Producción

### Componentes a Agregar
- **API Gateway**: Kong, Istio, o similar
- **Auth Service**: Keycloak, Auth0, o similar
- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack o similar
- **Service Mesh**: Istio para comunicación segura

### Configuraciones a Cambiar
- **Recursos**: Aumentar requests/limits
- **Replicas**: Múltiples instancias de cada servicio
- **Persistence**: Bases de datos externas
- **Security**: HTTPS, RBAC, Network Policies
- **Backup**: Estrategia de backup automático

## 📚 Referencias Específicas para Demo

- [Minikube Resource Management](https://minikube.sigs.k8s.io/docs/handbook/config/)
- [Backstage Configuration](https://backstage.io/docs/conf/)
- [OpenWebUI Docker Setup](https://docs.openwebui.com/getting-started/)
- [Helm Resource Limits](https://helm.sh/docs/chart_best_practices/resources/)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

**Nota**: Esta documentación está optimizada específicamente para demos en Minikube con recursos limitados. Para implementaciones de producción, consultar la documentación de arquitectura completa.
