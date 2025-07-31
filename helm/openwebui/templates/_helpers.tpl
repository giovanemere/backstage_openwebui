{{/*
Expand the name of the chart.
*/}}
{{- define "openwebui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openwebui.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openwebui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openwebui.labels" -}}
helm.sh/chart: {{ include "openwebui.chart" . }}
{{ include "openwebui.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openwebui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openwebui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openwebui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openwebui.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the namespace to use
*/}}
{{- define "openwebui.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the image name
*/}}
{{- define "openwebui.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create database connection string
*/}}
{{- define "openwebui.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s:%d/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "postgresql.primary.fullname" .Subcharts.postgresql) (.Values.postgresql.primary.service.ports.postgresql | int) .Values.postgresql.auth.database }}
{{- else }}
{{- printf "postgresql://%s:%s@%s:%d/%s" .Values.database.user .Values.database.password .Values.database.host (.Values.database.port | int) .Values.database.name }}
{{- end }}
{{- end }}

{{/*
Create common annotations
*/}}
{{- define "openwebui.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create resource limits
*/}}
{{- define "openwebui.resources" -}}
{{- if .Values.resources }}
resources:
  {{- if .Values.resources.limits }}
  limits:
    {{- if .Values.resources.limits.cpu }}
    cpu: {{ .Values.resources.limits.cpu }}
    {{- end }}
    {{- if .Values.resources.limits.memory }}
    memory: {{ .Values.resources.limits.memory }}
    {{- end }}
  {{- end }}
  {{- if .Values.resources.requests }}
  requests:
    {{- if .Values.resources.requests.cpu }}
    cpu: {{ .Values.resources.requests.cpu }}
    {{- end }}
    {{- if .Values.resources.requests.memory }}
    memory: {{ .Values.resources.requests.memory }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Create security context
*/}}
{{- define "openwebui.securityContext" -}}
{{- if .Values.securityContext }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create pod security context
*/}}
{{- define "openwebui.podSecurityContext" -}}
{{- if .Values.podSecurityContext }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create container security context
*/}}
{{- define "openwebui.containerSecurityContext" -}}
{{- if .Values.containerSecurityContext }}
securityContext:
  {{- toYaml .Values.containerSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create node selector
*/}}
{{- define "openwebui.nodeSelector" -}}
{{- if .Values.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create tolerations
*/}}
{{- define "openwebui.tolerations" -}}
{{- if .Values.tolerations }}
tolerations:
  {{- toYaml .Values.tolerations | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create affinity
*/}}
{{- define "openwebui.affinity" -}}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create environment variables
*/}}
{{- define "openwebui.envVars" -}}
- name: NODE_ENV
  value: "production"
- name: WEBUI_NAME
  value: {{ .Values.openwebui.name | quote }}
- name: WEBUI_URL
  value: {{ .Values.openwebui.url | quote }}
- name: WEBUI_SECRET_KEY
  value: {{ .Values.openwebui.secretKey | quote }}
- name: ENABLE_SIGNUP
  value: {{ .Values.openwebui.auth.enableSignup | quote }}
- name: DEFAULT_USER_ROLE
  value: {{ .Values.openwebui.auth.defaultUserRole | quote }}
- name: ENABLE_LOGIN_FORM
  value: {{ .Values.openwebui.auth.enableLoginForm | quote }}
- name: ENABLE_OAUTH_SIGNUP
  value: {{ .Values.openwebui.auth.enableOAuthSignup | quote }}
- name: WEBUI_AUTH
  value: {{ .Values.openwebui.auth.enabled | quote }}
- name: DATABASE_URL
  value: {{ include "openwebui.databaseUrl" . | quote }}
{{- if .Values.openwebui.backstage.enabled }}
- name: BACKSTAGE_URL
  value: {{ .Values.openwebui.backstage.baseUrl | quote }}
- name: BACKSTAGE_INTEGRATION
  value: "true"
