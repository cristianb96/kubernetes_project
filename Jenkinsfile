pipeline {
  agent any
  environment {
    REGISTRY = "YOUR_REGISTRY"
    IMAGE = "${REGISTRY}/pedido-backend"
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git config user.email "ci@example.com"; git config user.name "jenkins-ci"'
      }
    }
    stage('Build & Push Image') {
      steps {
        dir('sample-backend') {
          sh 'docker build -t ${IMAGE}:${GIT_COMMIT} .'
          sh 'docker push ${IMAGE}:${GIT_COMMIT}'
        }
      }
    }
    stage('Bump values.yaml') {
      steps {
        sh '''
          yq -i '.backend.image.repository = strenv(IMAGE)' charts/pedido-app/values.yaml
          yq -i '.backend.image.tag = strenv(GIT_COMMIT)' charts/pedido-app/values.yaml
        '''
      }
    }
    stage('Commit & Push') {
      steps {
        sh '''
          git add charts/pedido-app/values.yaml
          git commit -m "ci: bump backend image to ${IMAGE}:${GIT_COMMIT}"
          git push origin HEAD:main
        '''
      }
    }
  }
}
