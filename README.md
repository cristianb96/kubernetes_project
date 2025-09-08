# Pedido App (Helm + ArgoCD)

Este repositorio contiene:
- **charts/pedido-app**: Chart de Helm *umbrella* con dos subcharts:
  - `db` → dependencia de Bitnami PostgreSQL.
  - `backend` → Deployment/Service/Ingress/ConfigMap/Secret para el backend en Python.
- **environments/prod**: Manifiestos de ArgoCD (`AppProject` y `Application`) para el entorno `my-tech`.
- **sample-backend**: Ejemplo mínimo de backend en FastAPI y su `Dockerfile`.
- **Jenkinsfile**: Pipeline de ejemplo que construye/pushea la imagen y actualiza el `values.yaml`.

> Requisitos previos: `kubectl`, `helm` v3, un clúster Kubernetes, **ArgoCD** instalado, y un **Ingress Controller** (por ejemplo NGINX).

## Paso a paso (local / prueba rápida con Helm)

1. Añade el repo de Bitnami y prepara dependencias:
   ```bash
   cd charts/pedido-app
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm dependency build
   ```

2. (Opcional) Construye y publica tu imagen del backend:
   ```bash
   cd ../../backend
   docker build -t YOUR_REGISTRY/pedido-backend:v0.1.0 .
   docker push YOUR_REGISTRY/pedido-backend:v0.1.0
   ```

3. Ajusta `charts/pedido-app/values.yaml` con tu `image.repository`, `image.tag`, host de Ingress, recursos, etc.

4. Instala en tu clúster para pruebas (namespace `my-tech`):
   ```bash
   kubectl create namespace my-tech || true
   helm install pedido charts/pedido-app -n my-tech
   kubectl get pods -n my-tech
   kubectl get svc,ing -n my-tech
   ```

5. Si usas NGINX Ingress Controller y definiste un host DNS (ej: `my-tech.local`), accede a `http(s)://my-tech.local/api/health`.

## GitOps con ArgoCD

1. Sube este repo a tu Git (GitHub/GitLab/etc.).

2. Aplica los manifiestos (ajusta `repoURL` en `environments/prod/application.yaml`):
   ```bash
   kubectl apply -n argocd -f environments/prod/appproject.yaml
   kubectl apply -n argocd -f environments/prod/application.yaml
   ```

3. ArgoCD sincronizará automáticamente (tiene `syncPolicy.automated`). Cada cambio en `charts/pedido-app/values.yaml` (por ejemplo cambiando `backend.image.tag`) provocará una nueva sincronización.

## Jenkins (ejemplo)
El `Jenkinsfile` crea una imagen con tag del `GIT_COMMIT`, actualiza `charts/pedido-app/values.yaml` y hace `git push`. ArgoCD detectará el cambio y desplegará.

## Notas sobre PostgreSQL (Bitnami)
- Creamos el servicio de PostgreSQL con `fullnameOverride: db`. El nombre DNS interno por defecto será `db-postgresql` en el mismo namespace.
- El PVC lo gestiona el subchart de Bitnami a través de `db.primary.persistence.*`.
- Si necesitas otro tamaño de PVC o StorageClass, ajusta `db.primary.persistence.size` y `db.primary.persistence.storageClass` en `values.yaml`.
