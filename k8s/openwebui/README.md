# OpenWebUI Kubernetes Manifests

Manifiestos de Kubernetes para desplegar OpenWebUI optimizado para demo en Minikube con integración Backstage.

## Descripción General

Este directorio contiene todos los manifiestos de Kubernetes necesarios para desplegar OpenWebUI:

- **Namespace**: Aislamiento de recursos
- **ServiceAccount & RBAC**: Permisos mínimos necesarios
- **ConfigMaps**: Configuración de aplicación
- **Secrets**: Credenciales y tokens
- **Deployment**: Aplicación principal con sidecars
- **Services**: Exposición de servicios
- **Ingress**: Acceso externo
- **PVCs**: Almacenamiento persistente
- **HPA**: Auto-escalado horizontal
- **NetworkPolicy**: Seguridad de red

## Estructura de Archivos

```
k8s/openwebui/
├── namespace.yaml          # Namespace para OpenWebUI
├── serviceaccount.yaml     # ServiceAccount y RBAC
├── configmap.yaml         # Configuración de aplicación
├── secret.yaml            # Secrets para credenciales
├── pvc.yaml              # Persistent Volume Claims
├── deployment.yaml        # Deployment principal
├── service.yaml          # Servicios (ClusterIP, Headless, API)
├── ingress.yaml          # Ingress para acceso externo
├── hpa.yaml              # Horizontal Pod Autoscaler
├── networkpolicy.yaml    # Network Policies
└── README.md             # Esta documentación
```

## Recursos Creados

### Core Resources

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| **Namespace** | `openwebui-demo` | Namespace para todos los recursos |
| **ServiceAccount** | `openwebui` | Cuenta de servicio con permisos mínimos |
| **Deployment** | `openwebui` | Aplicación principal con 1 replica |
| **Service** | `openwebui` | Servicio principal (ClusterIP:8080) |
| **Ingress** | `openwebui-ingress` | Acceso externo via nginx |

### Storage Resources

| Recurso | Nombre | Tamaño | Descripción |
|---------|--------|--------|-------------|
| **PVC** | `openwebui-data` | 2Gi | Datos de aplicación |
| **PVC** | `openwebui-models` | 1Gi | Modelos AI |

### Configuration Resources

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| **ConfigMap** | `openwebui-config` | Configuración principal |
| **ConfigMap** | `openwebui-models` | Configuración de modelos |
| **Secret** | `openwebui-secrets` | JWT, API keys |
| **Secret** | `openwebui-db-secrets` | Credenciales DB |
| **Secret** | `openwebui-admin-secrets` | Credenciales admin |

### Security & Networking

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| **Role** | `openwebui-role` | Permisos en namespace |
| **RoleBinding** | `openwebui-rolebinding` | Vinculación de permisos |
| **ClusterRole** | `openwebui-cross-namespace` | Acceso cross-namespace |
| **NetworkPolicy** | `openwebui-network-policy` | Políticas de red |

### Scaling & Monitoring

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| **HPA** | `openwebui-hpa` | Auto-escalado (1-2 replicas) |

## Configuración de Recursos

### Deployment Configuration

```yaml
# Recursos optimizados para Minikube
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

# Init containers
initContainers:
  - wait-for-db      # Espera PostgreSQL
  - init-data        # Inicializa directorios

# Sidecars
containers:
  - openwebui        # Aplicación principal
  - nginx-proxy      # Proxy reverso
```

### Service Configuration

```yaml
# Servicio principal
apiVersion: v1
kind: Service
metadata:
  name: openwebui
spec:
  type: ClusterIP
  ports:
    - port: 8080      # Aplicación
    - port: 80        # Proxy
```

### Ingress Configuration

```yaml
# Acceso externo
spec:
  rules:
    - host: openwebui.local
      http:
        paths:
          - path: /
            backend:
              service:
                name: openwebui
                port:
                  number: 80
```

## Despliegue

### Método 1: Script Automatizado

```bash
# Usar script de despliegue
../scripts/deploy-openwebui.sh --method kubectl

# Con opciones específicas
../scripts/deploy-openwebui.sh \
  --method kubectl \
  --namespace openwebui-demo \
  --dry-run
```

### Método 2: kubectl Directo

```bash
# Aplicar todos los manifiestos
kubectl apply -f .

# Aplicar en orden específico
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f networkpolicy.yaml
```

### Método 3: Kustomize

```bash
# Crear kustomization.yaml
cat > kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - configmap.yaml
  - secret.yaml
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - networkpolicy.yaml

namespace: openwebui-demo
EOF

# Aplicar con kustomize
kubectl apply -k .
```

## Verificación del Despliegue

### Verificar Recursos

```bash
# Verificar todos los recursos
kubectl get all -n openwebui-demo

# Verificar pods específicamente
kubectl get pods -n openwebui-demo -l app.kubernetes.io/name=openwebui

# Verificar servicios
kubectl get svc -n openwebui-demo

# Verificar ingress
kubectl get ingress -n openwebui-demo

# Verificar PVCs
kubectl get pvc -n openwebui-demo
```

### Verificar Estado

```bash
# Estado del deployment
kubectl rollout status deployment/openwebui -n openwebui-demo

# Logs de la aplicación
kubectl logs -n openwebui-demo deployment/openwebui -f

# Describir pod para troubleshooting
kubectl describe pod -n openwebui-demo -l app.kubernetes.io/name=openwebui
```

### Health Checks

```bash
# Health check directo
kubectl exec -n openwebui-demo deployment/openwebui -- \
  curl -f http://localhost:8080/health

# Port forward para testing
kubectl port-forward -n openwebui-demo service/openwebui 8080:8080
curl http://localhost:8080/health
```

