# Templates de Kubernetes para Backstage

Este directorio contiene los manifiestos de Kubernetes optimizados para desplegar Backstage en Minikube como parte del demo de integración con OpenWebUI.

## Estructura de Archivos

```
k8s/backstage/
├── namespace.yaml          # Namespace para el demo
├── serviceaccount.yaml     # ServiceAccount y RBAC
├── secret.yaml            # Secrets para tokens y DB
├── configmap.yaml         # Configuración de Backstage
├── deployment.yaml        # Deployment principal
├── service.yaml           # Servicios ClusterIP y Headless
├── ingress.yaml           # Ingress para acceso web
├── hpa.yaml              # Horizontal Pod Autoscaler
├── networkpolicy.yaml    # Políticas de red
└── README.md             # Esta documentación
```

## Componentes

### 1. Namespace (namespace.yaml)
- **Propósito**: Aislamiento de recursos del demo
- **Nombre**: `backstage-demo`
- **Labels**: Optimizado para Minikube con etiquetas de demo

### 2. ServiceAccount y RBAC (serviceaccount.yaml)
- **ServiceAccount**: `backstage`
- **ClusterRole**: Permisos de lectura para recursos K8s
- **Role**: Permisos completos en el namespace del demo
- **Funcionalidad**: Permite al plugin de Kubernetes acceder a recursos

### 3. Secrets (secret.yaml)
- **backstage-secrets**: Tokens de GitHub y OpenWebUI
- **backstage-db-secrets**: Credenciales de PostgreSQL
- **Codificación**: Base64 (valores demo incluidos)

### 4. ConfigMap (configmap.yaml)
- **backstage-config**: Configuración principal de Backstage
- **backstage-plugins**: Lista de plugins habilitados
- **Incluye**: Configuración de integración con OpenWebUI y Kubernetes

### 5. Deployment (deployment.yaml)
- **Réplicas**: 1 (optimizado para demo)
- **Recursos**: 512Mi RAM, 500m CPU (límites)
- **Init Container**: Espera a que PostgreSQL esté listo
- **Health Checks**: Liveness y readiness probes
- **Seguridad**: Usuario no-root, capabilities restringidas

### 6. Services (service.yaml)
- **backstage**: ClusterIP para acceso interno
- **backstage-headless**: Servicio headless para discovery
- **Puerto**: 7007 (puerto estándar de Backstage)

### 7. Ingress (ingress.yaml)
- **backstage-ingress**: Acceso web principal
- **backstage-api-ingress**: Acceso específico para API
- **Rutas**: `/backstage` y `/backstage-api`
- **Annotations**: Configuración de NGINX para rewrite

### 8. HPA (hpa.yaml)
- **Estado**: Deshabilitado por defecto para demo
- **Rango**: 1-2 réplicas máximo
- **Métricas**: CPU 70%, Memoria 80%

### 9. Network Policy (networkpolicy.yaml)
- **Ingress**: Permite tráfico desde ingress-nginx y OpenWebUI
- **Egress**: Permite conexión a PostgreSQL y servicios externos
- **Seguridad**: Política permisiva para demo, restrictiva para producción

## Despliegue

### Método 1: Script Automatizado
```bash
# Usar el script de despliegue
./scripts/backstage/deploy-backstage.sh deploy kubectl
```

### Método 2: Manual
```bash
# Aplicar manifiestos en orden
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment.yaml
kubectl apply -f ingress.yaml
kubectl apply -f networkpolicy.yaml

# HPA es opcional
kubectl apply -f hpa.yaml
```

## Verificación

### Verificar Recursos
```bash
# Ver todos los recursos
kubectl get all -n backstage-demo

# Ver configuración
kubectl get configmap,secret -n backstage-demo

# Ver ingress
kubectl get ingress -n backstage-demo
```

### Verificar Conectividad
```bash
# Health check
kubectl exec -n backstage-demo deployment/backstage -- \
  curl -f http://localhost:7007/api/catalog/health

# Logs
kubectl logs -f deployment/backstage -n backstage-demo
```

