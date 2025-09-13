pipeline {
  agent any
  environment {
    REGISTRY = "ghcr.io/cristianb96"
    IMAGE = "${REGISTRY}/kubernetes_project-backend"
    ARGOCD_APP = "pedido-app"
    ARGOCD_NAMESPACE = "argocd"
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git config user.email "ci@example.com"; git config user.name "jenkins-ci"'
      }
    }
    
    stage('Detect Changes') {
      steps {
        script {
          // Detectar cambios en el backend
          def backendChanges = sh(
            script: 'git diff --name-only HEAD~1 HEAD | grep -E "^backend/" || true',
            returnStdout: true
          ).trim()
          
          // Detectar cambios en endpoints específicamente
          def endpointChanges = sh(
            script: 'git diff --name-only HEAD~1 HEAD | grep -E "^backend/.*\\.py$" || true',
            returnStdout: true
          ).trim()
          
          env.BACKEND_CHANGED = backendChanges ? 'true' : 'false'
          env.ENDPOINT_CHANGED = endpointChanges ? 'true' : 'false'
          
          echo "Backend changes detected: ${env.BACKEND_CHANGED}"
          echo "Endpoint changes detected: ${env.ENDPOINT_CHANGED}"
          echo "Changed files: ${backendChanges}"
        }
      }
    }
    
    stage('Build & Push Image') {
      when {
        anyOf {
          expression { env.BACKEND_CHANGED == 'true' }
          expression { env.ENDPOINT_CHANGED == 'true' }
        }
      }
      steps {
        script {
          def imageTag = "${GIT_COMMIT}"
          def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          
          dir('backend') {
            sh """
              docker build -t ${IMAGE}:${imageTag} .
              docker build -t ${IMAGE}:${shortCommit} .
              docker build -t ${IMAGE}:latest .
            """
            
            sh """
              docker push ${IMAGE}:${imageTag}
              docker push ${IMAGE}:${shortCommit}
              docker push ${IMAGE}:latest
            """
          }
          
          env.NEW_IMAGE_TAG = imageTag
          env.NEW_IMAGE_SHORT = shortCommit
        }
      }
    }
    
    stage('Update Helm Values') {
      when {
        anyOf {
          expression { env.BACKEND_CHANGED == 'true' }
          expression { env.ENDPOINT_CHANGED == 'true' }
        }
      }
      steps {
        script {
          def imageTag = env.NEW_IMAGE_TAG ?: env.GIT_COMMIT
          def shortCommit = env.NEW_IMAGE_SHORT ?: sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          
          // Actualizar values.yaml principal
          sh """
            yq -i '.backend.image.repository = "${env.IMAGE}"' charts/pedido-app/values.yaml
            yq -i '.backend.image.tag = "${imageTag}"' charts/pedido-app/values.yaml
          """
          
          // Actualizar values.yaml del subchart
          sh """
            yq -i '.image.repository = "${env.IMAGE}"' charts/pedido-app/charts/backend/values.yaml
            yq -i '.image.tag = "${imageTag}"' charts/pedido-app/charts/backend/values.yaml
          """
          
          echo "Updated image to: ${env.IMAGE}:${imageTag}"
        }
      }
    }
    
    stage('Commit & Push Changes') {
      when {
        anyOf {
          expression { env.BACKEND_CHANGED == 'true' }
          expression { env.ENDPOINT_CHANGED == 'true' }
        }
      }
      steps {
        script {
          def commitMessage = ""
          if (env.ENDPOINT_CHANGED == 'true') {
            commitMessage = "ci: update image after endpoint changes - ${env.NEW_IMAGE_TAG}"
          } else {
            commitMessage = "ci: update image after backend changes - ${env.NEW_IMAGE_TAG}"
          }
          
          sh """
            git add charts/pedido-app/values.yaml charts/pedido-app/charts/backend/values.yaml
            git commit -m "${commitMessage}"
            git push origin HEAD:main
          """
        }
      }
    }
    
    stage('Trigger ArgoCD Sync') {
      when {
        anyOf {
          expression { env.BACKEND_CHANGED == 'true' }
          expression { env.ENDPOINT_CHANGED == 'true' }
        }
      }
      steps {
        script {
          // Esperar un momento para que ArgoCD detecte los cambios
          sh 'sleep 10'
          
          // Verificar si ArgoCD está disponible
          sh """
            kubectl get application ${ARGOCD_APP} -n ${ARGOCD_NAMESPACE} || echo "ArgoCD application not found"
          """
          
          // ArgoCD debería sincronizar automáticamente debido a la configuración automated
          echo "ArgoCD debería sincronizar automáticamente en los próximos minutos"
          echo "Puedes verificar el estado en: kubectl get application ${ARGOCD_APP} -n ${ARGOCD_NAMESPACE}"
        }
      }
    }
    
    stage('Verify Deployment') {
      when {
        anyOf {
          expression { env.BACKEND_CHANGED == 'true' }
          expression { env.ENDPOINT_CHANGED == 'true' }
        }
      }
      steps {
        script {
          // Esperar a que el deployment se complete
          sh 'sleep 30'
          
          // Verificar el estado del deployment
          sh """
            kubectl get pods -l app.kubernetes.io/name=backend -n my-tech
            kubectl get deployment backend -n my-tech
          """
          
          echo "Deployment verification completed"
          echo "Nueva imagen desplegada: ${env.IMAGE}:${env.NEW_IMAGE_TAG}"
        }
      }
    }
  }
  
  post {
    always {
      echo "Pipeline execution completed"
      echo "Backend changes: ${env.BACKEND_CHANGED}"
      echo "Endpoint changes: ${env.ENDPOINT_CHANGED}"
    }
    success {
      echo "✅ Pipeline ejecutado exitosamente"
      echo "🚀 Nueva imagen desplegada automáticamente"
    }
    failure {
      echo "❌ Pipeline falló"
    }
  }
}
