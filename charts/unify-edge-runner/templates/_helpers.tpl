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
Reconciler environment variables — shared by hookJob and cronJob.
*/}}
{{- define "edge-runner.reconcilerEnv" -}}
- name: UNIFY_API_URL
  value: {{ .Values.unify.apiUrl | quote }}
- name: ORG_ID
  value: {{ .Values.unify.orgId | quote }}
- name: RUNNER_NAME_PREFIX
  value: {{ .Values.runner.name | quote }}
- name: STATEFULSET_NAME
  value: {{ include "edge-runner.fullname" . | quote }}
- name: NAMESPACE
  value: {{ .Release.Namespace | quote }}
- name: MODE
  value: {{ .Values.reconciler.mode | quote }}
- name: PAT
  valueFrom:
    secretKeyRef:
      name: {{ required "patSecret.name is required. Create the PAT secret before installing the chart." .Values.patSecret.name }}
      key: {{ .Values.patSecret.key }}
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