- name: BACKSTAGE_API_TOKEN
  value: {{ .Values.openwebui.backstage.apiToken | quote }}
{{- end }}
{{- if .Values.openwebui.ai.providers.ollama.enabled }}
- name: OLLAMA_BASE_URL
  value: {{ .Values.openwebui.ai.providers.ollama.baseUrl | quote }}
- name: ENABLE_OLLAMA_API
  value: "true"
{{- end }}
{{- if .Values.openwebui.ai.providers.openai.enabled }}
- name: OPENAI_API_KEY
  value: {{ .Values.openwebui.ai.providers.openai.apiKey | quote }}
{{- end }}
- name: UPLOAD_DIR
  value: "/app/data/uploads"
- name: MAX_FILE_SIZE
  value: {{ .Values.openwebui.upload.maxFileSize | quote }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create volume mounts
*/}}
{{- define "openwebui.volumeMounts" -}}
- name: config-volume
  mountPath: /app/config
  readOnly: true
- name: data-storage
  mountPath: /app/data
{{- if .Values.persistence.models.enabled }}
- name: models-storage
  mountPath: /app/models
{{- end }}
- name: logs-storage
  mountPath: /app/logs
- name: temp-dir
  mountPath: /tmp
{{- with .Values.extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create volumes
*/}}
{{- define "openwebui.volumes" -}}
- name: config-volume
  configMap:
    name: {{ include "openwebui.fullname" . }}-config
- name: data-storage
  {{- if .Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ include "openwebui.fullname" . }}-data
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- if .Values.persistence.models.enabled }}
- name: models-storage
  persistentVolumeClaim:
    claimName: {{ include "openwebui.fullname" . }}-models
{{- end }}
- name: logs-storage
  emptyDir: {}
- name: temp-dir
  emptyDir: {}
{{- with .Values.extraVolumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create init container for waiting database
*/}}
{{- define "openwebui.initContainerWaitDb" -}}
{{- if .Values.initContainers.waitForDb.enabled }}
- name: wait-for-db
  image: {{ .Values.initContainers.waitForDb.image }}
  command:
    - sh
    - -c
    - |
      echo "Esperando a que PostgreSQL esté listo..."
      until nc -z {{ .Values.database.host }} {{ .Values.database.port }}; do
        echo "PostgreSQL no está listo, esperando..."
        sleep 2
      done
      echo "PostgreSQL está listo!"
  {{- if .Values.initContainers.waitForDb.resources }}
  resources:
    {{- toYaml .Values.initContainers.waitForDb.resources | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Create init container for data initialization
*/}}
{{- define "openwebui.initContainerInitData" -}}
{{- if .Values.initContainers.initData.enabled }}
- name: init-data
  image: {{ include "openwebui.image" . }}
  command:
    - sh
    - -c
    - |
      echo "Inicializando datos de OpenWebUI..."
      mkdir -p /app/data/uploads
      mkdir -p /app/data/models
      mkdir -p /app/logs
      chown -R 1001:1001 /app/data /app/logs
      echo "Datos inicializados correctamente"
  volumeMounts:
    - name: data-storage
      mountPath: /app/data
    - name: logs-storage
      mountPath: /app/logs
  {{- if .Values.initContainers.initData.resources }}
  resources:
    {{- toYaml .Values.initContainers.initData.resources | nindent 4 }}
  {{- end }}
  {{- include "openwebui.containerSecurityContext" . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create sidecar nginx container
*/}}
{{- define "openwebui.sidecarNginx" -}}
{{- if .Values.sidecars.nginx.enabled }}
- name: nginx-proxy
  image: {{ .Values.sidecars.nginx.image }}
  ports:
    - name: proxy
      containerPort: 80
      protocol: TCP
  volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
      readOnly: true
  {{- if .Values.sidecars.nginx.resources }}
  resources:
    {{- toYaml .Values.sidecars.nginx.resources | nindent 4 }}
  {{- end }}
  securityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 101
    capabilities:
      drop:
        - ALL
{{- end }}
{{- end }}
