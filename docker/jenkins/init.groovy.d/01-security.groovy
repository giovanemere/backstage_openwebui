#!/usr/bin/env groovy

/*
 * Jenkins Security Configuration for Demo
 * Configuración básica de seguridad para el demo
 */

import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// Configurar autenticación básica para demo
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "demo123")
hudsonRealm.createAccount("demo", "demo123")
instance.setSecurityRealm(hudsonRealm)

// Configurar autorización básica
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Configurar agentes
instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)

// Guardar configuración
instance.save()

println "Configuración de seguridad aplicada para demo"
println "Usuario admin: admin/demo123"
println "Usuario demo: demo/demo123"
