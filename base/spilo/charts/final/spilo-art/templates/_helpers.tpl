{{/*
Expand the name of the chart.
*/}}
{{- define "spilo-art.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spilo-art.fullname" -}}
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
{{- define "spilo-art.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - Включает в себя все возможные labels
*/}}
{{- define "spilo-art.labels" -}}
{{ include "spilo-art.headerLabels" . }}
{{ include "spilo-art.selectorLabels" . }}
{{- end }}

{{/*
Base labels - Заголовочные labels.
*/}}
{{- define "spilo-art.headerLabels" -}}
helm.sh/chart: {{ include "spilo-art.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels - базовые labels, используемые для секции selectors. Включая специфические для
контейнеров spilo.
*/}}
{{- define "spilo-art.selectorLabels" -}}
{{ include "spilo-art.baseSelectorLabels" . }}
{{- with .Values.spilo.env.kubernetesLabels }}
{{ toYaml . }}
{{- end }}
{{ .Values.spilo.env.kubernetesScopeLabel }}: {{ include "spilo-art.fullname" . }}
{{- end }}

{{/*
Base Selector labels - базовые labels, используемые для секции selectors.
*/}}
{{- define "spilo-art.baseSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spilo-art.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spilo-art.serviceAccountName" -}}
{{- default (include "spilo-art.fullname" .) .Values.serviceAccount.name }}
{{- end }}
