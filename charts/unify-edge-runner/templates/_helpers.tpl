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
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "edge-runner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "edge-runner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PAT secret name — defaults to <release>-pat.
*/}}
{{- define "edge-runner.patSecretName" -}}
{{- if .Values.patSecret.name }}
{{- .Values.patSecret.name }}
{{- else }}
{{- printf "%s-pat" (include "edge-runner.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Kubeconfig secret name — defaults to <release>-kubeconfig.
*/}}
{{- define "edge-runner.kubeconfigSecretName" -}}
{{- if .Values.kubeconfig.secretName }}
{{- .Values.kubeconfig.secretName }}
{{- else }}
{{- printf "%s-kubeconfig" (include "edge-runner.fullname" .) }}
{{- end }}
{{- end }}

{{/*
SSH secret name — defaults to <release>-ssh.
*/}}
{{- define "edge-runner.sshSecretName" -}}
{{- if .Values.ssh.secretName }}
{{- .Values.ssh.secretName }}
{{- else }}
{{- printf "%s-ssh" (include "edge-runner.fullname" .) }}
{{- end }}
{{- end }}
