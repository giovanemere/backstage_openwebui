#!/usr/bin/env groovy

/*
 * Jenkins Pipeline - Full Demo Deploy
 * Pipeline completo para desplegar todo el demo Backstage + OpenWebUI
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
        MINIKUBE_PROFILE = 'backstage-demo'
        NAMESPACE = 'backstage-demo'
        BUILD_TAG = "${BUILD_NUMBER}-demo"
    }
    
    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['demo', 'staging', 'production'],
            description: 'Entorno de despliegue'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Omitir pruebas para despliegue rápido'
        )
        booleanParam(
            name: 'CLEAN_DEPLOY',
            defaultValue: false,
            description: 'Limpiar despliegue existente antes de instalar'
        )
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }
    
    stages {
        stage('Preparation') {
            steps {
                echo '🚀 Iniciando despliegue completo del demo...'
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    
                    echo """
                    === CONFIGURACIÓN DEL DESPLIEGUE ===
                    Entorno: ${params.DEPLOY_ENVIRONMENT}
                    Build: ${BUILD_TAG}
                    Commit: ${env.GIT_COMMIT_SHORT}
                    Namespace: ${NAMESPACE}
                    Skip Tests: ${params.SKIP_TESTS}
                    Clean Deploy: ${params.CLEAN_DEPLOY}
                    """
                }
            }
        }
        
        stage('Verify Minikube') {
            steps {
                echo '🔍 Verificando estado de Minikube...'
                script {
                    sh """
                        # Verificar que Minikube esté ejecutándose
                        minikube status -p ${MINIKUBE_PROFILE}
                        
                        # Configurar kubectl
                        kubectl config use-context ${MINIKUBE_PROFILE}
                        
                        # Verificar conectividad
                        kubectl get nodes
                        kubectl get namespaces
                    """
                }
            }
        }
        
        stage('Clean Previous Deployment') {
            when {
                expression { params.CLEAN_DEPLOY }
            }
            steps {
                echo '🧹 Limpiando despliegue anterior...'
                script {
                    sh """
                        # Eliminar recursos existentes
                        kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
                        
                        # Esperar a que el namespace se elimine completamente
                        kubectl wait --for=delete namespace/${NAMESPACE} --timeout=120s || true
                        
                        # Limpiar imágenes de Minikube
                        minikube image rm ${DOCKER_REGISTRY}/backstage:demo-latest -p ${MINIKUBE_PROFILE} || true
                        minikube image rm ${DOCKER_REGISTRY}/openwebui:demo-latest -p ${MINIKUBE_PROFILE} || true
                        minikube image rm ${DOCKER_REGISTRY}/postgresql:demo-latest -p ${MINIKUBE_PROFILE} || true
                    """
                }
            }
        }
        
        stage('Setup Infrastructure') {
            steps {
                echo '🏗️ Configurando infraestructura...'
                script {
                    sh """
                        # Crear namespace
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Aplicar configuraciones base
                        if [ -d "k8s/base" ]; then
                            kubectl apply -f k8s/base/ -n ${NAMESPACE}
                        fi
                        
                        # Configurar secrets y configmaps
                        if [ -d "k8s/configs" ]; then
                            kubectl apply -f k8s/configs/ -n ${NAMESPACE}
                        fi
                    """
                }
            }
        }
        
        stage('Build All Images') {
            parallel {
                stage('Build PostgreSQL') {
                    steps {
                        echo '🐘 Construyendo PostgreSQL...'
                        script {
                            dir('docker/postgresql') {
                                sh """
                                    docker build -t ${DOCKER_REGISTRY}/postgresql:${BUILD_TAG} .
                                    docker tag ${DOCKER_REGISTRY}/postgresql:${BUILD_TAG} ${DOCKER_REGISTRY}/postgresql:demo-latest
                                    minikube image load ${DOCKER_REGISTRY}/postgresql:demo-latest -p ${MINIKUBE_PROFILE}
                                """
                            }
                        }
                    }
                }
                stage('Build Backstage') {
                    steps {
                        echo '🎭 Construyendo Backstage...'
                        script {
                            dir('docker/backstage') {
                                sh """
                                    docker build -t ${DOCKER_REGISTRY}/backstage:${BUILD_TAG} .
                                    docker tag ${DOCKER_REGISTRY}/backstage:${BUILD_TAG} ${DOCKER_REGISTRY}/backstage:demo-latest
                                    minikube image load ${DOCKER_REGISTRY}/backstage:demo-latest -p ${MINIKUBE_PROFILE}
                                """
                            }
                        }
                    }
                }
                stage('Build OpenWebUI') {
                    steps {
                        echo '💬 Construyendo OpenWebUI...'
                        script {
                            dir('docker/openwebui') {
                                sh """
                                    docker build -t ${DOCKER_REGISTRY}/openwebui:${BUILD_TAG} .
                                    docker tag ${DOCKER_REGISTRY}/openwebui:${BUILD_TAG} ${DOCKER_REGISTRY}/openwebui:demo-latest
                                    minikube image load ${DOCKER_REGISTRY}/openwebui:demo-latest -p ${MINIKUBE_PROFILE}
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage('Deploy Database') {
            steps {
                echo '🐘 Desplegando PostgreSQL...'
                script {
                    sh """
                        # Desplegar PostgreSQL
                        if [ -d "k8s/postgresql" ]; then
                            kubectl apply -f k8s/postgresql/ -n ${NAMESPACE}
                        fi
                        
                        # Esperar a que PostgreSQL esté listo
                        kubectl wait --for=condition=ready pod -l app=postgresql -n ${NAMESPACE} --timeout=300s
                        
                        # Verificar conectividad
                        kubectl exec -n ${NAMESPACE} -l app=postgresql -- pg_isready -U postgres || true
                    """
                }
            }
        }
        
        stage('Deploy Applications') {
            parallel {
                stage('Deploy Backstage') {
                    steps {
                        echo '🎭 Desplegando Backstage...'
                        script {
                            sh """
                                # Desplegar Backstage
                                if [ -d "k8s/backstage" ]; then
                                    kubectl apply -f k8s/backstage/ -n ${NAMESPACE}
                                fi
                                
                                # Esperar a que esté listo
                                kubectl rollout status deployment/backstage -n ${NAMESPACE} --timeout=300s
                            """
                        }
                    }
                }
                stage('Deploy OpenWebUI') {
                    steps {
                        echo '💬 Desplegando OpenWebUI...'
                        script {
                            sh """
                                # Desplegar OpenWebUI
                                if [ -d "k8s/openwebui" ]; then
                                    kubectl apply -f k8s/openwebui/ -n ${NAMESPACE}
                                fi
                                
                                # Esperar a que esté listo
                                kubectl rollout status deployment/openwebui -n ${NAMESPACE} --timeout=300s
                            """
                        }
                    }
                }
            }
        }
        
        stage('Configure Ingress') {
            steps {
                echo '🌐 Configurando Ingress...'
                script {
                    sh """
                        # Aplicar configuración de ingress
                        if [ -d "k8s/ingress" ]; then
                            kubectl apply -f k8s/ingress/ -n ${NAMESPACE}
                        fi
                        
                        # Verificar ingress
                        kubectl get ingress -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Run Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                echo '🧪 Ejecutando pruebas...'
                script {
                    sh """
                        # Pruebas básicas de conectividad
                        echo "=== Probando conectividad interna ==="
                        
                        # Probar PostgreSQL
                        kubectl exec -n ${NAMESPACE} -l app=postgresql -- pg_isready -U postgres
                        
                        # Probar Backstage
                        kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -n ${NAMESPACE} -- curl -f http://backstage:7007/api/catalog/entities || true
                        
                        # Probar OpenWebUI
                        kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -n ${NAMESPACE} -- curl -f http://openwebui:8080/health || true
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo '✅ Verificando despliegue completo...'
                script {
                    sh """
                        echo "=== ESTADO DEL DESPLIEGUE ==="
                        
                        # Verificar pods
                        kubectl get pods -n ${NAMESPACE} -o wide
                        
                        # Verificar servicios
                        kubectl get services -n ${NAMESPACE}
                        
                        # Verificar ingress
                        kubectl get ingress -n ${NAMESPACE}
                        
                        # Verificar logs recientes
                        echo "=== LOGS DE BACKSTAGE ==="
                        kubectl logs -n ${NAMESPACE} -l app=backstage --tail=10 || true
                        
                        echo "=== LOGS DE OPENWEBUI ==="
                        kubectl logs -n ${NAMESPACE} -l app=openwebui --tail=10 || true
                        
                        echo "=== LOGS DE POSTGRESQL ==="
                        kubectl logs -n ${NAMESPACE} -l app=postgresql --tail=10 || true
                        
                        # Obtener URL de acceso
                        echo "=== INFORMACIÓN DE ACCESO ==="
                        MINIKUBE_IP=\$(minikube ip -p ${MINIKUBE_PROFILE})
                        echo "Minikube IP: \$MINIKUBE_IP"
                        echo "Backstage URL: http://\$MINIKUBE_IP/backstage"
                        echo "OpenWebUI URL: http://\$MINIKUBE_IP/openwebui"
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Limpiando recursos temporales...'
            script {
                // Limpiar imágenes locales para ahorrar espacio
                sh """
                    docker system prune -f || true
                """
            }
        }
        success {
            echo '🎉 ¡Despliegue completo exitoso!'
            script {
                sh """
                    echo "=================================="
                    echo "✅ DEMO DESPLEGADO EXITOSAMENTE"
                    echo "=================================="
                    echo "Entorno: ${params.DEPLOY_ENVIRONMENT}"
                    echo "Build: ${BUILD_TAG}"
                    echo "Namespace: ${NAMESPACE}"
                    echo ""
                    echo "Acceso al demo:"
                    MINIKUBE_IP=\$(minikube ip -p ${MINIKUBE_PROFILE})
                    echo "• Backstage: http://\$MINIKUBE_IP/backstage"
                    echo "• OpenWebUI: http://\$MINIKUBE_IP/openwebui"
                    echo "• Dashboard: minikube dashboard -p ${MINIKUBE_PROFILE}"
                    echo ""
                    echo "Comandos útiles:"
                    echo "• kubectl get pods -n ${NAMESPACE}"
                    echo "• kubectl logs -f -n ${NAMESPACE} -l app=backstage"
                    echo "• kubectl port-forward -n ${NAMESPACE} svc/backstage 7007:7007"
                    echo "=================================="
                """
            }
        }
        failure {
            echo '❌ Despliegue falló!'
            script {
                // Mostrar información de debug detallada
                sh """
                    echo "=== INFORMACIÓN DE DEBUG ==="
                    kubectl get all -n ${NAMESPACE} || true
                    kubectl describe pods -n ${NAMESPACE} || true
                    kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' || true
                """
            }
        }
        cleanup {
            // Limpiar workspace
            cleanWs()
        }
    }
}