## Personalización

### 1. Modificar Configuración
Editar `configmap.yaml` para cambiar:
- URL base de Backstage
- Configuración de plugins
- Integración con servicios externos

### 2. Ajustar Recursos
Editar `deployment.yaml` para modificar:
- Límites de CPU/memoria
- Número de réplicas
- Variables de entorno

### 3. Configurar Ingress
Editar `ingress.yaml` para:
- Cambiar rutas de acceso
- Agregar TLS/SSL
- Modificar annotations de NGINX

### 4. Actualizar Secrets
```bash
# Actualizar token de GitHub
kubectl patch secret backstage-secrets -n backstage-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/data/GITHUB_TOKEN", "value": "'$(echo -n "nuevo-token" | base64 -w 0)'"}]'

# Reiniciar deployment
kubectl rollout restart deployment/backstage -n backstage-demo
```

## Troubleshooting

### Problemas Comunes

#### 1. Pod en CrashLoopBackOff
```bash
# Ver logs detallados
kubectl logs deployment/backstage -n backstage-demo --previous

# Verificar configuración
kubectl describe deployment backstage -n backstage-demo
```

#### 2. Error de Conexión a Base de Datos
```bash
# Verificar PostgreSQL
kubectl get pods -n backstage-demo -l app=postgresql

# Probar conectividad
kubectl exec -n backstage-demo deployment/backstage -- \
  nc -zv postgresql 5432
```

#### 3. Ingress No Funciona
```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx

# Ver configuración de ingress
kubectl describe ingress backstage-ingress -n backstage-demo
```

### Comandos de Diagnóstico
```bash
# Estado general
kubectl get events -n backstage-demo --sort-by='.lastTimestamp'

# Recursos del nodo
kubectl describe nodes

# Configuración de red
kubectl get networkpolicy -n backstage-demo -o yaml
```

## Optimizaciones para Minikube

### 1. Recursos Limitados
- CPU request: 100m (mínimo)
- Memory request: 256Mi (mínimo)
- CPU limit: 500m (máximo para demo)
- Memory limit: 512Mi (máximo para demo)

### 2. Almacenamiento
- Usa volúmenes emptyDir para temporales
- PVC mínimo para PostgreSQL (1-2Gi)

### 3. Red
- Network policies permisivas para facilitar demo
- Ingress con configuración simple
- Service discovery interno

## Seguridad

### 1. Configuración de Seguridad
- Usuario no-root (UID 1001)
- Capabilities restringidas
- Read-only root filesystem donde sea posible
- Security context estricto

### 2. Secrets Management
- Secrets codificados en base64
- Rotación manual de tokens
- Variables de entorno para credenciales

### 3. Network Security
- Network policies para controlar tráfico
- Ingress con rate limiting
- CORS configurado apropiadamente

## Monitoreo

### 1. Health Checks
- Liveness probe: `/api/catalog/health`
- Readiness probe: `/api/catalog/health`
- Timeouts optimizados para Minikube

### 2. Logs
```bash
# Logs en tiempo real
kubectl logs -f deployment/backstage -n backstage-demo

# Logs de todos los containers
kubectl logs -f deployment/backstage -n backstage-demo --all-containers
```

### 3. Métricas
```bash
# Uso de recursos
kubectl top pods -n backstage-demo

# Eventos del sistema
kubectl get events -n backstage-demo -w
```

## Limpieza

### Eliminar Recursos
```bash
# Eliminar todos los recursos
kubectl delete -f .

# O eliminar namespace completo
kubectl delete namespace backstage-demo
```

### Verificar Limpieza
```bash
# Verificar que no queden recursos
kubectl get all -n backstage-demo
kubectl get pv | grep backstage-demo
```

## Referencias

- [Backstage Kubernetes Plugin](https://backstage.io/docs/features/kubernetes/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
