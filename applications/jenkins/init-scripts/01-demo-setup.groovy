// Jenkins Demo Setup Script
import jenkins.model.*
import hudson.security.*
import hudson.model.*

def instance = Jenkins.getInstance()

// Configure demo message
def systemMessage = """
<div style="background-color: #e7f3ff; border: 1px solid #b3d9ff; padding: 10px; margin: 10px 0; border-radius: 5px;">
    <h3 style="color: #0066cc; margin-top: 0;">🚀 Jenkins Demo - Backstage + OpenWebUI</h3>
    <p><strong>Modo Demo:</strong> Configuración optimizada para Minikube</p>
    <p><strong>Recursos:</strong> 512Mi RAM, 500m CPU</p>
    <p><strong>Registry:</strong> edissonz8809/iaops</p>
    <p><strong>Credenciales Demo:</strong> admin / demo-jenkins-password</p>
</div>
"""

instance.setSystemMessage(systemMessage)

// Configure executors for demo
instance.setNumExecutors(2)

// Set quiet period for demo
instance.setQuietPeriod(5)

// Configure SCM checkout retry count
instance.setScmCheckoutRetryCount(2)

// Save configuration
instance.save()

println "Jenkins demo setup completed successfully!"
println "System message configured"
println "Executors set to 2"
println "Quiet period set to 5 seconds"
println "SCM retry count set to 2"
