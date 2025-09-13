# Pedido App - CI/CD Automático con Jenkins + ArgoCD

Este repositorio implementa un flujo completo de CI/CD que detecta automáticamente cambios en endpoints y despliega actualizaciones sin intervención manual.

## 🏗️ Arquitectura

```
GitHub Push → Jenkins Pipeline → Docker Registry → ArgoCD → Kubernetes
     ↓              ↓                ↓              ↓           ↓
  Webhook    Detecta cambios    Build & Push    Auto Sync   Deploy
```

## 📁 Estructura del Proyecto

- **charts/pedido-app**: Chart de Helm _umbrella_ con dos subcharts:
  - `db` → dependencia de Bitnami PostgreSQL
  - `backend` → Deployment/Service/Ingress/ConfigMap/Secret para el backend en Python
- **environments/prod**: Manifiestos de ArgoCD (`AppProject` y `Application`) para el entorno `my-tech`
- **backend**: Backend en FastAPI con endpoints de ejemplo
- **Jenkinsfile**: Pipeline inteligente que detecta cambios y despliega automáticamente
- **scripts/**: Scripts de configuración y verificación
- **docs/**: Documentación detallada de configuración

## 🚀 Características Principales

- ✅ **Detección automática** de cambios en endpoints
- ✅ **Build automático** de imágenes Docker
- ✅ **Actualización automática** de tags en Helm
- ✅ **Despliegue automático** con ArgoCD
- ✅ **Verificación automática** del deployment
- ✅ **Sin comandos manuales** necesarios
- ✅ **Trazabilidad completa** del proceso

> Requisitos previos: `kubectl`, `helm` v3, un clúster Kubernetes, **ArgoCD** instalado, **Jenkins** configurado, y un **Ingress Controller** (por ejemplo NGINX).

## Paso a paso (local / prueba rápida con Helm)

1. Añade el repo de Bitnami y prepara dependencias:

   ```bash
   cd charts/pedido-app
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm dependency build
   ```

2. Ajusta `charts/pedido-app/values.yaml` con tu `image.repository`, `image.tag`, host de Ingress, recursos, etc.

3. Instala en tu clúster para pruebas (namespace `my-tech`):

   ```bash
   kubectl create namespace my-tech || true
   helm install pedido charts/pedido-app -n my-tech
   kubectl get pods -n my-tech
   kubectl get svc,ing -n my-tech
   ```
   ```bash
   minikube addons enable ingress
   ```


4. Si usas NGINX Ingress Controller y definiste un host DNS (ej: `my-tech.local`), accede a `http(s)://my-tech.local/api/health`.

## GitOps con ArgoCD

1. Sube este repo a tu Git (GitHub/GitLab/etc.).

2. Aplica los manifiestos (ajusta `repoURL` en `environments/prod/application.yaml`):
    
    ```bash
    kubectl create ns argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.5.8/manifests/install.yaml
    kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d; echo
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```
   ```bash
   kubectl apply -n argocd -f environments/prod/appproject.yaml
   kubectl apply -n argocd -f environments/prod/application.yaml
   ```

3. ArgoCD sincronizará automáticamente (tiene `syncPolicy.automated`). Cada cambio en `charts/pedido-app/values.yaml` (por ejemplo cambiando `backend.image.tag`) provocará una nueva sincronización.

## 🔧 Configuración Rápida

### 1. Configurar Jenkins + ArgoCD

Sigue la guía detallada en [docs/JENKINS_ARGOCD_SETUP.md](docs/JENKINS_ARGOCD_SETUP.md)

### 2. Configurar Webhook de GitHub

```bash
# Hacer ejecutable
chmod +x scripts/setup-github-webhook.sh

# Configurar variables
export JENKINS_URL="http://tu-jenkins-url:8080"
export GITHUB_REPO="cristianb96/kubernetes_project"
export GITHUB_TOKEN="tu_github_token"

# Ejecutar configuración
./scripts/setup-github-webhook.sh
```

### 3. Probar el Flujo Completo

```bash
# Ejecutar script de prueba
./scripts/test-endpoint-changes.sh

# Verificar deployment
./scripts/verify-argocd-sync.sh
```

## 🧪 Cómo Funciona

### Cuando agregas o modificas un endpoint:

1. **Editas** `backend/main.py` (ej: agregar `@app.get("/api/nuevo")`)
2. **Haces commit y push** al repositorio
3. **GitHub webhook** notifica a Jenkins automáticamente
4. **Jenkins detecta** cambios en archivos `.py` del backend
5. **Jenkins construye** nueva imagen Docker con tag único
6. **Jenkins actualiza** `values.yaml` con el nuevo tag
7. **Jenkins hace commit** de los cambios y los envía al repo
8. **ArgoCD detecta** cambios en el repositorio automáticamente
9. **ArgoCD sincroniza** y despliega la nueva versión
10. **Verificación automática** confirma que todo funciona

### Sin comandos manuales necesarios! 🎉

## Notas sobre PostgreSQL (Bitnami)

- Creamos el servicio de PostgreSQL con `fullnameOverride: db`. El nombre DNS interno por defecto será `db-postgresql` en el mismo namespace.
- El PVC lo gestiona el subchart de Bitnami a través de `db.primary.persistence.*`.
- Si necesitas otro tamaño de PVC o StorageClass, ajusta `db.primary.persistence.size` y `db.primary.persistence.storageClass` en `values.yaml`.
