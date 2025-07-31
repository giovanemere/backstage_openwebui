#!/usr/bin/env groovy

/*
 * Jenkins Pipeline - Backstage Build & Deploy
 * Pipeline optimizado para construir y desplegar Backstage en Minikube
 */

pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
            defaultContainer 'jnlp'
        }
    }
    
    environment {
        DOCKER_REGISTRY = 'edissonz8809/iaops'
        IMAGE_NAME = 'backstage'
        IMAGE_TAG = "${BUILD_NUMBER}-demo"
        MINIKUBE_PROFILE = 'backstage-demo'
        NAMESPACE = 'backstage-demo'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '🔄 Clonando repositorio...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Construyendo imagen Docker de Backstage...'
                script {
                    dir('docker/backstage') {
                        sh """
                            docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
                            docker tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_REGISTRY}/${IMAGE_NAME}:demo-latest
                        """
                    }
                }
            }
        }
        
        stage('Test Image') {
            steps {
                echo '🧪 Probando imagen Docker...'
                script {
                    sh """
                        # Probar que la imagen se ejecuta correctamente
                        docker run --rm -d --name backstage-test ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        sleep 10
                        docker logs backstage-test
                        docker stop backstage-test || true
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                echo '📤 Subiendo imagen a DockerHub...'
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:demo-latest
                    """
                }
            }
        }
        
        stage('Load to Minikube') {
            steps {
                echo '📥 Cargando imagen en Minikube...'
                script {
                    sh """
                        # Cargar imagen en Minikube
                        minikube image load ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} -p ${MINIKUBE_PROFILE}
                        minikube image load ${DOCKER_REGISTRY}/${IMAGE_NAME}:demo-latest -p ${MINIKUBE_PROFILE}
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Desplegando Backstage en Kubernetes...'
                script {
                    sh """
                        # Configurar kubectl para Minikube
                        kubectl config use-context ${MINIKUBE_PROFILE}
                        
                        # Crear namespace si no existe
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Actualizar imagen en deployment
                        kubectl set image deployment/backstage backstage=${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} -n ${NAMESPACE} || echo "Deployment no existe aún"
                        
                        # Aplicar manifiestos de Kubernetes
                        if [ -d "k8s/backstage" ]; then
                            kubectl apply -f k8s/backstage/ -n ${NAMESPACE}
                        fi
                        
                        # Esperar a que el deployment esté listo
                        kubectl rollout status deployment/backstage -n ${NAMESPACE} --timeout=300s || true
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo '✅ Verificando despliegue...'
                script {
                    sh """
                        # Verificar pods
                        kubectl get pods -n ${NAMESPACE} -l app=backstage
                        
                        # Verificar servicios
                        kubectl get services -n ${NAMESPACE} -l app=backstage
                        
                        # Verificar logs
                        kubectl logs -n ${NAMESPACE} -l app=backstage --tail=20 || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Limpiando recursos...'
            script {
                // Limpiar imágenes locales para ahorrar espacio
                sh """
                    docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                    docker system prune -f || true
                """
            }
        }
        success {
            echo '✅ Pipeline de Backstage completado exitosamente!'
            script {
                // Notificar éxito (opcional)
                sh """
                    echo "Backstage desplegado exitosamente"
                    echo "Imagen: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    echo "Namespace: ${NAMESPACE}"
                """
            }
        }
        failure {
            echo '❌ Pipeline de Backstage falló!'
            script {
                // Mostrar logs de debug
                sh """
                    echo "=== DEBUG INFO ==="
                    kubectl get pods -n ${NAMESPACE} || true
                    kubectl describe pods -n ${NAMESPACE} -l app=backstage || true
                    kubectl logs -n ${NAMESPACE} -l app=backstage --tail=50 || true
                """
            }
        }
        cleanup {
            // Limpiar workspace
            cleanWs()
        }
    }
}
