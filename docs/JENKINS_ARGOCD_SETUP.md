# Configuración de Jenkins + ArgoCD para CI/CD Automático

Este documento describe cómo configurar un pipeline de CI/CD que detecta automáticamente cambios en endpoints y despliega actualizaciones sin intervención manual.

## 🏗️ Arquitectura

```
GitHub Push → Jenkins Pipeline → Docker Registry → ArgoCD → Kubernetes
     ↓              ↓                ↓              ↓           ↓
  Webhook    Detecta cambios    Build & Push    Auto Sync   Deploy
```

## 📋 Prerrequisitos

### 1. Jenkins

- Jenkins instalado y funcionando
- Plugin `GitHub` instalado
- Plugin `Docker Pipeline` instalado
- Plugin `Kubernetes` instalado (opcional, para verificación)
- Acceso a Docker Registry (GitHub Container Registry)

### 2. ArgoCD

- ArgoCD instalado en el cluster
- Application `pedido-app` configurada
- Sincronización automática habilitada

### 3. Kubernetes

- Cluster de Kubernetes funcionando
- Namespace `my-tech` creado
- Acceso desde Jenkins al cluster

## 🔧 Configuración Paso a Paso

### 1. Configurar Credenciales en Jenkins

1. Ve a **Jenkins > Manage Jenkins > Manage Credentials**
2. Agrega las siguientes credenciales:

#### GitHub Token

- **Tipo**: Secret text
- **ID**: `github-token`
- **Secret**: Tu GitHub Personal Access Token

#### Docker Registry

- **Tipo**: Username with password
- **ID**: `docker-registry`
- **Username**: Tu usuario de GitHub
- **Password**: GitHub Personal Access Token

### 2. Configurar Webhook de GitHub

Ejecuta el script de configuración:

```bash
# Hacer ejecutable
chmod +x scripts/setup-github-webhook.sh

# Configurar variables de entorno
export JENKINS_URL="http://tu-jenkins-url:8080"
export GITHUB_REPO="cristianb96/kubernetes_project"
export GITHUB_TOKEN="tu_github_token"

# Ejecutar script
./scripts/setup-github-webhook.sh
```

### 3. Crear Job de Jenkins

1. **Nuevo Item > Pipeline**
2. **Nombre**: `pedido-app-cicd`
3. **Pipeline > Definition**: Pipeline script from SCM
4. **SCM**: Git
5. **Repository URL**: `https://github.com/cristianb96/kubernetes_project.git`
6. **Branch**: `main`
7. **Script Path**: `Jenkinsfile`

#### Configuración de Triggers

- ✅ **GitHub hook trigger for GITScm polling**
- ✅ **Build when a change is pushed to GitHub**

### 4. Verificar Configuración de ArgoCD

Asegúrate de que tu `environments/prod/application.yaml` tenga:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pedido-app
  namespace: argocd
spec:
  project: my-tech
  source:
    repoURL: https://github.com/cristianb96/kubernetes_project.git
    targetRevision: main
    path: charts/pedido-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-tech
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Replace=true
```

## 🚀 Flujo de Trabajo

### Cuando se hace un push al repositorio:

1. **GitHub Webhook** → Notifica a Jenkins
2. **Jenkins Pipeline** ejecuta:
   - ✅ Detecta cambios en `backend/` o archivos `.py`
   - ✅ Build de nueva imagen Docker
   - ✅ Push a GitHub Container Registry
   - ✅ Actualiza `values.yaml` con nuevo tag
   - ✅ Commit y push de cambios
   - ✅ ArgoCD detecta cambios automáticamente
   - ✅ ArgoCD sincroniza y despliega
   - ✅ Verificación del deployment

### Comandos de Verificación

```bash
# Verificar estado de ArgoCD
kubectl get application pedido-app -n argocd

# Verificar pods
kubectl get pods -l app.kubernetes.io/name=backend -n my-tech

# Verificar deployment
kubectl get deployment backend -n my-tech

# Ejecutar script de verificación completo
chmod +x scripts/verify-argocd-sync.sh
./scripts/verify-argocd-sync.sh
```

## 🔍 Monitoreo y Troubleshooting

### Logs de Jenkins

- Ve a tu job de Jenkins
- Click en el build específico
- Revisa la consola de output

### Logs de ArgoCD

```bash
# Ver logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Ver estado detallado de la aplicación
kubectl describe application pedido-app -n argocd
```

### Logs de la Aplicación

```bash
# Ver logs de los pods
kubectl logs -l app.kubernetes.io/name=backend -n my-tech

# Ver eventos del namespace
kubectl get events -n my-tech --sort-by='.lastTimestamp'
```

## 🧪 Pruebas

### 1. Agregar un nuevo endpoint

Edita `backend/main.py`:

```python
@app.get("/api/test")
def test():
    return {"message": "Nuevo endpoint de prueba"}
```

Haz commit y push:

```bash
git add backend/main.py
git commit -m "feat: add new test endpoint"
git push origin main
```

### 2. Verificar el pipeline

1. Ve a Jenkins y verifica que el job se ejecute automáticamente
2. Revisa los logs del pipeline
3. Verifica que ArgoCD sincronice automáticamente
4. Prueba el nuevo endpoint

### 3. Eliminar un endpoint

Edita `backend/main.py` y elimina un endpoint, luego haz commit y push.

## 📊 Beneficios de esta Configuración

- ✅ **Detección automática** de cambios en endpoints
- ✅ **Build automático** de imágenes Docker
- ✅ **Actualización automática** de tags en Helm
- ✅ **Despliegue automático** con ArgoCD
- ✅ **Verificación automática** del deployment
- ✅ **Sin comandos manuales** necesarios
- ✅ **Trazabilidad completa** del proceso

## 🔧 Personalización

### Cambiar Registry de Docker

Edita en `Jenkinsfile`:

```groovy
environment {
  REGISTRY = "tu-registry.com"
  IMAGE = "${REGISTRY}/tu-imagen"
}
```

### Cambiar Namespace de Kubernetes

Edita en `Jenkinsfile`:

```groovy
environment {
  ARGOCD_NAMESPACE = "argocd"
  NAMESPACE = "tu-namespace"
}
```

### Agregar más verificaciones

Edita la sección `Verify Deployment` en `Jenkinsfile` para agregar más checks.

## 🆘 Solución de Problemas Comunes

### Pipeline no se ejecuta automáticamente

- Verifica que el webhook esté configurado correctamente
- Revisa los logs de GitHub webhooks
- Verifica que Jenkins tenga el plugin GitHub instalado

### ArgoCD no sincroniza

- Verifica que la aplicación esté configurada correctamente
- Revisa los logs de ArgoCD
- Verifica que el repositorio sea accesible

### Build falla

- Verifica las credenciales de Docker Registry
- Revisa que Docker esté instalado en Jenkins
- Verifica que el Dockerfile sea correcto

### Deployment falla

- Revisa los logs de los pods
- Verifica que los recursos estén disponibles
- Revisa la configuración de Helm values
