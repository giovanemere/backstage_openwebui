#!/usr/bin/env groovy

/*
 * Jenkins Kubernetes Configuration for Demo
 * Configuración de Kubernetes para integración con Minikube
 */

import jenkins.model.*
import org.csanchez.jenkins.plugins.kubernetes.*
import org.csanchez.jenkins.plugins.kubernetes.volumes.*

def instance = Jenkins.getInstance()

// Configurar cloud de Kubernetes para Minikube
def kubernetesCloud = new KubernetesCloud("minikube")
kubernetesCloud.setServerUrl("https://kubernetes.default.svc.cluster.local")
kubernetesCloud.setNamespace("jenkins")
kubernetesCloud.setJenkinsUrl("http://jenkins:8080/jenkins")
kubernetesCloud.setJenkinsTunnel("jenkins:50000")
kubernetesCloud.setContainerCapStr("10")
kubernetesCloud.setRetentionTimeout(5)
kubernetesCloud.setConnectTimeout(10)
kubernetesCloud.setReadTimeout(20)

// Configurar template de pod para agentes
def podTemplate = new PodTemplate()
podTemplate.setName("jenkins-agent")
podTemplate.setNamespace("jenkins")
podTemplate.setLabel("jenkins-agent")
podTemplate.setNodeUsageMode(Node.Mode.NORMAL)

// Configurar contenedor principal
def containerTemplate = new ContainerTemplate("jnlp", "jenkins/inbound-agent:latest")
containerTemplate.setWorkingDir("/home/jenkins/agent")
containerTemplate.setCommand("")
containerTemplate.setArgs("")
containerTemplate.setResourceRequestMemory("256Mi")
containerTemplate.setResourceLimitMemory("512Mi")
containerTemplate.setResourceRequestCpu("100m")
containerTemplate.setResourceLimitCpu("500m")

podTemplate.getContainers().add(containerTemplate)

// Configurar volumen para Docker socket (para builds)
def hostPathVolume = new HostPathVolume("/var/run/docker.sock", "/var/run/docker.sock")
podTemplate.getVolumes().add(hostPathVolume)

kubernetesCloud.addTemplate(podTemplate)

// Agregar cloud a Jenkins
instance.clouds.add(kubernetesCloud)
instance.save()

println "Configuración de Kubernetes aplicada para Minikube"
println "Cloud configurado: minikube"
println "Namespace: jenkins"
