#!/usr/bin/env groovy

/*
 * Jenkins Tools Configuration for Demo
 * Configuración de herramientas para el demo
 */

import jenkins.model.*
import hudson.tools.*
import hudson.plugins.git.*
import org.jenkinsci.plugins.docker.commons.tools.*

def instance = Jenkins.getInstance()

// Configurar Git
def gitInstallation = new GitTool("Default", "/usr/bin/git", [])
def gitDescriptor = instance.getDescriptor(GitTool.class)
gitDescriptor.setInstallations(gitInstallation)
gitDescriptor.save()

// Configurar Docker
def dockerInstallation = new DockerTool("docker", "/usr/bin/docker", [])
def dockerDescriptor = instance.getDescriptor(DockerTool.class)
dockerDescriptor.setInstallations(dockerInstallation)
dockerDescriptor.save()

instance.save()

println "Herramientas configuradas:"
println "- Git: /usr/bin/git"
println "- Docker: /usr/bin/docker"
