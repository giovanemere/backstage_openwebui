{{/*
Expand the name of the chart.
*/}}
{{- define "backstage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "backstage.fullname" -}}
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
{{- define "backstage.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "backstage.labels" -}}
helm.sh/chart: {{ include "backstage.chart" . }}
{{ include "backstage.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: backstage-openwebui-demo
demo.minikube: "true"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "backstage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backstage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "backstage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "backstage.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the PostgreSQL connection string
*/}}
{{- define "backstage.postgresql.connectionString" -}}
postgresql://{{ .Values.database.username }}:{{ .Values.database.password }}@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.database }}
{{- end }}

{{/*
Create demo-specific labels
*/}}
{{- define "backstage.demoLabels" -}}
demo.minikube: "true"
demo.component: backstage
demo.version: {{ .Chart.AppVersion | quote }}
demo.optimization: {{ .Values.demo.optimization.enabled | quote }}
{{- if .Values.demo.features.kubernetes }}
demo.feature.kubernetes: "true"
{{- end }}
{{- if .Values.demo.features.techdocs }}
demo.feature.techdocs: "true"
{{- end }}
{{- if .Values.demo.features.openwebui }}
demo.feature.openwebui: "true"
{{- end }}
{{- end }}

{{/*
Create resource limits for demo
*/}}
{{- define "backstage.demoResources" -}}
{{- if .Values.demo.optimization.enabled }}
limits:
  cpu: {{ .Values.demo.optimization.cpu.limit }}
  memory: {{ .Values.demo.optimization.memory.limit }}
requests:
  cpu: {{ .Values.demo.optimization.cpu.request }}
  memory: {{ .Values.demo.optimization.memory.request }}
{{- else }}
{{- toYaml .Values.resources }}
{{- end }}
{{- end }}