## Configuración Post-Despliegue

### Acceso a la Aplicación

```bash
# Método 1: Port Forward
kubectl port-forward -n openwebui-demo service/openwebui 8080:8080
# Acceder: http://localhost:8080

# Método 2: Ingress (agregar a /etc/hosts)
echo "$(minikube ip) openwebui.local" | sudo tee -a /etc/hosts
# Acceder: http://openwebui.local
```

### Credenciales por Defecto

```bash
# Obtener credenciales desde secrets
kubectl get secret -n openwebui-demo openwebui-admin-secrets -o jsonpath='{.data.ADMIN_EMAIL}' | base64 -d
kubectl get secret -n openwebui-demo openwebui-admin-secrets -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d

# Credenciales por defecto:
# Email: demo@example.com
# Password: demo123
```

## Personalización

### Variables de Entorno

Editar `configmap.yaml` para personalizar la configuración:

```yaml
data:
  config.yaml: |
    app:
      name: "Mi OpenWebUI Personalizado"
    features:
      chat: true
      fileUpload: true
      codeExecution: false
```

### Recursos

Editar `deployment.yaml` para ajustar recursos:

```yaml
resources:
  limits:
    cpu: 1000m      # Aumentar CPU
    memory: 1Gi     # Aumentar memoria
  requests:
    cpu: 200m
    memory: 512Mi
```

### Almacenamiento

Editar `pvc.yaml` para ajustar almacenamiento:

```yaml
spec:
  resources:
    requests:
      storage: 5Gi  # Aumentar almacenamiento
```

### Ingress

Editar `ingress.yaml` para personalizar acceso:

```yaml
spec:
  rules:
    - host: mi-openwebui.local  # Cambiar hostname
      http:
        paths:
          - path: /
            pathType: Prefix
```

## Troubleshooting

### Problemas Comunes

#### 1. Pod en Pending

```bash
# Verificar eventos
kubectl describe pod -n openwebui-demo <pod-name>

# Posibles causas:
# - PVC no puede ser montado
# - Recursos insuficientes
# - Node selector no coincide
```

#### 2. ImagePullBackOff

```bash
# Verificar imagen
kubectl describe pod -n openwebui-demo <pod-name>

# Verificar si la imagen existe
docker pull edissonz8809/iaops/openwebui:demo-latest
```

#### 3. CrashLoopBackOff

```bash
# Verificar logs
kubectl logs -n openwebui-demo <pod-name> --previous

# Verificar configuración
kubectl get configmap -n openwebui-demo openwebui-config -o yaml
```

#### 4. Servicio no accesible

```bash
# Verificar endpoints
kubectl get endpoints -n openwebui-demo openwebui

# Verificar labels
kubectl get pods -n openwebui-demo --show-labels
```

### Comandos de Diagnóstico

```bash
# Estado general
kubectl get all -n openwebui-demo

# Eventos recientes
kubectl get events -n openwebui-demo --sort-by='.lastTimestamp'

# Logs de todos los containers
kubectl logs -n openwebui-demo deployment/openwebui --all-containers=true

# Descripción completa del deployment
kubectl describe deployment -n openwebui-demo openwebui

# Verificar network policies
kubectl describe networkpolicy -n openwebui-demo
```

## Limpieza

### Eliminar Recursos

```bash
# Eliminar todos los recursos
kubectl delete -f .

# Eliminar namespace completo
kubectl delete namespace openwebui-demo

# Eliminar recursos específicos
kubectl delete deployment,service,ingress -n openwebui-demo -l app.kubernetes.io/name=openwebui
```

### Limpiar Almacenamiento

```bash
# Eliminar PVCs (datos se perderán)
kubectl delete pvc -n openwebui-demo --all

# Verificar PVs huérfanos
kubectl get pv | grep Released
```

## Integración con Backstage

### Network Connectivity

Los manifiestos incluyen configuración para comunicación con Backstage:

```yaml
# En networkpolicy.yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            name: backstage-demo
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            name: backstage-demo
```

### Service Discovery

```yaml
# En configmap.yaml
integrations:
  backstage:
    enabled: true
    base_url: "http://backstage.backstage-demo.svc.cluster.local:7007"
```

## Monitoreo

### Métricas

```bash
# Métricas de pods
kubectl top pods -n openwebui-demo

# Estado del HPA
kubectl get hpa -n openwebui-demo

# Uso de almacenamiento
kubectl exec -n openwebui-demo deployment/openwebui -- df -h /app/data
```

### Logs

```bash
# Logs en tiempo real
kubectl logs -n openwebui-demo deployment/openwebui -f

# Logs del sidecar nginx
kubectl logs -n openwebui-demo deployment/openwebui -c nginx-proxy -f

# Logs estructurados
kubectl logs -n openwebui-demo deployment/openwebui | jq .
```

## Mejores Prácticas

### Seguridad

- ✅ Usar usuarios no-root (UID 1001)
- ✅ Configurar network policies restrictivas
- ✅ Limitar capabilities del container
- ✅ Usar secrets para credenciales sensibles
- ✅ Configurar RBAC con permisos mínimos

### Performance

- ✅ Configurar resource requests y limits
- ✅ Usar health checks apropiados
- ✅ Configurar HPA para escalado automático
- ✅ Usar persistent storage para datos importantes

### Mantenimiento

- ✅ Usar labels consistentes
- ✅ Documentar configuraciones personalizadas
- ✅ Implementar backup de datos
- ✅ Monitorear recursos y logs

## Referencias

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [OpenWebUI GitHub](https://github.com/open-webui/open-webui)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

**Nota**: Estos manifiestos están optimizados para demo en Minikube. Para producción, revisar configuraciones de seguridad, recursos y alta disponibilidad.
