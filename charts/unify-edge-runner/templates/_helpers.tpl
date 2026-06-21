{{/*
Expand the name of the chart.
*/}}
{{- define "edge-runner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "edge-runner.fullname" -}}
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
Create chart label.
*/}}
{{- define "edge-runner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "edge-runner.labels" -}}
helm.sh/chart: {{ include "edge-runner.chart" . }}
{{ include "edge-runner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
cloudbees.io/architecture: v2
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "edge-runner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "edge-runner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Kubeconfig secret name — required when kubeconfig.enabled=true.
*/}}
{{- define "edge-runner.kubeconfigSecretName" -}}
{{- required "kubeconfig.secretName is required when kubeconfig.enabled=true. Create the kubeconfig secret before installing the chart." .Values.kubeconfig.secretName }}
{{- end }}

{{/*
SSH secret name — required when ssh.enabled=true.
*/}}
{{- define "edge-runner.sshSecretName" -}}
{{- required "ssh.secretName is required when ssh.enabled=true. Create the SSH secret before installing the chart." .Values.ssh.secretName }}
{{- end }}
