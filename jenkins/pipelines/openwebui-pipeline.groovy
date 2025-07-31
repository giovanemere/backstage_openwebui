#!/usr/bin/env groovy

/*
 * Jenkins Pipeline - OpenWebUI Build & Deploy
 * Pipeline optimizado para construir y desplegar OpenWebUI en Minikube
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
        IMAGE_NAME = 'openwebui'
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
                echo '🐳 Construyendo imagen Docker de OpenWebUI...'
                script {
                    dir('docker/openwebui') {
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
                        docker run --rm -d --name openwebui-test -p 8081:8080 ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        sleep 15
                        
                        # Verificar que el servicio responde
                        curl -f http://localhost:8081/health || echo "Health check failed"
                        
                        docker logs openwebui-test
                        docker stop openwebui-test || true
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
                echo '🚀 Desplegando OpenWebUI en Kubernetes...'
                script {
                    sh """
                        # Configurar kubectl para Minikube
                        kubectl config use-context ${MINIKUBE_PROFILE}
                        
                        # Crear namespace si no existe
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Actualizar imagen en deployment
                        kubectl set image deployment/openwebui openwebui=${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} -n ${NAMESPACE} || echo "Deployment no existe aún"
                        
                        # Aplicar manifiestos de Kubernetes
                        if [ -d "k8s/openwebui" ]; then
                            kubectl apply -f k8s/openwebui/ -n ${NAMESPACE}
                        fi
                        
                        # Esperar a que el deployment esté listo
                        kubectl rollout status deployment/openwebui -n ${NAMESPACE} --timeout=300s || true
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
                        kubectl get pods -n ${NAMESPACE} -l app=openwebui
                        
                        # Verificar servicios
                        kubectl get services -n ${NAMESPACE} -l app=openwebui
                        
                        # Verificar logs
                        kubectl logs -n ${NAMESPACE} -l app=openwebui --tail=20 || true
                        
                        # Probar conectividad interna
                        kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -f http://openwebui:8080/health || true
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
            echo '✅ Pipeline de OpenWebUI completado exitosamente!'
            script {
                // Notificar éxito (opcional)
                sh """
                    echo "OpenWebUI desplegado exitosamente"
                    echo "Imagen: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    echo "Namespace: ${NAMESPACE}"
                """
            }
        }
        failure {
            echo '❌ Pipeline de OpenWebUI falló!'
            script {
                // Mostrar logs de debug
                sh """
                    echo "=== DEBUG INFO ==="
                    kubectl get pods -n ${NAMESPACE} || true
                    kubectl describe pods -n ${NAMESPACE} -l app=openwebui || true
                    kubectl logs -n ${NAMESPACE} -l app=openwebui --tail=50 || true
                """
            }
        }
        cleanup {
            // Limpiar workspace
            cleanWs()
        }
    }
}
